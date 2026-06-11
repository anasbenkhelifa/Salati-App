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

        private const val NATIVE_PREFS_NAME = "adhan_live_prefs"
        private const val KEY_LAST_FIRED_OCCURRENCE = "last_fired_occurrence"
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

        // Deduplicate: the regular alarm and the tomorrow-Fajr fallback can both
        // fire for the same occurrence (possibly ~1 minute apart). The occurrence
        // key is date-scoped, so a repeat means this prayer was already handled.
        // TEST_ alarms are exempt so repeated manual tests still work.
        val nativePrefs = context.getSharedPreferences(NATIVE_PREFS_NAME, Context.MODE_PRIVATE)
        if (occurrenceKey.isNotEmpty() && !occurrenceKey.startsWith("TEST_")) {
            val lastFired = nativePrefs.getString(KEY_LAST_FIRED_OCCURRENCE, null)
            if (lastFired == occurrenceKey) {
                Log.d(TAG, "Occurrence $occurrenceKey already fired, skipping duplicate alarm")
                // Still keep the alarm chain alive
                AdhanAlarmScheduler.scheduleNextAlarm(context)
                return
            }
            nativePrefs.edit().putString(KEY_LAST_FIRED_OCCURRENCE, occurrenceKey).apply()
        }

        // Acquire a partial wake lock to ensure we complete our work
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "AdhanApp::AlarmWakeLock"
        )
        wakeLock.acquire(10 * 1000L) // 10 seconds max
        
        try {
            // Keep the alarm chain alive no matter which alert mode runs below
            // (silent/vibrate used to return early and skip rescheduling)
            AdhanAlarmScheduler.scheduleNextAlarm(context)

            // Get language preference from SharedPreferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isArabic = prefs.getString("flutter.app_language", "ar") == "ar"
            
            // Get the prayer key from prayer ID (0=fajr, 1=dhuhr, etc.)
            val prayerKeys = arrayOf("fajr", "dhuhr", "asr", "maghrib", "isha")
            val prayerKey = if (prayerId in 0..4) prayerKeys[prayerId] else "fajr"
            
            // Read adhan selection from SharedPreferences
            // The selection is stored as JSON: {"fajr":"default","dhuhr":"custom_123",...}
            val selectionsJson = prefs.getString("flutter.adhan_selections", null)
            var adhanPath = "assets/audio/adhan.mp3"
            var isAsset = true
            
            if (selectionsJson != null) {
                try {
                    val selections = org.json.JSONObject(selectionsJson)
                    val selectedAdhanId = selections.optString(prayerKey, "default")
                    Log.d(TAG, "Selected adhan for $prayerKey: $selectedAdhanId")
                    
                    when {
                        selectedAdhanId == "medina" -> {
                            adhanPath = "assets/audio/medina_adhan.mp3"
                            isAsset = true
                            Log.d(TAG, "Using bundled medina adhan")
                        }
                        selectedAdhanId != "default" && selectedAdhanId.startsWith("custom_") -> {
                            // Custom adhan - read from custom adhans list
                            val customAdhansJson = prefs.getString("flutter.custom_adhans", null)
                            if (customAdhansJson != null) {
                                val customAdhans = org.json.JSONArray(customAdhansJson)
                                for (i in 0 until customAdhans.length()) {
                                    val adhan = customAdhans.getJSONObject(i)
                                    if (adhan.getString("id") == selectedAdhanId) {
                                        adhanPath = adhan.getString("filePath")
                                        isAsset = adhan.optBoolean("isAsset", false)
                                        Log.d(TAG, "Found custom adhan: $adhanPath")
                                        break
                                    }
                                }
                            }
                        }
                        selectedAdhanId != "default" -> {
                            Log.w(TAG, "Unknown adhan id '$selectedAdhanId', falling back to default")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing adhan selection: ${e.message}")
                }
            }
            
            Log.d(TAG, "Final adhan path: $adhanPath, isAsset: $isAsset")
            
            // Check alert mode for this prayer (0=sound, 1=vibrate, 2=silent)
            // Flutter saves as: flutter.prayer_alert_mode_fajr = 0, 1, or 2
            val alertModeKey = "flutter.prayer_alert_mode_$prayerKey"
            val alertModeInt = prefs.getLong(alertModeKey, 0L).toInt()
            val alertMode = when (alertModeInt) {
                1 -> "vibrate"
                2 -> "silent"
                else -> "sound"
            }
            Log.d(TAG, "Alert mode for $prayerKey: $alertMode (raw: $alertModeInt from key: $alertModeKey)")
            
            // Handle based on alert mode
            when (alertMode) {
                "silent" -> {
                    // Silent mode - do nothing, don't play adhan or vibrate
                    Log.d(TAG, "Prayer $prayerName is set to silent, skipping adhan")
                    return
                }
                "vibrate" -> {
                    // Vibrate mode - vibrate only, no audio
                    Log.d(TAG, "Prayer $prayerName is set to vibrate only")
                    val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                        vibratorManager.defaultVibrator
                    } else {
                        @Suppress("DEPRECATION")
                        context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                    }
                    
                    // Vibrate pattern for prayer time
                    val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(android.os.VibrationEffect.createWaveform(pattern, -1))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(pattern, -1)
                    }
                    return
                }
                // "sound" - continue to full adhan playback
            }
            
            // Start the foreground service for Adhan playback (sound mode only)
            val serviceIntent = Intent(context, AdhanForegroundService::class.java).apply {
                action = AdhanForegroundService.ACTION_START_ADHAN
                putExtra(AdhanForegroundService.EXTRA_PRAYER_NAME, prayerName)
                putExtra(AdhanForegroundService.EXTRA_PRAYER_TIME, prayerTime)
                putExtra(AdhanForegroundService.EXTRA_IS_ARABIC, isArabic)
                putExtra(AdhanForegroundService.EXTRA_OCCURRENCE_KEY, occurrenceKey)
                putExtra(AdhanForegroundService.EXTRA_ADHAN_PATH, adhanPath)
                putExtra(AdhanForegroundService.EXTRA_IS_ASSET, isAsset)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            Log.d(TAG, "AdhanForegroundService started for $prayerName with adhan: $adhanPath")

        } catch (e: Exception) {
            Log.e(TAG, "Error starting Adhan service: ${e.message}", e)
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
}
