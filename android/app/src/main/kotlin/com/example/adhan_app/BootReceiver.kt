package com.example.adhan_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver that handles device boot and time changes
 * Restarts the foreground service if it was previously enabled
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        const val TAG = "BootReceiver"
        const val PREFS_NAME = "adhan_live_prefs"
        const val KEY_ENABLED = "live_notification_enabled"
    }
    
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        Log.d(TAG, "Received broadcast: $action")
        
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIMEZONE_CHANGED,
            "android.intent.action.TIME_SET" -> {
                Log.d(TAG, "Rescheduling alarms after $action")
                
                // Reschedule Adhan alarms from cached prayer times
                try {
                    AdhanAlarmScheduler.rescheduleFromCache(context)
                    Log.d(TAG, "Alarms rescheduled successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to reschedule alarms: ${e.message}")
                }
                
                // Check if live notification was enabled
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val isEnabled = prefs.getBoolean(KEY_ENABLED, false)
                
                if (isEnabled) {
                    Log.d(TAG, "Live notification was enabled, restarting service")
                    startService(context)
                } else {
                    Log.d(TAG, "Live notification was disabled, not starting service")
                }
            }
        }
    }
    
    private fun startService(context: Context) {
        val serviceIntent = Intent(context, AdhanForegroundService::class.java)
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start service: ${e.message}")
        }
    }
}
