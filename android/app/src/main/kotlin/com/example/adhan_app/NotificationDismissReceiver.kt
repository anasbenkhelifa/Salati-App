package com.example.adhan_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver that handles notification dismissal
 * When the notification is dismissed (if possible), this receiver restarts it
 */
class NotificationDismissReceiver : BroadcastReceiver() {
    
    companion object {
        const val TAG = "NotificationDismissReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "Notification dismissed - restarting service")
        
        val title = intent?.getStringExtra(AdhanForegroundService.EXTRA_TITLE) ?: "Adhan App"
        val body = intent?.getStringExtra(AdhanForegroundService.EXTRA_BODY) ?: "Prayer times"
        
        // Restart the foreground service
        val serviceIntent = Intent(context, AdhanForegroundService::class.java).apply {
            putExtra(AdhanForegroundService.EXTRA_TITLE, title)
            putExtra(AdhanForegroundService.EXTRA_BODY, body)
        }
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Service restart initiated")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart service: ${e.message}")
        }
    }
}
