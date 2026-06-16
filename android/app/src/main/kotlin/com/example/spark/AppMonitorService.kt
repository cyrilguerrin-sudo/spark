package com.example.spark

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.util.Log
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class AppMonitorService : Service() {

    companion object {
        const val PREFS                  = "spark_monitor"
        const val KEY_MONITORED          = "monitored_packages"
        const val KEY_ACTIVE             = "active_sessions"
        const val KEY_FOCUS_ACTIVE       = "focus_active"
        const val KEY_FOCUS_PKGS         = "focus_packages"
        // Timestamp Unix (ms) de fin de session — surveillé par le service
        // pour déclencher la fin même quand Flutter est en arrière-plan.
        const val KEY_SESSION_END_TIME   = "session_end_time"
        const val KEY_SESSION_NETWORK_ID = "session_network_id"
        const val EXTRA_NETWORK_ID       = "network_id"
        const val EXTRA_IS_FOCUS         = "is_focus"
        const val EXTRA_SESSION_ENDED         = "session_ended_network_id"
        const val KEY_PENDING_SESSION_ENDED   = "pending_session_ended"
        const val KEY_SESSION_CANCELLED       = "session_cancelled"
        // Blocage temporaire après "Bloquer Insta 5min"
        const val KEY_BLOCK_UNTIL_MS  = "block_until_ms"
        const val KEY_BLOCK_PKG       = "block_pkg"
        const val EXTRA_APP_BLOCKED   = "extra_app_blocked"
        const val EXTRA_BLOCK_UNTIL_MS = "extra_block_until_ms"
        private const val CHANNEL_ID       = "spark_monitor"
        private const val NOTIF_ID         = 42
        private const val CHANNEL_ID_ALERT = "spark_session_alert"
        private const val NOTIF_ID_ALERT   = 43
        private const val TAG        = "SparkMonitor"
        private const val POLL_MS     = 500L
        private const val BLOCK_COOLDOWN_MS           = 2_000L   // 2s — anti-spam pour l'écran de blocage
        private const val SILENT_CLOSE_TIMEOUT_MS      = 45_000L  // 45s sans foreground → reset silencieux
        private const val SESSION_FOREGROUND_WINDOW_MS = 30 * 60 * 1_000L  // 30min — couvre la durée max de session
        const val KEY_SESSION_REMAINING_MS = "session_remaining_ms" // ms restants quand timer en pause
        const val KEY_SESSION_PAUSED_AT_MS = "session_paused_at_ms" // timestamp de la mise en pause

        val PKG_TO_ID = mapOf(
            "com.instagram.android"        to "instagram",
            "com.zhiliaoapp.musically"     to "tiktok",
            "com.ss.android.ugc.trill"     to "tiktok",
            "com.google.android.youtube"   to "youtube",
            "com.twitter.android"          to "twitter",
            "com.snapchat.android"         to "snapchat",
            "com.facebook.katana"          to "facebook",
        )
    }

    private val handler = Handler(Looper.getMainLooper())
    private val lastBlocked = mutableMapOf<String, Long>()
    private var isPolling = false
    private var overlayView: View? = null
    private val wm: WindowManager by lazy { getSystemService(Context.WINDOW_SERVICE) as WindowManager }

    private val pollRunnable = object : Runnable {
        override fun run() {
            poll()
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        createAlertChannel()
        startForeground(NOTIF_ID, buildNotif())
        if (!isPolling) {
            isPolling = true
            handler.post(pollRunnable)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isPolling = false
        handler.removeCallbacks(pollRunnable)
        removeSessionEndOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Logique de surveillance ──────────────────────────────────────────────

    private fun poll() {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        // ── Timer de session : pause / reprise / expiration / reset silencieux ─
        val sessionNetworkId = prefs.getString(KEY_SESSION_NETWORK_ID, "") ?: ""
        if (sessionNetworkId.isNotEmpty()) {
            val sessionEndTime = prefs.getLong(KEY_SESSION_END_TIME, 0L)
            val remainingMs    = prefs.getLong(KEY_SESSION_REMAINING_MS, 0L)
            val pausedAtMs     = prefs.getLong(KEY_SESSION_PAUSED_AT_MS, 0L)

            val sessionPkgs = PKG_TO_ID.entries
                .filter { it.value == sessionNetworkId }
                .map { it.key }.toSet()
            val appInFg = sessionPkgs.any { isSessionPkgForeground(it) }

            if (appInFg) {
                when {
                    remainingMs > 0L -> {
                        // Reprendre le timer depuis le temps restant
                        prefs.edit()
                            .putLong(KEY_SESSION_END_TIME, now + remainingMs)
                            .putLong(KEY_SESSION_REMAINING_MS, 0L)
                            .putLong(KEY_SESSION_PAUSED_AT_MS, 0L)
                            .apply()
                    }
                    sessionEndTime > 0L && now >= sessionEndTime -> {
                        // Expiration normale — app au premier plan
                        prefs.edit().putLong(KEY_SESSION_END_TIME, 0L).apply()
                        handleSessionEnd(sessionNetworkId)
                        return
                    }
                }
            } else {
                when {
                    sessionEndTime > 0L && now >= sessionEndTime -> {
                        prefs.edit().putLong(KEY_SESSION_END_TIME, 0L).apply()
                        handleSessionEnd(sessionNetworkId)
                        return
                    }
                    sessionEndTime > 0L -> {
                        // Passer en pause : sauvegarder le temps restant
                        prefs.edit()
                            .putLong(KEY_SESSION_END_TIME, 0L)
                            .putLong(KEY_SESSION_REMAINING_MS, (sessionEndTime - now).coerceAtLeast(0L))
                            .putLong(KEY_SESSION_PAUSED_AT_MS, now)
                            .apply()
                    }
                    pausedAtMs > 0L && (now - pausedAtMs) >= SILENT_CLOSE_TIMEOUT_MS -> {
                        // 45s sans retour → reset silencieux
                        silentReset(sessionNetworkId)
                        return
                    }
                }
            }
        }

        // ── Nettoyage blocage expiré (même sans app en avant-plan) ───────────
        val blockUntil = prefs.getLong(KEY_BLOCK_UNTIL_MS, 0L)
        if (blockUntil > 0L && now >= blockUntil) {
            prefs.edit()
                .putLong(KEY_BLOCK_UNTIL_MS, 0L)
                .putString(KEY_BLOCK_PKG, "")
                .apply()
        }

        val pkg = getForegroundPackage() ?: return
        if (pkg == packageName) return
        if (!isSessionPkgForeground(pkg, 10_000L)) return

        // ── Blocage actif : intercepte sans écran d'intention ─────────────────
        if (blockUntil > 0L && now < blockUntil) {
            val blockPkg = prefs.getString(KEY_BLOCK_PKG, "") ?: ""
            if (pkg == blockPkg) {
                if ((now - (lastBlocked[pkg] ?: 0L)) >= BLOCK_COOLDOWN_MS) {
                    lastBlocked[pkg] = now
                    val launchIntent = Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        putExtra(EXTRA_APP_BLOCKED, PKG_TO_ID[pkg] ?: pkg)
                        putExtra(EXTRA_BLOCK_UNTIL_MS, blockUntil)
                    }
                    startActivity(launchIntent)
                }
                return
            }
        }

        // ── Interception normale ──────────────────────────────────────────────
        val monitored = prefs.getStringSet(KEY_MONITORED, emptySet()) ?: emptySet()
        if (!monitored.contains(pkg)) return

        val active = prefs.getStringSet(KEY_ACTIVE, emptySet()) ?: emptySet()
        val sessionEndTime = prefs.getLong(KEY_SESSION_END_TIME, 0L)
        val remainingMs    = prefs.getLong(KEY_SESSION_REMAINING_MS, 0L)
        if (active.contains(pkg) && (sessionEndTime > 0L || remainingMs > 0L)) return

        val focusActive = prefs.getBoolean(KEY_FOCUS_ACTIVE, false)
        val focusPkgs   = prefs.getStringSet(KEY_FOCUS_PKGS, emptySet()) ?: emptySet()
        if (focusActive && !focusPkgs.contains(pkg)) return

        val networkId = PKG_TO_ID[pkg] ?: return

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra(EXTRA_NETWORK_ID, networkId)
            putExtra(EXTRA_IS_FOCUS, focusActive && focusPkgs.contains(pkg))
        }
        startActivity(launchIntent)
    }

    private fun getForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 10_000, now)
        return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
    }

    // Retourne true si le dernier événement d'activité pour ce package est ACTIVITY_RESUMED.
    private fun isSessionPkgForeground(pkg: String, windowMs: Long = SESSION_FOREGROUND_WINDOW_MS): Boolean {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - windowMs, now)
        val event = UsageEvents.Event()
        var latestType = -1
        var latestTime = 0L
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.packageName == pkg && event.timeStamp > latestTime) {
                latestType = event.eventType
                latestTime = event.timeStamp
            }
        }
        return latestType == UsageEvents.Event.ACTIVITY_RESUMED
    }

    // ── Overlay système — fin de session (prioritaire sur tous constructeurs) ─

    private fun handleSessionEnd(networkId: String) {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val component = ComponentName(this, SparkDeviceAdminReceiver::class.java)
        val isAdmin = dpm.isAdminActive(component)

        if (isAdmin) {
            getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_PENDING_SESSION_ENDED, networkId)
                .apply()
            clearActiveSession(networkId)
            var locked = false
            try {
                dpm.lockNow()
                locked = true
            } catch (e: Exception) {
                Log.e(TAG, "lockNow() EXCEPTION — ${e::class.simpleName}: ${e.message}")
            }
            if (locked) return
            // lockNow() a échoué — fallthrough vers overlay
        }

        // Priorité 2 — WindowManager overlay (SYSTEM_ALERT_WINDOW)
        val canOverlay = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)
        if (canOverlay) {
            showSessionEndOverlay(networkId)
        } else {
            // Priorité 3 — notification setFullScreenIntent
            showSessionEndNotification(networkId)
        }
    }

    private fun clearActiveSession(networkId: String) {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pkgsToRemove = PKG_TO_ID.entries.filter { it.value == networkId }.map { it.key }.toSet()
        val active = (prefs.getStringSet(KEY_ACTIVE, emptySet()) ?: emptySet()).toMutableSet()
        active.removeAll(pkgsToRemove)
        prefs.edit()
            .putStringSet(KEY_ACTIVE, active)
            .putString(KEY_SESSION_NETWORK_ID, "")
            .putLong(KEY_SESSION_END_TIME, 0L)
            .putLong(KEY_SESSION_REMAINING_MS, 0L)
            .putLong(KEY_SESSION_PAUSED_AT_MS, 0L)
            .apply()
    }

    private fun silentReset(networkId: String) {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_SESSION_END_TIME, 0L)
            .putLong(KEY_SESSION_REMAINING_MS, 0L)
            .putLong(KEY_SESSION_PAUSED_AT_MS, 0L)
            .putString(KEY_SESSION_NETWORK_ID, "")
            .putString(KEY_PENDING_SESSION_ENDED, "")
            .putString(KEY_SESSION_CANCELLED, networkId)
            .apply()
        clearActiveSession(networkId)
    }

    @Suppress("DEPRECATION")
    private fun showSessionEndOverlay(networkId: String) {
        if (overlayView != null) return
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        val view = buildOverlayView(networkId)
        overlayView = view
        try {
            wm.addView(view, params)
        } catch (e: Exception) {
            Log.e(TAG, "showSessionEndOverlay: wm.addView() FAILED — ${e::class.simpleName}: ${e.message}")
            overlayView = null
            showSessionEndNotification(networkId)
        }
    }

    private fun removeSessionEndOverlay() {
        overlayView?.let {
            try {
                wm.removeView(it)
            } catch (e: Exception) {
                Log.e(TAG, "removeSessionEndOverlay: ${e.message}")
            }
            overlayView = null
        }
    }

    private fun buildOverlayView(networkId: String): View {
        val root = FrameLayout(this).apply {
            setBackgroundColor(0xFF171A1A.toInt())
        }
        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val title = TextView(this).apply {
            text = "Ta session est terminée"
            textSize = 22f
            setTextColor(0xFFFFFFFF.toInt())
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(64, 0, 64, 20)
        }
        val subtitle = TextView(this).apply {
            text = "Appuie pour revenir dans Spark"
            textSize = 14f
            setTextColor(0xFF888888.toInt())
            gravity = Gravity.CENTER
            setPadding(64, 0, 64, 0)
        }
        col.addView(title, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))
        col.addView(subtitle, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))
        root.addView(col, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        ))
        root.setOnClickListener {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra(EXTRA_SESSION_ENDED, networkId)
            }
            startActivity(intent)
            removeSessionEndOverlay()
        }
        return root
    }

    // ── Notification plein écran — fin de session (fallback) ─────────────────

    private fun showSessionEndNotification(networkId: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra(EXTRA_SESSION_ENDED, networkId)
        }
        val pi = PendingIntent.getActivity(
            this, NOTIF_ID_ALERT, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(this, CHANNEL_ID_ALERT)
            .setContentTitle("Ta session est terminée")
            .setContentText("Reviens dans Spark pour conclure.")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(pi)
            .setFullScreenIntent(pi, true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIF_ID_ALERT, notif)
    }

    // ── Notification foreground ──────────────────────────────────────────────

    private fun createAlertChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID_ALERT,
                "Spark — Fin de session",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerte de fin de session Spark"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "Spark Monitor", NotificationManager.IMPORTANCE_MIN).apply {
                description = "Spark surveille tes apps"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
        }
    }

    private fun buildNotif(): Notification {
        val pi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Spark actif")
            .setContentText("Surveillance des apps en cours")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
    }
}
