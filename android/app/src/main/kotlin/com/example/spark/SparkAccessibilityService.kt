package com.example.spark

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class SparkAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "SparkAccessibility"
        private const val COOLDOWN_MS = 30_000L
        private const val BLOCK_COOLDOWN_MS = 2_000L
    }

    private val lastIntercepted = mutableMapOf<String, Long>()
    private val lastBlocked = mutableMapOf<String, Long>()
    private val lastContentChangedMs = mutableMapOf<String, Long>()

    override fun onServiceConnected() {
        Log.e("SparkA11y", "Service connected")
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                         AccessibilityEvent.TYPE_WINDOWS_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
        }
        Log.d(TAG, "connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return
        val networkId = AppMonitorService.PKG_TO_ID[pkg] ?: return
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val now = System.currentTimeMillis()
            if (now - (lastContentChangedMs[pkg] ?: 0L) < 500L) return
            lastContentChangedMs[pkg] = now
        }
        handlePackageDetected(pkg, networkId)
    }

    override fun onInterrupt() {}

    private fun handlePackageDetected(pkg: String, networkId: String) {
        val now = System.currentTimeMillis()

        // Fast-path cooldown check (in-memory, no I/O)
        val sinceIntercepted = now - (lastIntercepted[pkg] ?: 0L)
        val sinceBlocked = now - (lastBlocked[pkg] ?: 0L)
        if (sinceIntercepted < COOLDOWN_MS && sinceBlocked < BLOCK_COOLDOWN_MS) return

        val prefs = getSharedPreferences(AppMonitorService.PREFS, Context.MODE_PRIVATE)

        // ── Blocage actif (post-session 5min) ────────────────────────────────
        val blockUntil = prefs.getLong(AppMonitorService.KEY_BLOCK_UNTIL_MS, 0L)
        if (blockUntil > 0L && now < blockUntil) {
            val blockPkg = prefs.getString(AppMonitorService.KEY_BLOCK_PKG, "") ?: ""
            if (pkg == blockPkg) {
                if (sinceBlocked >= BLOCK_COOLDOWN_MS) {
                    lastBlocked[pkg] = now
                    val intent = Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        putExtra(AppMonitorService.EXTRA_APP_BLOCKED, networkId)
                        putExtra(AppMonitorService.EXTRA_BLOCK_UNTIL_MS, blockUntil)
                    }
                    startActivity(intent)
                }
                return
            }
        }

        if (sinceIntercepted < COOLDOWN_MS) return

        // ── Interception normale ──────────────────────────────────────────────
        val monitored = prefs.getStringSet(AppMonitorService.KEY_MONITORED, emptySet()) ?: emptySet()
        if (!monitored.contains(pkg)) return

        val active = prefs.getStringSet(AppMonitorService.KEY_ACTIVE, emptySet()) ?: emptySet()
        if (active.contains(pkg)) return

        val focusActive = prefs.getBoolean(AppMonitorService.KEY_FOCUS_ACTIVE, false)
        val focusPkgs = prefs.getStringSet(AppMonitorService.KEY_FOCUS_PKGS, emptySet()) ?: emptySet()
        if (focusActive && !focusPkgs.contains(pkg)) return

        lastIntercepted[pkg] = now
        Log.d(TAG, "intercepting $pkg → $networkId")

        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra(AppMonitorService.EXTRA_NETWORK_ID, networkId)
            putExtra(AppMonitorService.EXTRA_IS_FOCUS, focusActive && focusPkgs.contains(pkg))
        }
        startActivity(intent)
    }
}
