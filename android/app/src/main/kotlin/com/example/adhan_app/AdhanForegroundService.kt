package com.example.adhan_app

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.res.AssetFileDescriptor
import android.database.ContentObserver
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.VolumeProviderCompat
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * Foreground Service for:
 * 1) Persistent live prayer countdown notification
 * 2) Adhan audio playback with ongoing "Adhan is playing" notification
 * Computes everything NATIVELY from SharedPreferences cache - no Flutter dependency
 */
class AdhanForegroundService : Service() {
    
    companion object {
        const val TAG = "AdhanForegroundService"
        const val CHANNEL_ID = "adhan_live_channel"
        const val CHANNEL_ID_PLAYING = "adhan_playing_channel"
        const val NOTIFICATION_ID = 1001
        const val NOTIFICATION_ID_PLAYING = 1002
        const val ACTION_STOP = "com.example.adhan_app.STOP_SERVICE"
        const val ACTION_START_ADHAN = "com.example.adhan_app.START_ADHAN"
        
        // For backward compatibility with MainActivity/NotificationDismissReceiver
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_TIME = "prayer_time"
        const val EXTRA_IS_ARABIC = "is_arabic"
        const val EXTRA_OCCURRENCE_KEY = "occurrence_key"
        const val EXTRA_ADHAN_PATH = "adhan_path"
        const val EXTRA_IS_ASSET = "is_asset"
        
        // Grace window: 30 minutes after prayer
        const val GRACE_WINDOW_MINUTES = 30
        // Warning: last 20 minutes before prayer
        const val WARNING_MINUTES = 20
        
        @Volatile
        private var instance: AdhanForegroundService? = null
        
        fun getInstance(): AdhanForegroundService? = instance
        fun isRunning(): Boolean = instance != null
    }
    
    private val handler = Handler(Looper.getMainLooper())
    private var tickerRunning = false
    private lateinit var prefs: SharedPreferences
    
    // Adhan playback state
    private var mediaPlayer: MediaPlayer? = null
    var isAdhanPlaying = false
        private set
    private var currentOccurrenceKey: String? = null
    private var currentPrayerName: String? = null
    private var currentPrayerTime: String? = null
    private var currentIsArabic: Boolean = false
    
    // Hardware stop listeners - for Power/Volume button detection
    private var screenOffReceiver: BroadcastReceiver? = null
    private var volumeObserver: ContentObserver? = null
    private var audioManager: AudioManager? = null
    
    // Multi-stream volume baseline tracking for robust detection
    private var baselineMusicVolume: Int = -1
    private var baselineAlarmVolume: Int = -1
    private var baselineRingVolume: Int = -1
    private var volumeChangeDebounceRunnable: Runnable? = null
    private val VOLUME_DEBOUNCE_MS = 50L  // Debounce window
    
    // MediaSession for media button fallback (headset buttons, etc.)
    private var mediaSession: MediaSessionCompat? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    
    // Max volume override
    private var maxVolumeOverrideEnabled = false
    private var savedAlarmVolume: Int = -1  // To restore after playback
    
    // Prayer names
    private val prayerNamesEn = arrayOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
    private val prayerNamesAr = arrayOf("الفجر", "الظهر", "العصر", "المغرب", "العشاء")
    
    // Hijri month names (Arabic)
    private val hijriMonthsAr = arrayOf(
        "محرم", "صفر", "ربيع الأول", "ربيع الثاني",
        "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان",
        "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
    )
    private val hijriMonthsEn = arrayOf(
        "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
        "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
    )
    
