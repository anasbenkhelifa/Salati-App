package com.example.adhan_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * Helper class for scheduling Adhan alarms using AlarmManager.
 * Uses setExactAndAllowWhileIdle() for reliable firing even in Doze mode.
 */
object AdhanAlarmScheduler {
    
    const val TAG = "AdhanAlarmScheduler"
    private const val ALARM_REQUEST_CODE_BASE = 5000
    
    // Prayer IDs for alarm identification
    const val PRAYER_FAJR = 0
    const val PRAYER_DHUHR = 1
    const val PRAYER_ASR = 2
    const val PRAYER_MAGHRIB = 3
    const val PRAYER_ISHA = 4
    
    private val prayerNames = arrayOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
    
    /**
     * Check if exact alarms are allowed (Android 12+ requires permission)
     */
    fun isExactAlarmAllowed(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true // Always allowed on Android 11 and below
        }
    }
    
    /**
     * Get intent to open exact alarm settings (Android 12+)
     */
    fun getExactAlarmSettingsIntent(context: Context): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = android.net.Uri.parse("package:${context.packageName}")
            }
        } else {
            null
        }
    }
    
    /**
     * Get intent to open battery optimization settings
     */
    fun getBatteryOptimizationIntent(context: Context): Intent {
        return Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
    }
    
    /**
     * Schedule alarm for a specific prayer
     */
    fun scheduleAlarm(
        context: Context,
        prayerId: Int,
        prayerName: String,
        prayerTime: String,
        epochMillis: Long
    ) {
        if (!isExactAlarmAllowed(context)) {
            Log.w(TAG, "Exact alarms not allowed, cannot schedule $prayerName")
            return
        }
        
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Build occurrence key for mute checking
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val occurrenceKey = "${prayerName}_${dateFormat.format(Date(epochMillis))}"
        
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER_ID, prayerId)
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER_TIME, prayerTime)
            putExtra(AdhanAlarmReceiver.EXTRA_SCHEDULED_TIME, epochMillis)
            putExtra(AdhanAlarmReceiver.EXTRA_OCCURRENCE_KEY, occurrenceKey)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE_BASE + prayerId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Use setExactAndAllowWhileIdle for reliable firing in Doze
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                epochMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                epochMillis,
                pendingIntent
            )
        }
        
        Log.d(TAG, "Scheduled $prayerName alarm for ${Date(epochMillis)}")
        
        // Also schedule pre-adhan reminder if enabled
        schedulePreAdhanIfEnabled(context, prayerId, prayerName, epochMillis)
    }
    
    /**
     * Schedule pre-adhan reminder if the feature is enabled
     */
    private fun schedulePreAdhanIfEnabled(
        context: Context,
        prayerId: Int,
        prayerName: String,
        prayerEpochMillis: Long
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Check if pre-adhan is globally enabled
        val globalEnabled = prefs.getBoolean("flutter.pre_adhan_enabled", false)
        if (!globalEnabled) {
            Log.d(TAG, "Pre-adhan disabled globally, skipping for $prayerName")
            return
        }
        
        // Check if this specific prayer has reminder enabled
        val prayerKey = prayerName.lowercase()
        val prayerEnabled = prefs.getBoolean("flutter.pre_adhan_$prayerKey", true)
        if (!prayerEnabled) {
            Log.d(TAG, "Pre-adhan disabled for $prayerName, skipping")
            return
        }
        
        // Get reminder minutes (default 15)
        val minutes = prefs.getInt("flutter.pre_adhan_minutes_$prayerKey", 15)
        
        // Schedule the pre-adhan alarm
        schedulePreAdhanAlarm(context, prayerId, prayerName, prayerEpochMillis, minutes)
    }
    
    /**
     * Schedule a test alarm to fire after delayMs milliseconds
     * This allows testing adhan with app closed
     */
    fun scheduleTestAlarm(
        context: Context,
        prayerId: Int,
        prayerName: String,
        prayerTime: String,
        delayMs: Long
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerTime = System.currentTimeMillis() + delayMs
        
        // Use a special request code for test alarms to not interfere with real alarms
        val testRequestCode = ALARM_REQUEST_CODE_BASE + 100 + prayerId
        
        // Build occurrence key for mute checking
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val occurrenceKey = "TEST_${prayerName}_${dateFormat.format(Date(triggerTime))}"
        
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER_ID, prayerId)
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER_TIME, prayerTime)
            putExtra(AdhanAlarmReceiver.EXTRA_SCHEDULED_TIME, triggerTime)
            putExtra(AdhanAlarmReceiver.EXTRA_OCCURRENCE_KEY, occurrenceKey)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            testRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Use setExactAndAllowWhileIdle for reliable firing in Doze
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        }
        
        Log.d(TAG, "Scheduled TEST $prayerName alarm for ${Date(triggerTime)} (in ${delayMs}ms)")
    }
    
    // Request code offset for pre-adhan alarms
    private const val PRE_ADHAN_REQUEST_CODE_BASE = 6000
    
    /**
     * Schedule a pre-adhan reminder notification
     * @param minutesBefore How many minutes before the actual prayer time
     */
    fun schedulePreAdhanAlarm(
        context: Context,
        prayerId: Int,
        prayerName: String,
        prayerEpochMillis: Long,
        minutesBefore: Int
    ) {
        if (!isExactAlarmAllowed(context)) {
            Log.w(TAG, "Exact alarms not allowed, cannot schedule pre-adhan for $prayerName")
            return
        }
        
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val reminderTime = prayerEpochMillis - (minutesBefore * 60 * 1000L)
        
        // Only schedule if the reminder time is in the future
        if (reminderTime <= System.currentTimeMillis()) {
            Log.d(TAG, "Pre-adhan time already passed for $prayerName, skipping")
            return
        }
        
        val intent = Intent(context, PreAdhanReceiver::class.java).apply {
            putExtra(PreAdhanReceiver.EXTRA_PRAYER_ID, prayerId)
            putExtra(PreAdhanReceiver.EXTRA_PRAYER_NAME, prayerName)
            putExtra(PreAdhanReceiver.EXTRA_MINUTES_UNTIL, minutesBefore)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            PRE_ADHAN_REQUEST_CODE_BASE + prayerId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                reminderTime,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                reminderTime,
                pendingIntent
            )
        }
        
        Log.d(TAG, "Scheduled pre-adhan for $prayerName at ${Date(reminderTime)} ($minutesBefore min before)")
    }
    
    /**
     * Cancel a pre-adhan reminder alarm
     */
    fun cancelPreAdhanAlarm(context: Context, prayerId: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(context, PreAdhanReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            PRE_ADHAN_REQUEST_CODE_BASE + prayerId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "Cancelled pre-adhan alarm for prayer $prayerId")
    }
    
    /**
     * Cancel a specific prayer alarm
     */
    fun cancelAlarm(context: Context, prayerId: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(context, AdhanAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE_BASE + prayerId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "Cancelled alarm for prayer $prayerId")
    }
    
    /**
     * Cancel all prayer alarms
     */
    fun cancelAllAlarms(context: Context) {
        for (i in 0..4) {
            cancelAlarm(context, i)
        }
        Log.d(TAG, "Cancelled all prayer alarms")
    }
    
    /**
     * Schedule the next upcoming prayer alarm from cache
     */
    fun scheduleNextAlarm(context: Context) {
        Log.d(TAG, "Scheduling next alarm from cache...")
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val prayerTimesJson = prefs.getString("flutter.cached_prayer_times_json", null)
        
        if (prayerTimesJson.isNullOrEmpty()) {
            Log.w(TAG, "No cached prayer times, cannot schedule")
            return
        }
        
        val timings = parsePrayerTimes(prayerTimesJson)
        if (timings == null) {
            Log.e(TAG, "Failed to parse prayer times")
            return
        }
        
        val now = System.currentTimeMillis()
        var nextPrayerId = -1
        var nextPrayerTime = Long.MAX_VALUE
        var nextPrayerName = ""
        var nextPrayerTimeStr = ""
        
        // Find the next upcoming prayer
        for (i in 0..4) {
            val prayerName = prayerNames[i]
            val timeStr = timings[prayerName] ?: continue
            val prayerEpoch = parseTimeToEpoch(timeStr)
            
            if (prayerEpoch > now && prayerEpoch < nextPrayerTime) {
                nextPrayerId = i
                nextPrayerTime = prayerEpoch
                nextPrayerName = prayerName
                nextPrayerTimeStr = timeStr
            }
        }
        
        if (nextPrayerId >= 0) {
            scheduleAlarm(context, nextPrayerId, nextPrayerName, nextPrayerTimeStr, nextPrayerTime)
        } else {
            Log.d(TAG, "No more prayers today, will reschedule tomorrow")
            // Tomorrow's Fajr will be scheduled when prayer times are refreshed
        }
    }
    
    /**
     * Reschedule all alarms from cache (called on boot/time change)
     */
    fun rescheduleFromCache(context: Context) {
        Log.d(TAG, "Rescheduling all alarms from cache...")
        
        // Cancel existing alarms first
        cancelAllAlarms(context)
        
        // Schedule the next prayer
        scheduleNextAlarm(context)
    }
    
    /**
     * Schedule all remaining prayers for today
     */
    fun scheduleAllTodayAlarms(context: Context) {
        Log.d(TAG, "Scheduling all today's alarms from cache...")
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val prayerTimesJson = prefs.getString("flutter.cached_prayer_times_json", null)
        
        if (prayerTimesJson.isNullOrEmpty()) {
            Log.w(TAG, "No cached prayer times")
            return
        }
        
        val timings = parsePrayerTimes(prayerTimesJson)
        if (timings == null) {
            Log.e(TAG, "Failed to parse prayer times")
            return
        }
        
        val now = System.currentTimeMillis()
        var scheduledCount = 0
        
        for (i in 0..4) {
            val prayerName = prayerNames[i]
            val timeStr = timings[prayerName] ?: continue
            val prayerEpoch = parseTimeToEpoch(timeStr)
            
            // Only schedule future prayers
            if (prayerEpoch > now) {
                scheduleAlarm(context, i, prayerName, timeStr, prayerEpoch)
                scheduledCount++
            }
        }
        
        Log.d(TAG, "Scheduled $scheduledCount alarms for today")
    }
    
    /**
     * Parse prayer times JSON to map
     */
    private fun parsePrayerTimes(json: String): Map<String, String>? {
        return try {
            val root = JSONObject(json)
            val data = root.optJSONObject("data") ?: root
            val timings = data.optJSONObject("timings") ?: return null
            
            mapOf(
                "Fajr" to (timings.optString("Fajr", "") ?: ""),
                "Dhuhr" to (timings.optString("Dhuhr", "") ?: ""),
                "Asr" to (timings.optString("Asr", "") ?: ""),
                "Maghrib" to (timings.optString("Maghrib", "") ?: ""),
                "Isha" to (timings.optString("Isha", "") ?: "")
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing prayer times: $e")
            null
        }
    }
    
    /**
     * Parse time string (HH:mm) to epoch millis for today
     */
    private fun parseTimeToEpoch(timeStr: String): Long {
        return try {
            val parts = timeStr.split(":")
            if (parts.size < 2) return 0
            
            val cal = Calendar.getInstance()
            cal.set(Calendar.HOUR_OF_DAY, parts[0].toInt())
            cal.set(Calendar.MINUTE, parts[1].toInt())
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            
            cal.timeInMillis
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing time $timeStr: $e")
            0
        }
    }
    
    /**
     * Parse time string (HH:mm) to epoch millis for tomorrow
     */
    private fun parseTimeToTomorrowEpoch(timeStr: String): Long {
        return try {
            val parts = timeStr.split(":")
            if (parts.size < 2) return 0
            
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_MONTH, 1) // Tomorrow
            cal.set(Calendar.HOUR_OF_DAY, parts[0].toInt())
            cal.set(Calendar.MINUTE, parts[1].toInt())
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            
            cal.timeInMillis
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing tomorrow time $timeStr: $e")
            0
        }
    }
    
    /**
     * Schedule tomorrow's Fajr alarm using today's cached Fajr time.
     * This ensures Fajr fires even when phone is offline overnight.
     */
    fun scheduleTomorrowFajr(context: Context) {
        Log.d(TAG, "Scheduling tomorrow's Fajr alarm...")
        
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val prayerTimesJson = prefs.getString("flutter.cached_prayer_times_json", null)
        
        if (prayerTimesJson.isNullOrEmpty()) {
            Log.w(TAG, "No cached prayer times for tomorrow's Fajr")
            return
        }
        
        val timings = parsePrayerTimes(prayerTimesJson)
        if (timings == null) {
            Log.e(TAG, "Failed to parse prayer times for tomorrow's Fajr")
            return
        }
        
        val fajrTimeStr = timings["Fajr"]
        if (fajrTimeStr.isNullOrEmpty()) {
            Log.e(TAG, "No Fajr time in cache")
            return
        }
        
        val tomorrowFajrEpoch = parseTimeToTomorrowEpoch(fajrTimeStr)
        if (tomorrowFajrEpoch <= System.currentTimeMillis()) {
            Log.w(TAG, "Tomorrow's Fajr time calculation failed")
            return
        }
        
        // Use a special request code for tomorrow's Fajr (offset by 1000)
        val requestCode = ALARM_REQUEST_CODE_BASE + PRAYER_FAJR + 1000
        
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_MONTH, 1) }
        val occurrenceKey = "Fajr_${dateFormat.format(tomorrow.time)}"
        
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER_ID, PRAYER_FAJR)
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER_NAME, "Fajr")
            putExtra(AdhanAlarmReceiver.EXTRA_PRAYER_TIME, fajrTimeStr)
            putExtra(AdhanAlarmReceiver.EXTRA_SCHEDULED_TIME, tomorrowFajrEpoch)
            putExtra(AdhanAlarmReceiver.EXTRA_OCCURRENCE_KEY, occurrenceKey)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                tomorrowFajrEpoch,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                tomorrowFajrEpoch,
                pendingIntent
            )
        }
        
        Log.d(TAG, "Scheduled tomorrow's Fajr for ${Date(tomorrowFajrEpoch)} (key: $occurrenceKey)")
    }
}
