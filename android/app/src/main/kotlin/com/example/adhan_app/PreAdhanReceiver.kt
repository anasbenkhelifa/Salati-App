package com.example.adhan_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * BroadcastReceiver for pre-adhan reminder notifications.
 * Triggered X minutes before actual prayer time.
 */
class PreAdhanReceiver : BroadcastReceiver() {
    
    companion object {
        const val TAG = "PreAdhanReceiver"
        const val EXTRA_PRAYER_ID = "prayer_id"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_MINUTES_UNTIL = "minutes_until"
        const val CHANNEL_ID = "pre_adhan_channel"
        const val NOTIFICATION_ID_BASE = 3000
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val prayerId = intent.getIntExtra(EXTRA_PRAYER_ID, 0)
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
        val minutesUntil = intent.getIntExtra(EXTRA_MINUTES_UNTIL, 15)
        
        Log.d(TAG, "Pre-adhan reminder: $prayerName in $minutesUntil minutes")
        
        // Check if pre-adhan is still enabled
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val globalEnabled = prefs.getBoolean("flutter.pre_adhan_enabled", false)
        val prayerKey = prayerName.lowercase()
        val prayerEnabled = prefs.getBoolean("flutter.pre_adhan_$prayerKey", true)
        
        if (!globalEnabled || !prayerEnabled) {
            Log.d(TAG, "Pre-adhan disabled, skipping notification")
            return
        }
        
        // Get language preference
        val isArabic = prefs.getString("flutter.app_language", "ar") == "ar"
        
        // Create notification channel
        createNotificationChannel(context, isArabic)
        
        // Show reminder notification
        showReminderNotification(context, prayerName, minutesUntil, isArabic, prayerId)
    }
    
    private fun createNotificationChannel(context: Context, isArabic: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = if (isArabic) "تذكير قبل الأذان" else "Pre-Adhan Reminder"
            val description = if (isArabic) {
                "تنبيهات قبل وقت الصلاة"
            } else {
                "Notifications before prayer time"
            }
            
            val channel = NotificationChannel(
                CHANNEL_ID,
                name,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                this.description = description
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 200, 100, 200)
            }
            
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun showReminderNotification(
        context: Context,
        prayerName: String,
        minutesUntil: Int,
        isArabic: Boolean,
        prayerId: Int
    ) {
        val emoji = when (prayerName.lowercase()) {
            "fajr" -> "🌅"
            "dhuhr" -> "☀️"
            "asr" -> "🌤️"
            "maghrib" -> "🌇"
            "isha" -> "🌙"
            else -> "🕌"
        }
        
        val arabicNames = mapOf(
            "fajr" to "الفجر",
            "dhuhr" to "الظهر",
            "asr" to "العصر",
            "maghrib" to "المغرب",
            "isha" to "العشاء"
        )
        
        val localizedPrayerName = if (isArabic) {
            arabicNames[prayerName.lowercase()] ?: prayerName
        } else {
            prayerName
        }
        
        val title = if (isArabic) {
            "$emoji $minutesUntil دقيقة حتى صلاة $localizedPrayerName"
        } else {
            "$emoji $minutesUntil minutes to $localizedPrayerName"
        }
        
        val body = if (isArabic) {
            "استعد للصلاة"
        } else {
            "Prepare for prayer"
        }
        
        // Open app intent
        val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            context, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(0xFF4CAF50.toInt()) // Green for reminder
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(openAppPendingIntent)
            .build()
        
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID_BASE + prayerId, notification)
        
        Log.d(TAG, "Showed pre-adhan notification: $title")
    }
}
