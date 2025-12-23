package com.example.adhan_app

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground Service for persistent live prayer notification
 * This service keeps running even when the app is closed
 */
class AdhanForegroundService : Service() {
    
    companion object {
        const val TAG = "AdhanForegroundService"
        const val CHANNEL_ID = "adhan_live_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.example.adhan_app.STOP_SERVICE"
        const val ACTION_UPDATE = "com.example.adhan_app.UPDATE_NOTIFICATION"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        
        // Singleton reference for updates
        @Volatile
        private var instance: AdhanForegroundService? = null
        
        fun getInstance(): AdhanForegroundService? = instance
        
        fun isRunning(): Boolean = instance != null
    }
    
    private val handler = Handler(Looper.getMainLooper())
    private var currentTitle = "Adhan App"
    private var currentBody = "Prayer times"
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "Service created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")
        
        when (intent?.action) {
            ACTION_STOP -> {
                Log.d(TAG, "Stopping service via ACTION_STOP")
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                val body = intent.getStringExtra(EXTRA_BODY) ?: currentBody
                updateNotificationContent(title, body)
            }
            else -> {
                // Start or restart service
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: currentTitle
                val body = intent?.getStringExtra(EXTRA_BODY) ?: currentBody
                startForegroundWithNotification(title, body)
            }
        }
        
        // START_STICKY ensures service restarts if killed by system
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        Log.d(TAG, "Service destroyed")
        instance = null
        super.onDestroy()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Prayer Times Live",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Live prayer time notifications"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
                enableLights(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }
    
    private fun startForegroundWithNotification(title: String, body: String) {
        currentTitle = title
        currentBody = body
        
        val notification = buildNotification(title, body)
        startForeground(NOTIFICATION_ID, notification)
        Log.d(TAG, "Started foreground with notification: $title")
    }
    
    fun updateNotificationContent(title: String, body: String) {
        currentTitle = title
        currentBody = body
        
        val notification = buildNotification(title, body)
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun buildNotification(title: String, body: String): Notification {
        // Intent to open app when notification is tapped
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Delete intent - triggered when notification is dismissed
        // This will restart the notification via our BroadcastReceiver
        val dismissIntent = Intent(this, NotificationDismissReceiver::class.java).apply {
            action = "com.example.adhan_app.NOTIFICATION_DISMISSED"
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            this,
            100,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_stat_adhan) // Custom app icon for notification
            .setOngoing(true)  // Cannot be dismissed by swipe (mostly)
            .setAutoCancel(false)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openAppPendingIntent)
            .setDeleteIntent(dismissPendingIntent)  // Repost if somehow dismissed
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
}
