package com.example.adhan_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log

/**
 * BroadcastReceiver that fires from AlarmManager exact alarms.
 * Immediately starts AdhanForegroundService for Adhan playback.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {
    
    companion object {
        const val TAG = "AdhanAlarmReceiver"
        const val EXTRA_PRAYER_ID = "prayer_id"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_TIME = "prayer_time"
        const val EXTRA_SCHEDULED_TIME = "scheduled_time"
        const val EXTRA_OCCURRENCE_KEY = "occurrence_key"
    }
    
    override fun onReceive(context: Context, intent: Intent?) {
        val prayerId = intent?.getIntExtra(EXTRA_PRAYER_ID, -1) ?: -1
        val prayerName = intent?.getStringExtra(EXTRA_PRAYER_NAME) ?: ""
        val prayerTime = intent?.getStringExtra(EXTRA_PRAYER_TIME) ?: ""
        val occurrenceKey = intent?.getStringExtra(EXTRA_OCCURRENCE_KEY) ?: ""
        val scheduledTime = intent?.getLongExtra(EXTRA_SCHEDULED_TIME, 0) ?: 0
        
        Log.d(TAG, "======== ADHAN ALARM FIRED ========")
        Log.d(TAG, "Prayer: $prayerName ($prayerId)")
        Log.d(TAG, "Time: $prayerTime")
        Log.d(TAG, "Occurrence: $occurrenceKey")
        Log.d(TAG, "Scheduled: $scheduledTime, Now: ${System.currentTimeMillis()}")
        Log.d(TAG, "===================================")
        
        if (prayerId < 0 || prayerName.isEmpty()) {
            Log.e(TAG, "Invalid alarm data, ignoring")
            return
        }
        
        // Acquire a partial wake lock to ensure we complete our work
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "AdhanApp::AlarmWakeLock"
        )
        wakeLock.acquire(10 * 1000L) // 10 seconds max
        
        try {
            // Get language preference from SharedPreferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isArabic = prefs.getString("flutter.app_language", "en") == "ar"
            
            // Start the foreground service for Adhan playback
            val serviceIntent = Intent(context, AdhanForegroundService::class.java).apply {
                action = AdhanForegroundService.ACTION_START_ADHAN
                putExtra(AdhanForegroundService.EXTRA_PRAYER_NAME, prayerName)
                putExtra(AdhanForegroundService.EXTRA_PRAYER_TIME, prayerTime)
                putExtra(AdhanForegroundService.EXTRA_IS_ARABIC, isArabic)
                putExtra(AdhanForegroundService.EXTRA_OCCURRENCE_KEY, occurrenceKey)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            Log.d(TAG, "AdhanForegroundService started for $prayerName")
            
            // Reschedule the next alarm after this one fires
            AdhanAlarmScheduler.scheduleNextAlarm(context)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Adhan service: ${e.message}", e)
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
}
