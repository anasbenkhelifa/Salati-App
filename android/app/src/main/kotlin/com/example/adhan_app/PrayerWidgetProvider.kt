package com.example.adhan_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.util.Log
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * Home screen widget showing next prayer time and countdown.
 * Reads prayer data from SharedPreferences (same as foreground service).
 */
class PrayerWidgetProvider : AppWidgetProvider() {
    
    companion object {
        const val TAG = "PrayerWidgetProvider"
        
        private val prayerEmojis = mapOf(
            "Fajr" to "🌅",
            "Dhuhr" to "☀️",
            "Asr" to "🌤️",
            "Maghrib" to "🌇",
            "Isha" to "🌙"
        )
        
        private val prayerNamesAr = mapOf(
            "Fajr" to "الفجر",
            "Dhuhr" to "الظهر",
            "Asr" to "العصر",
            "Maghrib" to "المغرب",
            "Isha" to "العشاء"
        )
    }
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isArabic = prefs.getString("flutter.app_language", "ar") == "ar"

        // Today's timings: exact per-date entry from the multi-day cache,
        // legacy single-day projection as fallback
        val timings = AdhanAlarmScheduler.getTimingsForDate(context, Calendar.getInstance())

        val views = RemoteViews(context.packageName, R.layout.prayer_widget)

        if (timings != null) {
            try {
                val now = Calendar.getInstance()
                val prayerOrder = arrayOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")

                var nextPrayer: String? = null
                var nextPrayerTime: String? = null
                var nextPrayerCal: Calendar? = null

                // Find next prayer
                for (prayer in prayerOrder) {
                    val timeStr = timings[prayer] ?: ""
                    if (timeStr.isNotEmpty()) {
                        val prayerCal = parseTime(timeStr, now)
                        if (prayerCal != null && prayerCal.after(now)) {
                            nextPrayer = prayer
                            nextPrayerTime = timeStr
                            nextPrayerCal = prayerCal
                            break
                        }
                    }
                }

                // If no prayer found today, use tomorrow's Fajr (exact entry
                // from the multi-day cache when available)
                if (nextPrayer == null) {
                    val tomorrow = Calendar.getInstance().apply {
                        add(Calendar.DAY_OF_MONTH, 1)
                    }
                    val tomorrowTimings =
                        AdhanAlarmScheduler.getTimingsForDate(context, tomorrow)
                    nextPrayer = "Fajr"
                    nextPrayerTime =
                        tomorrowTimings?.get("Fajr")?.ifEmpty { null }
                            ?: timings["Fajr"] ?: "05:00"
                    nextPrayerCal = parseTime(nextPrayerTime, tomorrow)
                }

                // Update views
                val displayName = if (isArabic) prayerNamesAr[nextPrayer] ?: nextPrayer else nextPrayer
                val emoji = prayerEmojis[nextPrayer] ?: "🕌"

                // Update "Next Prayer" label
                views.setTextViewText(R.id.next_prayer_label,
                    if (isArabic) "الصلاة القادمة" else "Next Prayer")

                views.setTextViewText(R.id.prayer_emoji, emoji)
                views.setTextViewText(R.id.prayer_name, displayName)
                views.setTextViewText(R.id.prayer_time, nextPrayerTime)

                // Calculate countdown
                if (nextPrayerCal != null) {
                    val diffMs = nextPrayerCal.timeInMillis - now.timeInMillis
                    if (diffMs > 0) {
                        val hours = diffMs / (1000 * 60 * 60)
                        val mins = (diffMs / (1000 * 60)) % 60

                        val countdownText = if (isArabic) {
                            if (hours > 0) "بعد ${hours}س ${mins}د" else "بعد ${mins} دقيقة"
                        } else {
                            if (hours > 0) "in ${hours}h ${mins}m" else "in ${mins}m"
                        }
                        views.setTextViewText(R.id.countdown, countdownText)
                    } else {
                        views.setTextViewText(R.id.countdown, "")
                    }
                }

                Log.d(TAG, "Widget updated: $nextPrayer at $nextPrayerTime")
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing prayer times: ${e.message}")
                setNoDataView(views, isArabic)
            }
        } else {
            views.setTextViewText(R.id.next_prayer_label, if (isArabic) "الصلاة القادمة" else "Next Prayer")
            views.setTextViewText(R.id.prayer_name, if (isArabic) "افتح التطبيق" else "Open app")
            views.setTextViewText(R.id.prayer_time, "--:--")
            views.setTextViewText(R.id.countdown, "")
            Log.d(TAG, "No cached prayer times found")
        }
        
        // Set click intent on entire widget root (FrameLayout)
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val pendingIntent = android.app.PendingIntent.getActivity(
                context, 0, launchIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        }
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    
    private fun setNoDataView(views: RemoteViews, isArabic: Boolean) {
        views.setTextViewText(R.id.prayer_emoji, "🕌")
        views.setTextViewText(R.id.next_prayer_label, if (isArabic) "الصلاة القادمة" else "Next Prayer")
        views.setTextViewText(R.id.prayer_name, if (isArabic) "لا توجد بيانات" else "No data")
        views.setTextViewText(R.id.prayer_time, "--:--")
        views.setTextViewText(R.id.countdown, "")
    }
    
    private fun parseTime(timeStr: String, today: Calendar): Calendar? {
        try {
            val cleanTime = timeStr.split(" ")[0] // Remove timezone like "(EET)"
            val parts = cleanTime.split(":")
            if (parts.size >= 2) {
                val hour = parts[0].toInt()
                val minute = parts[1].toInt()
                
                return Calendar.getInstance().apply {
                    set(Calendar.YEAR, today.get(Calendar.YEAR))
                    set(Calendar.MONTH, today.get(Calendar.MONTH))
                    set(Calendar.DAY_OF_MONTH, today.get(Calendar.DAY_OF_MONTH))
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing time: $timeStr - ${e.message}")
        }
        return null
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        // Handle home_widget update broadcast
        if (intent.action == "es.antonborri.home_widget.action.UPDATE") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, PrayerWidgetProvider::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }
}