    private val tickerRunnable = object : Runnable {
        override fun run() {
            if (!isAdhanPlaying) {
                updateNotificationFromCache()
            }
            handler.postDelayed(this, 1000) // Update every second
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        Log.d(TAG, "Service created")
        createNotificationChannel()
        createAdhanPlayingChannel()
        
        // Schedule midnight refresh alarm for daily prayer time rescheduling
        MidnightRefreshReceiver.scheduleMidnightAlarm(this)
        
        // Schedule tomorrow's Fajr as fallback for overnight reliability
        AdhanAlarmScheduler.scheduleTomorrowFajr(this)
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")
        
        when (intent?.action) {
            ACTION_STOP -> {
                Log.d(TAG, "Stopping service via ACTION_STOP")
                stopAdhanPlayback(isServiceStopping = true)
                stopTicker()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START_ADHAN -> {
                Log.d(TAG, "Starting Adhan playback")
                val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: ""
                val prayerTime = intent.getStringExtra(EXTRA_PRAYER_TIME) ?: ""
                val isArabic = intent.getBooleanExtra(EXTRA_IS_ARABIC, false)
                val occurrenceKey = intent.getStringExtra(EXTRA_OCCURRENCE_KEY) ?: ""
                val adhanPath = intent.getStringExtra(EXTRA_ADHAN_PATH) ?: "assets/audio/adhan.mp3"
                val isAsset = intent.getBooleanExtra(EXTRA_IS_ASSET, true)
                startAdhanPlayback(prayerName, prayerTime, isArabic, occurrenceKey, adhanPath, isAsset)
            }
            else -> {
                // Start or restart service - load from cache immediately
                startForegroundWithCachedData()
                startTicker()
            }
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        Log.d(TAG, "Service destroyed")
        stopAdhanPlayback()
        stopTicker()
        instance = null
        super.onDestroy()
    }
    
    private fun startTicker() {
        if (tickerRunning) {
            Log.d(TAG, "Ticker already running, skipping")
            return
        }
        tickerRunning = true
        handler.post(tickerRunnable)
        Log.d(TAG, "Ticker started")
    }
    
    private fun stopTicker() {
        tickerRunning = false
        handler.removeCallbacks(tickerRunnable)
        Log.d(TAG, "Ticker stopped")
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
    
    private fun createAdhanPlayingChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID_PLAYING,
                "Adhan Playing",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notification shown while Adhan is playing"
                setShowBadge(true)
                setSound(null, null) // We play our own audio
                enableVibration(false) // We handle vibration ourselves
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d(TAG, "Adhan playing channel created")
        }
    }
    
    // ==================== ADHAN PLAYBACK ====================
    
    /**
     * Check if an occurrence is muted in SharedPreferences
     */
    fun isOccurrenceMuted(occurrenceKey: String): Boolean {
        return prefs.getBoolean("flutter.muted_occurrence_$occurrenceKey", false)
    }
    
    /**
     * Start Adhan playback with notification
     */
    fun startAdhanPlayback(prayerName: String, prayerTime: String, isArabic: Boolean, occurrenceKey: String, adhanPath: String = "assets/audio/adhan.mp3", isAsset: Boolean = true) {
        Log.d(TAG, "startAdhanPlayback: $prayerName at $prayerTime, key=$occurrenceKey, path=$adhanPath, isAsset=$isAsset")
        
        // Check if this occurrence is muted
        if (isOccurrenceMuted(occurrenceKey)) {
            Log.d(TAG, "Occurrence $occurrenceKey is muted, skipping playback")
            return
        }
        
        // Store current playback info
        isAdhanPlaying = true
        currentOccurrenceKey = occurrenceKey
        currentPrayerName = prayerName
        currentPrayerTime = prayerTime
        currentIsArabic = isArabic
        
        // Check max volume override setting
        maxVolumeOverrideEnabled = prefs.getBoolean("flutter.max_volume_override", false)
        if (maxVolumeOverrideEnabled) {
            // Save current alarm volume and set to max
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            savedAlarmVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
            val maxVolume = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            am.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)
            Log.d(TAG, "Max volume override enabled: saved=$savedAlarmVolume, set to max=$maxVolume")
        }
        
        // Vibrate first
        vibrateForAdhan()
        
        // Play audio
        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                if (isAsset) {
                    // Asset file - use flutter_assets path
                    val assetPath = if (adhanPath.startsWith("assets/")) {
                        "flutter_assets/$adhanPath"
                    } else {
                        "flutter_assets/assets/audio/adhan.mp3"
                    }
                    Log.d(TAG, "Playing asset: $assetPath")
                    val afd: AssetFileDescriptor = assets.openFd(assetPath)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                } else {
                    // Custom file from app storage
                    Log.d(TAG, "Playing file: $adhanPath")
                    setDataSource(adhanPath)
                }
                
                setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build())
                
                setOnPreparedListener {
                    Log.d(TAG, "MediaPlayer prepared, starting playback after delay")
                    // Small delay to let Android audio routing and AudioFocus settle
                    // This prevents the "stuttering" effect on Adhan start
                    handler.postDelayed({
                        try {
                            if (isAdhanPlaying && mediaPlayer != null) {
                                start()
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error starting playback after delay: \${e.message}")
                        }
                    }, 400)
                }
                
                setOnCompletionListener {
                    Log.d(TAG, "Adhan playback completed")
                    stopAdhanPlayback()
                }
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    stopAdhanPlayback()
                    true
                }
                
                prepareAsync()
            }
            Log.d(TAG, "MediaPlayer initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Adhan playback: ${e.message}")
            isAdhanPlaying = false
            return
        }
        
        // Update notification to "Adhan is playing" mode
        updateToPlayingNotification()
        
        // Register hardware stop listeners (power button, volume buttons)
        registerHardwareStopListeners()
    }
    
    /**
     * Stop Adhan playback and revert notification
     */
    fun stopAdhanPlayback(isServiceStopping: Boolean = false) {
        Log.d(TAG, "stopAdhanPlayback")
        
        // Unregister hardware stop listeners first
        unregisterHardwareStopListeners()
        
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping MediaPlayer: ${e.message}")
        }
        
        isAdhanPlaying = false
        currentOccurrenceKey = null
        currentPrayerName = null
        currentPrayerTime = null
        
        // Restore volume if max override was enabled
        if (maxVolumeOverrideEnabled && savedAlarmVolume >= 0) {
            try {
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.setStreamVolume(AudioManager.STREAM_ALARM, savedAlarmVolume, 0)
                Log.d(TAG, "Restored alarm volume to $savedAlarmVolume")
            } catch (e: Exception) {
                Log.e(TAG, "Error restoring volume: ${e.message}")
            }
            savedAlarmVolume = -1
        }
        
        // Cancel the playing notification
        val manager = getSystemService(NotificationManager::class.java)
        manager.cancel(NOTIFICATION_ID_PLAYING)
        
        if (!isServiceStopping) {
            try {
                // Revert to normal countdown notification using startForeground
                val content = computeNotificationContent()
                val (title, body) = content
                val notification = buildNotification(title, body)
                startForeground(NOTIFICATION_ID, notification)
                Log.d(TAG, "Reverted to countdown notification")
            } catch (e: Exception) {
                Log.e(TAG, "Error reverting notification: ${e.message}")
            }
        }
    }
    
    /**
     * Vibrate for Adhan (3 pulses)
     */
    private fun vibrateForAdhan() {
        try {
            val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val vibrator = vibratorManager.defaultVibrator
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(pattern, -1)
                }
            }
            Log.d(TAG, "Vibration triggered")
        } catch (e: Exception) {
            Log.e(TAG, "Vibration error: ${e.message}")
        }
    }
    
    /**
     * Register listeners for hardware button stop (power button via screen off, volume buttons)
     * Uses multi-stream ContentObserver for robust volume key detection
     */
    private fun registerHardwareStopListeners() {
        Log.d(TAG, "Registering hardware stop listeners with multi-stream volume observer")
        
        // Initialize AudioManager
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Request audio focus with AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
        // Some devices ignore EXCLUSIVE when other media is playing
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(audioAttributes)
                .setOnAudioFocusChangeListener { focusChange ->
                    Log.d(TAG, "Audio focus change: $focusChange")
                }
                .build()
            
            val result = audioManager?.requestAudioFocus(audioFocusRequest!!)
            Log.d(TAG, "Audio focus request result: $result")
        } else {
            @Suppress("DEPRECATION")
            audioManager?.requestAudioFocus(
                { Log.d(TAG, "Audio focus change (legacy)") },
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
        }
        
        // Store baseline volumes for ALL relevant streams
        baselineMusicVolume = audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: -1
        baselineAlarmVolume = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: -1
        baselineRingVolume = audioManager?.getStreamVolume(AudioManager.STREAM_RING) ?: -1
        Log.d(TAG, "Baseline volumes - Music: $baselineMusicVolume, Alarm: $baselineAlarmVolume, Ring: $baselineRingVolume")
        
        // Initialize MediaSession (callback only, no VolumeProvider)
        initMediaSession()
        
        // Register screen off receiver (power button detection)
        // Note: This also fires for tap-to-sleep gestures on some phones
        screenOffReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_SCREEN_OFF && isAdhanPlaying) {
                    Log.d(TAG, "Screen off detected - stopping Adhan")
                    handler.post { stopAdhanPlayback() }
                }
            }
        }
        val screenFilter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenOffReceiver, screenFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenOffReceiver, screenFilter)
        }
        Log.d(TAG, "Screen off receiver registered")
        
        // Register robust multi-stream volume observer
        // This observes Settings.System for ANY volume change (Music, Alarm, Ring)
        // Only stops adhan when volume VALUES actually change (button press)
        volumeObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean) {
                if (!isAdhanPlaying) return
                
                // Check all volume streams
                val currentMusic = audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: baselineMusicVolume
                val currentAlarm = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: baselineAlarmVolume
                val currentRing = audioManager?.getStreamVolume(AudioManager.STREAM_RING) ?: baselineRingVolume
                
                val musicChanged = currentMusic != baselineMusicVolume
                val alarmChanged = currentAlarm != baselineAlarmVolume
                val ringChanged = currentRing != baselineRingVolume
                
                // Only stop if actual volume value changed (not just observer triggered)
                if (musicChanged || alarmChanged || ringChanged) {
                    val changeInfo = buildString {
                        if (musicChanged) append("Music: $baselineMusicVolume→$currentMusic ")
                        if (alarmChanged) append("Alarm: $baselineAlarmVolume→$currentAlarm ")
                        if (ringChanged) append("Ring: $baselineRingVolume→$currentRing ")
                    }
                    Log.d(TAG, "Volume change detected: $changeInfo")
                    
                    // Debounce to avoid multiple rapid triggers
                    volumeChangeDebounceRunnable?.let { handler.removeCallbacks(it) }
                    volumeChangeDebounceRunnable = Runnable {
                        if (isAdhanPlaying) {
                            Log.d(TAG, "Debounced volume change - stopping Adhan")
                            stopAdhanPlayback()
                        }
                    }
                    handler.postDelayed(volumeChangeDebounceRunnable!!, VOLUME_DEBOUNCE_MS)
                }
            }
        }
        
        // Register on Settings.System.CONTENT_URI with notifyForDescendants=true
        // This catches changes to VOLUME_MUSIC, VOLUME_ALARM, VOLUME_RING, etc.
        contentResolver.registerContentObserver(
            Settings.System.CONTENT_URI,
            true,  // notifyForDescendants - important for catching all volume changes
            volumeObserver!!
        )
        Log.d(TAG, "Multi-stream volume observer registered")
    }
    
    /**
     * Initialize MediaSession with callback for media button events (headset buttons, etc.)
     * Does NOT use VolumeProvider as it's unreliable for volume key interception
     */
    private fun initMediaSession() {
        mediaSession = MediaSessionCompat(this, "AdhanSession").apply {
            // Set playback state to PLAYING so system knows we're active
            val playbackState = PlaybackStateCompat.Builder()
                .setState(PlaybackStateCompat.STATE_PLAYING, 0, 1f)
                .setActions(
                    PlaybackStateCompat.ACTION_STOP or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_PLAY_PAUSE
                )
                .build()
            setPlaybackState(playbackState)
            
            // Set callback for media button events (play/pause hardware buttons, headsets)
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onStop() {
                    Log.d(TAG, "MediaSession onStop - stopping Adhan")
                    handler.post { stopAdhanPlayback() }
                }
                
                override fun onPause() {
                    Log.d(TAG, "MediaSession onPause - stopping Adhan")
                    handler.post { stopAdhanPlayback() }
                }
                
                override fun onPlay() {
                    // Ignore play commands
                    Log.d(TAG, "MediaSession onPlay - ignored")
                }
                
                override fun onMediaButtonEvent(mediaButtonEvent: Intent?): Boolean {
                    Log.d(TAG, "MediaSession media button event: ${mediaButtonEvent?.action}")
                    // Let default handling occur
                    return super.onMediaButtonEvent(mediaButtonEvent)
                }
            })
            
            // Use local playback (not remote) - let system handle volume normally
            // This allows our ContentObserver to detect volume changes
            setPlaybackToLocal(AudioManager.STREAM_ALARM)
            
            // Activate the session
            isActive = true
            Log.d(TAG, "MediaSession initialized (callback-only, no VolumeProvider)")
        }
    }
    
    /**
     * Unregister hardware stop listeners
     */
    private fun unregisterHardwareStopListeners() {
        Log.d(TAG, "Unregistering hardware stop listeners")
        
        // Cancel any pending debounce
        volumeChangeDebounceRunnable?.let { handler.removeCallbacks(it) }
        volumeChangeDebounceRunnable = null
        
        // Release MediaSession
        mediaSession?.let {
            try {
                it.isActive = false
                it.release()
                Log.d(TAG, "MediaSession released")
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing MediaSession: ${e.message}")
            }
        }
        mediaSession = null
        
        // Abandon audio focus
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let {
                audioManager?.abandonAudioFocusRequest(it)
                Log.d(TAG, "Audio focus abandoned")
            }
            audioFocusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager?.abandonAudioFocus(null)
        }
        
        // Unregister screen off receiver
        screenOffReceiver?.let {
            try {
                unregisterReceiver(it)
                Log.d(TAG, "Screen off receiver unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering screen off receiver: ${e.message}")
            }
        }
        screenOffReceiver = null
        
        // Unregister volume observer
        volumeObserver?.let {
            try {
                contentResolver.unregisterContentObserver(it)
                Log.d(TAG, "Volume observer unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering volume observer: ${e.message}")
            }
        }
        volumeObserver = null
        
        // Reset baselines
        baselineMusicVolume = -1
        baselineAlarmVolume = -1
        baselineRingVolume = -1
        audioManager = null
    }
    
    /**
     * Update notification to "Adhan is playing" mode with premium UX
     * Features:
     * - Full-screen intent for lock screen visibility
     * - MediaStyle for prominent action buttons
     * - Colored notification for visual distinction
     * - Large icon with mosque imagery
     * - Prominent STOP button
     */
    private fun updateToPlayingNotification() {
        val prayerEmoji = when (currentPrayerName?.lowercase()) {
            "fajr", "الفجر" -> "🌅"
            "dhuhr", "الظهر" -> "☀️"
            "asr", "العصر" -> "🌤️"
            "maghrib", "المغرب" -> "🌇"
            "isha", "العشاء" -> "🌙"
            else -> "🕌"
        }
        
        val title = if (currentIsArabic) {
            "$prayerEmoji حان وقت صلاة $currentPrayerName"
        } else {
            "$prayerEmoji Time for $currentPrayerName Prayer"
        }
        
        val body = if (currentIsArabic) {
            "⁧$currentPrayerTime⁩"
        } else {
            "$currentPrayerTime"
        }
        
        val subText = if (currentIsArabic) "اضغط لإيقاف الأذان" else "Tap to stop Adhan"
        
        // Create STOP action with more visible icon
        val stopIntent = Intent(this, AdhanActionReceiver::class.java).apply {
            action = AdhanActionReceiver.ACTION_STOP_ADHAN
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            this, 200, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopLabel = if (currentIsArabic) "⏹ إيقاف" else "⏹ Stop"
        
        // Open app intent
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Full-screen intent for lock screen - shows notification in full-screen mode
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 100, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Use BigTextStyle for expanded view
        val bigTextStyle = NotificationCompat.BigTextStyle()
            .setBigContentTitle(title)
            .bigText(body)
            .setSummaryText(subText)
        
        // Build enhanced notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID_PLAYING)
            .setContentTitle(title)
            .setContentText(body)
            .setSubText(subText)
            .setStyle(bigTextStyle)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(0xFF1565C0.toInt()) // Blue color for notification accent
            .setColorized(true) // Enable colored notification background
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentIntent(openAppPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true) // Full-screen intent for lock screen
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, stopLabel, stopPendingIntent)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setDeleteIntent(stopPendingIntent) // Stop when notification dismissed
            .setTimeoutAfter(10 * 60 * 1000) // Auto-dismiss after 10 minutes as safety
            .build()
        
        // Use startForeground to make this an ongoing foreground notification
        startForeground(NOTIFICATION_ID_PLAYING, notification)
        Log.d(TAG, "Enhanced playing notification started: $title | $body")
    }
    
    private fun startForegroundWithCachedData() {
        val (title, body) = computeNotificationContent()
        val notification = buildNotification(title, body)
        startForeground(NOTIFICATION_ID, notification)
        Log.d(TAG, "Started foreground: $title | $body")
    }
    
    private fun updateNotificationFromCache() {
        val (title, body) = computeNotificationContent()
        val notification = buildNotification(title, body)
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }
    
    /**
     * Public method for backward compatibility with MainActivity
     * Still uses native cache computation - ignores parameters
     */
    fun updateNotificationContent(title: String, body: String) {
        Log.d(TAG, "updateNotificationContent called (using cache instead)")
        updateNotificationFromCache()
    }
    
    /**
     * Public method to refresh notification after Hijri date cache is updated
     * Called from Flutter via MethodChannel when date changes
     */
    fun refreshPrayerNotification() {
        Log.d(TAG, "refreshPrayerNotification called - re-reading cache")
        updateNotificationFromCache()
    }
    
    /**
     * Compute notification content from SharedPreferences cache
     * Returns Pair(title, body)
     */
    private fun computeNotificationContent(): Pair<String, String> {
        // Read cache
        val prayerTimesJson = prefs.getString("flutter.cached_prayer_times_json", null)
        val cachedDate = prefs.getString("flutter.cached_prayer_times_date", null)
        val isArabic = prefs.getString("flutter.app_language", "ar") == "ar"
        val cityAr = prefs.getString("flutter.cached_city_ar", "") ?: ""
        val cityEn = prefs.getString("flutter.cached_city_en", "") ?: ""
        
        val cacheExists = !prayerTimesJson.isNullOrEmpty()
        Log.d(TAG, "SERVICE TICK: cacheExists=$cacheExists, cachedDate=$cachedDate")
        
        if (!cacheExists) {
            // No cache - show setup message
            return if (isArabic) {
                Pair("افتح التطبيق لإكمال الإعداد", "لم يتم تحديد الموقع وأوقات الصلاة")
            } else {
                Pair("Open the app to finish setup", "Location & prayer times not cached yet")
            }
        }
        
        // Parse prayer times
        val timings = parsePrayerTimes(prayerTimesJson!!)
        if (timings == null) {
            return if (isArabic) {
                Pair("خطأ في البيانات", "أعد تحديث أوقات الصلاة")
            } else {
                Pair("Data error", "Please refresh prayer times")
            }
        }
        
        // Build title: city + hijri date
        val city = if (isArabic) cityAr.ifEmpty { cityEn } else cityEn.ifEmpty { cityAr }
        val hijriDate = getHijriDateString(isArabic)
        val title = if (city.isNotEmpty()) "$city • $hijriDate" else hijriDate
        
        // Compute prayer status
        val now = Calendar.getInstance()
        val prayerStatus = computePrayerStatus(timings, now, isArabic)
        
        Log.d(TAG, "TICK: nextPrayer=${prayerStatus.prayerName}, remaining=${prayerStatus.countdown}, grace=${prayerStatus.isGrace}")
        
        // Build body: prayer name + time + countdown
        val body = "${prayerStatus.prayerName} ${prayerStatus.prayerTime} | ${prayerStatus.countdown}"
        
        return Pair(title, body)
    }
    
    /**
     * Parse prayer times JSON to get timings map
     */
    private fun parsePrayerTimes(json: String): Map<String, String>? {
        return try {
            val root = JSONObject(json)
            val data = root.optJSONObject("data") ?: root
            val timings = data.optJSONObject("timings") ?: return null
            
            mapOf(
                "Fajr" to (timings.optString("Fajr", "05:00") ?: "05:00"),
                "Dhuhr" to (timings.optString("Dhuhr", "12:00") ?: "12:00"),
                "Asr" to (timings.optString("Asr", "15:30") ?: "15:30"),
                "Maghrib" to (timings.optString("Maghrib", "18:00") ?: "18:00"),
                "Isha" to (timings.optString("Isha", "19:30") ?: "19:30")
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing prayer times: $e")
            null
        }
    }
    
    /**
     * Get Hijri date string for TODAY by reading Flutter's per-date JSON cache.
     *
     * Flutter's HijriDateService pre-fetches the next 7 days and stores each as:
     *   key:   "flutter.hijri_date_YYYY-MM-DD"
     *   value: JSON with fields day, month, year, monthNameAr, monthNameEn
     *
     * Reading today's entry directly means we always show the correct date even
     * when the Flutter engine hasn't run for days, because the pre-fetch put the
     * data there in advance.
     *
     * Fallback chain:
     *   1. Today's per-date JSON cache entry   ← NEW primary source
     *   2. Recent pre-formatted display string  (cached_hijri_display_ar/en)
     *   3. Crude Gregorian → Hijri approximation
     */
    private fun getHijriDateString(isArabic: Boolean): String {
        // --- 1. Primary: read today's per-date JSON cache entry ---
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val todayKey = sdf.format(Date())
        val perDateJson = prefs.getString("flutter.hijri_date_$todayKey", null)

        if (!perDateJson.isNullOrBlank()) {
            try {
                val json = org.json.JSONObject(perDateJson)
                val day   = json.optInt("day", 0)
                val month = json.optInt("month", 0)
                val year  = json.optInt("year", 0)
                if (day > 0 && month > 0 && year > 0) {
                    val monthName = if (isArabic) {
                        json.optString("monthNameAr", hijriMonthsAr.getOrElse(month - 1) { "" })
                    } else {
                        json.optString("monthNameEn", hijriMonthsEn.getOrElse(month - 1) { "" })
                    }
                    Log.d(TAG, "getHijriDateString: per-date cache hit for $todayKey → $day $monthName $year")
                    return if (isArabic) "\u200F$day $monthName $year\u200F"
                           else          "$day $monthName $year AH"
                }
            } catch (e: Exception) {
                Log.w(TAG, "getHijriDateString: failed to parse per-date JSON for $todayKey: ${e.message}")
            }
        } else {
            Log.d(TAG, "getHijriDateString: no per-date cache for $todayKey, trying display strings")
        }

        // --- 2. Fallback: pre-formatted display strings (written by Flutter for today) ---
        val cachedTimestamp = prefs.getLong("flutter.cached_hijri_updated_at", 0L)
        val now = System.currentTimeMillis()
        val cacheAgeMs = now - cachedTimestamp
        val maxCacheAgeMs = 36 * 60 * 60 * 1000L // 36 hours

        if (cacheAgeMs < maxCacheAgeMs && cachedTimestamp > 0) {
            val displayKey = if (isArabic) "flutter.cached_hijri_display_ar" else "flutter.cached_hijri_display_en"
            val cachedDisplay = prefs.getString(displayKey, null)
            if (!cachedDisplay.isNullOrBlank()) {
                Log.d(TAG, "getHijriDateString: display string fallback (age: ${cacheAgeMs / 1000}s)")
                return cachedDisplay
            }
        } else if (cachedTimestamp > 0) {
            Log.d(TAG, "getHijriDateString: display string is stale (age: ${cacheAgeMs / 1000}s)")
        }

        // --- 3. Last resort: crude Gregorian → Hijri approximation ---
        Log.w(TAG, "getHijriDateString: no cache at all, using approximation")
        val calendar = Calendar.getInstance()
        val approxYear = ((calendar.get(Calendar.YEAR) - 622) * 33 / 32)
        val approxDay  = calendar.get(Calendar.DAY_OF_MONTH)
        val monthName  = if (isArabic) hijriMonthsAr[6] else hijriMonthsEn[6]
        return if (isArabic) "\u200F$approxDay $monthName $approxYear\u200F"
               else          "$approxDay $monthName $approxYear AH"
    }
    
    /**
     * Compute prayer status: name, time, countdown, color indicator
     */
    private fun computePrayerStatus(timings: Map<String, String>, now: Calendar, isArabic: Boolean): PrayerStatus {
        val prayerKeys = arrayOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
        val prayerNames = if (isArabic) prayerNamesAr else prayerNamesEn
        
        val today = Calendar.getInstance()
        val prayerCalendars = prayerKeys.mapIndexed { index, key ->
            val timeStr = timings[key] ?: "12:00"
            val parts = timeStr.split(":")
            val hour = parts.getOrElse(0) { "12" }.trim().split(" ")[0].toIntOrNull() ?: 12
            val minute = parts.getOrElse(1) { "00" }.trim().split(" ")[0].toIntOrNull() ?: 0
            
            Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            } to prayerNames[index]
        }
        
        // Find last passed prayer and next upcoming prayer
        var lastPrayerIndex: Int? = null
        var lastPrayerTime: Calendar? = null
        var nextPrayerIndex: Int? = null
        var nextPrayerTime: Calendar? = null
        
        for (i in prayerCalendars.indices) {
            val (prayerCal, _) = prayerCalendars[i]
            if (now.before(prayerCal)) {
                nextPrayerIndex = i
                nextPrayerTime = prayerCal
                break
            } else {
                lastPrayerIndex = i
                lastPrayerTime = prayerCal
            }
        }
        
        // Check for grace window (within 30 min after last prayer)
        if (lastPrayerTime != null && lastPrayerIndex != null) {
            val elapsedMinutes = (now.timeInMillis - lastPrayerTime.timeInMillis) / 60000
            if (elapsedMinutes < GRACE_WINDOW_MINUTES) {
                // Grace window - show elapsed time with + sign
                val elapsed = now.timeInMillis - lastPrayerTime.timeInMillis
                val countdownStr = formatDuration(elapsed, isPositive = true)
                val prayerName = prayerNames[lastPrayerIndex]
                val prayerTimeStr = formatPrayerTime(lastPrayerTime, isArabic)
                
                return PrayerStatus(
                    prayerName = prayerName,
                    prayerTime = prayerTimeStr,
                    countdown = countdownStr,
                    isGrace = true,
                    isWarning = false
                )
            }
        }
        
        // If all prayers passed, next is tomorrow's Fajr
        if (nextPrayerIndex == null) {
            nextPrayerIndex = 0
            nextPrayerTime = prayerCalendars[0].first.apply {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        
        // Normal countdown to next prayer
        val remaining = nextPrayerTime!!.timeInMillis - now.timeInMillis
        val remainingMinutes = remaining / 60000
        val isWarning = remainingMinutes < WARNING_MINUTES
        val countdownStr = formatDuration(remaining, isPositive = false)
        val prayerName = prayerNames[nextPrayerIndex!!]
        val prayerTimeStr = formatPrayerTime(nextPrayerTime, isArabic)
        
        return PrayerStatus(
            prayerName = prayerName,
            prayerTime = prayerTimeStr,
            countdown = countdownStr,
            isGrace = false,
            isWarning = isWarning
        )
    }
    
    /**
     * Format duration with sign and hide hours when 0
     */
    private fun formatDuration(millis: Long, isPositive: Boolean): String {
        val totalSeconds = kotlin.math.abs(millis / 1000)
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        
        val sign = if (isPositive) "+" else "-"
        
        return if (hours > 0) {
            String.format("%s %02d:%02d:%02d", sign, hours, minutes, seconds)
        } else {
            String.format("%s %02d:%02d", sign, minutes, seconds)
        }
    }
    
    /**
     * Format prayer time for display
     */
    private fun formatPrayerTime(cal: Calendar, isArabic: Boolean): String {
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val minute = cal.get(Calendar.MINUTE)
        val hour12 = if (hour > 12) hour - 12 else if (hour == 0) 12 else hour
        val period = if (isArabic) {
            if (hour >= 12) "م" else "ص"
        } else {
            if (hour >= 12) "PM" else "AM"
        }
        
        return String.format("%d:%02d %s", hour12, minute, period)
    }
    
    private fun buildNotification(title: String, body: String): Notification {
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val dismissIntent = Intent(this, NotificationDismissReceiver::class.java).apply {
            action = "com.example.adhan_app.NOTIFICATION_DISMISSED"
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
            .setSmallIcon(R.drawable.ic_stat_adhan)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openAppPendingIntent)
            .setDeleteIntent(dismissPendingIntent)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }
    
    /**
     * Data class for prayer status
     */
    data class PrayerStatus(
        val prayerName: String,
        val prayerTime: String,
        val countdown: String,
        val isGrace: Boolean,
        val isWarning: Boolean
    )
}
