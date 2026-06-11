package com.example.adhan_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.*

/**
 * BroadcastReceiver that fires at midnight to:
 * 1. Reschedule all prayer alarms for the new day
 * 2. Force the foreground service to refresh its cached data
 * 
 * This ensures alarms continue to work even when the phone is offline overnight.
 */
class MidnightRefreshReceiver : BroadcastReceiver() {
    
    companion object {
        const val TAG = "MidnightRefreshReceiver"
        const val MIDNIGHT_ALARM_REQUEST_CODE = 9999
        
        /**
         * Schedule the midnight refresh alarm
         */
        fun scheduleMidnightAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Calculate next midnight
            val midnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1) // 00:01 to avoid edge cases
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            val intent = Intent(context, MidnightRefreshReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                MIDNIGHT_ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Use setExactAndAllowWhileIdle for reliable Doze firing
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    midnight.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    midnight.timeInMillis,
                    pendingIntent
                )
            }
            
            Log.d(TAG, "Scheduled midnight refresh for ${midnight.time}")
        }
        
        /**
         * Cancel the midnight alarm
         */
        fun cancelMidnightAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, MidnightRefreshReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                MIDNIGHT_ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "Cancelled midnight alarm")
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Midnight refresh triggered!")
        
        try {
            // 1. Reschedule all prayer alarms for today (also re-arms the
            //    tomorrow-Fajr fallback as backup)
            AdhanAlarmScheduler.scheduleAllTodayAlarms(context)

            // 2. Restart the foreground service to refresh notification
            val serviceIntent = Intent(context, AdhanForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            // 4. Schedule the next midnight alarm (daily repeating)
            scheduleMidnightAlarm(context)
            
            Log.d(TAG, "Midnight refresh completed - alarms rescheduled")
        } catch (e: Exception) {
            Log.e(TAG, "Error during midnight refresh: ${e.message}")
        }
    }
}
