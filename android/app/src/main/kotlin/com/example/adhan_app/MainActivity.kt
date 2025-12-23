package com.example.adhan_app

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.example.adhan_app/foreground_service"
        const val PREFS_NAME = "adhan_live_prefs"
        const val KEY_ENABLED = "live_notification_enabled"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val title = call.argument<String>("title") ?: "Adhan App"
                    val body = call.argument<String>("body") ?: "Prayer times"
                    startForegroundService(title, body)
                    setEnabled(true)
                    result.success(true)
                }
                "stopService" -> {
                    stopForegroundService()
                    setEnabled(false)
                    result.success(true)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "Adhan App"
                    val body = call.argument<String>("body") ?: "Prayer times"
                    updateNotification(title, body)
                    result.success(true)
                }
                "isServiceRunning" -> {
                    result.success(AdhanForegroundService.isRunning())
                }
                "isEnabled" -> {
                    result.success(isEnabled())
                }
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setEnabled(enabled)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startForegroundService(title: String, body: String) {
        val intent = Intent(this, AdhanForegroundService::class.java).apply {
            putExtra(AdhanForegroundService.EXTRA_TITLE, title)
            putExtra(AdhanForegroundService.EXTRA_BODY, body)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopForegroundService() {
        val intent = Intent(this, AdhanForegroundService::class.java).apply {
            action = AdhanForegroundService.ACTION_STOP
        }
        startService(intent)
    }

    private fun updateNotification(title: String, body: String) {
        val service = AdhanForegroundService.getInstance()
        if (service != null) {
            service.updateNotificationContent(title, body)
        } else {
            // Service not running, start it
            startForegroundService(title, body)
        }
    }

    private fun isEnabled(): Boolean {
        return getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)
    }

    private fun setEnabled(enabled: Boolean) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, enabled)
            .apply()
    }
}
