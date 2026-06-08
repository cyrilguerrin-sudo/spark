package com.example.spark

import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.spark/permissions"
    private var channel: MethodChannel? = null

    // Intent reçu avant que le channel Flutter soit prêt
    private var pendingNetworkId: String? = null
    private var pendingIsFocus: Boolean = false
    private var pendingSessionEndedNetworkId: String? = null
    private var pendingBlockedNetworkId: String? = null
    private var pendingBlockUntilMs: Long = 0L

    // ── Lifecycle ────────────────────────────────────────────────────────────

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractAndDispatch(intent)
    }

    override fun onResume() {
        super.onResume()
        // Récupère une fin de session écrite par le service pendant le verrouillage écran
        val prefs = getSharedPreferences(AppMonitorService.PREFS, Context.MODE_PRIVATE)
        val pendingEnd = prefs.getString(AppMonitorService.KEY_PENDING_SESSION_ENDED, "") ?: ""
        if (pendingEnd.isNotEmpty()) {
            prefs.edit().putString(AppMonitorService.KEY_PENDING_SESSION_ENDED, "").apply()
            if (channel != null) {
                channel!!.invokeMethod("onSessionEnded", mapOf("networkId" to pendingEnd))
            } else {
                pendingSessionEndedNetworkId = pendingEnd
            }
        }
    }

    // ── Flutter engine setup ─────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {

                // ── Permissions ──────────────────────────────────────────
                "checkUsageStatsPermission" -> result.success(hasUsageStats())
                "openUsageStatsSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "checkOverlayPermission" -> result.success(hasOverlay())
                "openOverlaySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"))
                        )
                    }
                    result.success(null)
                }
                "checkDeviceAdminPermission" -> result.success(isDeviceAdminActive())
                "openDeviceAdminSettings" -> {
                    val component = ComponentName(this, SparkDeviceAdminReceiver::class.java)
                    startActivity(Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                        putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, component)
                        putExtra(
                            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                            "Spark verrouille l'écran quand ta session se termine pour t'aider à décrocher."
                        )
                    })
                    result.success(null)
                }

                // ── Service de surveillance ──────────────────────────────
                "startMonitorService" -> {
                    startMonitorService()
                    result.success(null)
                }
                "stopMonitorService" -> {
                    stopService(Intent(this, AppMonitorService::class.java))
                    result.success(null)
                }
                "updateMonitorConfig" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as Map<String, Any>
                    updateMonitorPrefs(args)
                    result.success(null)
                }
                "setSessionEndTime" -> {
                    val args = call.arguments as Map<*, *>
                    val endTimeMs = when (val raw = args["endTimeMs"]) {
                        is Long   -> raw
                        is Int    -> raw.toLong()
                        is Double -> raw.toLong()
                        else      -> 0L
                    }
                    val networkId = args["networkId"] as? String ?: ""
                    getSharedPreferences(AppMonitorService.PREFS, Context.MODE_PRIVATE)
                        .edit()
                        .putLong(AppMonitorService.KEY_SESSION_END_TIME, endTimeMs)
                        .putString(AppMonitorService.KEY_SESSION_NETWORK_ID, networkId)
                        .apply()
                    result.success(null)
                }
                "clearSessionEndTime" -> {
                    getSharedPreferences(AppMonitorService.PREFS, Context.MODE_PRIVATE)
                        .edit()
                        .putLong(AppMonitorService.KEY_SESSION_END_TIME, 0L)
                        .putString(AppMonitorService.KEY_SESSION_NETWORK_ID, "")
                        .apply()
                    result.success(null)
                }
                "setBlockUntil" -> {
                    val args = call.arguments as Map<*, *>
                    val pkg = args["packageName"] as? String ?: ""
                    val until = when (val raw = args["blockUntilMs"]) {
                        is Long   -> raw
                        is Int    -> raw.toLong()
                        is Double -> raw.toLong()
                        else      -> 0L
                    }
                    getSharedPreferences(AppMonitorService.PREFS, Context.MODE_PRIVATE)
                        .edit()
                        .putLong(AppMonitorService.KEY_BLOCK_UNTIL_MS, until)
                        .putString(AppMonitorService.KEY_BLOCK_PKG, pkg)
                        .apply()
                    result.success(null)
                }
                "bringToFront" -> {
                    val i = Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    startActivity(i)
                    result.success(null)
                }
                "launchApp" -> {
                    val pkg = call.arguments as? Map<*, *>
                    val packageName = pkg?.get("packageName") as? String ?: ""
                    launchDefaultApp(packageName)
                    result.success(null)
                }
                "launchWithDeepLink" -> {
                    val args = call.arguments as Map<*, *>
                    val deepLink = args["deepLink"] as? String ?: ""
                    val packageName = args["packageName"] as? String ?: ""
                    launchDeepLink(deepLink, packageName)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // Dispatcher les événements en attente (intent arrivé avant le channel)
        pendingSessionEndedNetworkId?.let { nid ->
            channel!!.invokeMethod("onSessionEnded", mapOf("networkId" to nid))
            pendingSessionEndedNetworkId = null
        }
        pendingBlockedNetworkId?.let { nid ->
            channel!!.invokeMethod("onAppBlocked", mapOf(
                "networkId" to nid,
                "blockUntilMs" to pendingBlockUntilMs
            ))
            pendingBlockedNetworkId = null
            pendingBlockUntilMs = 0L
        }
        pendingNetworkId?.let { nid ->
            channel!!.invokeMethod("onAppIntercepted",
                mapOf("networkId" to nid, "isFocus" to pendingIsFocus))
            pendingNetworkId = null
        }
        intent?.let { extractAndDispatch(it) }
    }

    // ── Interception intent → Flutter ────────────────────────────────────────

    private fun extractAndDispatch(intent: Intent) {
        // ── Fin de session détectée par le service ──────────────────────────
        val endedNetworkId = intent.getStringExtra(AppMonitorService.EXTRA_SESSION_ENDED)
        if (endedNetworkId != null) {
            intent.removeExtra(AppMonitorService.EXTRA_SESSION_ENDED)
            if (channel != null) {
                channel!!.invokeMethod("onSessionEnded", mapOf("networkId" to endedNetworkId))
            } else {
                pendingSessionEndedNetworkId = endedNetworkId
            }
            return
        }

        // ── App bloquée (5min post-session) ──────────────────────────────────
        val blockedNetworkId = intent.getStringExtra(AppMonitorService.EXTRA_APP_BLOCKED)
        if (blockedNetworkId != null) {
            intent.removeExtra(AppMonitorService.EXTRA_APP_BLOCKED)
            val blockUntilMs = intent.getLongExtra(AppMonitorService.EXTRA_BLOCK_UNTIL_MS, 0L)
            intent.removeExtra(AppMonitorService.EXTRA_BLOCK_UNTIL_MS)
            if (channel != null) {
                channel!!.invokeMethod("onAppBlocked", mapOf(
                    "networkId" to blockedNetworkId,
                    "blockUntilMs" to blockUntilMs
                ))
            } else {
                pendingBlockedNetworkId = blockedNetworkId
                pendingBlockUntilMs = blockUntilMs
            }
            return
        }

        // ── Interception normale ─────────────────────────────────────────────
        val networkId = intent.getStringExtra(AppMonitorService.EXTRA_NETWORK_ID) ?: return
        val isFocus   = intent.getBooleanExtra(AppMonitorService.EXTRA_IS_FOCUS, false)
        intent.removeExtra(AppMonitorService.EXTRA_NETWORK_ID)

        if (channel != null) {
            channel!!.invokeMethod(
                "onAppIntercepted",
                mapOf("networkId" to networkId, "isFocus" to isFocus)
            )
        } else {
            pendingNetworkId = networkId
            pendingIsFocus   = isFocus
        }
    }

    // ── Service ──────────────────────────────────────────────────────────────

    private fun startMonitorService() {
        val intent = Intent(this, AppMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun updateMonitorPrefs(args: Map<String, Any>) {
        val prefs = getSharedPreferences(AppMonitorService.PREFS, Context.MODE_PRIVATE).edit()

        @Suppress("UNCHECKED_CAST")
        prefs.putStringSet(
            AppMonitorService.KEY_MONITORED,
            (args["monitoredPackages"] as List<*>).map { it.toString() }.toSet()
        )
        @Suppress("UNCHECKED_CAST")
        prefs.putStringSet(
            AppMonitorService.KEY_ACTIVE,
            (args["activeSessionPackages"] as List<*>).map { it.toString() }.toSet()
        )
        prefs.putBoolean(AppMonitorService.KEY_FOCUS_ACTIVE, args["focusActive"] as Boolean)
        @Suppress("UNCHECKED_CAST")
        prefs.putStringSet(
            AppMonitorService.KEY_FOCUS_PKGS,
            (args["focusPackages"] as List<*>).map { it.toString() }.toSet()
        )
        prefs.apply()
    }

    // ── Lancement des apps sociales ──────────────────────────────────────────

    private fun launchDeepLink(deepLink: String, packageName: String) {
        if (deepLink.isEmpty()) {
            launchDefaultApp(packageName)
            return
        }
        try {
            val intent = when {
                // Format intent:// (ex: story-camera Instagram)
                deepLink.startsWith("intent://") -> {
                    Intent.parseUri(deepLink, Intent.URI_INTENT_SCHEME).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                }
                // Format https:// → App Link ciblé sur le package
                deepLink.startsWith("https://") || deepLink.startsWith("http://") -> {
                    Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
                        setPackage(packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                }
                // Format instagram:// ou autre scheme custom
                else -> {
                    Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
                        setPackage(packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                }
            }
            startActivity(intent)
        } catch (_: Exception) {
            // Deep link non supporté → lancement par défaut
            launchDefaultApp(packageName)
        }
    }

    private fun launchDefaultApp(packageName: String) {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        } ?: return
        startActivity(intent)
    }

    // ── Checks permissions ───────────────────────────────────────────────────

    private fun hasUsageStats(): Boolean {
        val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasOverlay(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this)
        else true

    private fun isDeviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(ComponentName(this, SparkDeviceAdminReceiver::class.java))
    }

}
