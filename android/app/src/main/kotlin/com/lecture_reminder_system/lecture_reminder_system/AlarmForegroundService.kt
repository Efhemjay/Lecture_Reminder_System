package com.lecture_reminder_system.lecture_reminder_system

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import android.app.ActivityManager
import android.content.pm.PackageManager
import android.os.PowerManager
import android.view.WindowManager.LayoutParams
import android.media.MediaPlayer
import android.media.AudioManager
import android.os.Vibrator
import android.os.VibrationEffect
import android.os.Handler
import android.os.Looper
import android.content.IntentFilter
import android.media.AudioManager.OnAudioFocusChangeListener
import com.lecture_reminder_system.lecture_reminder_system.R

class AlarmForegroundService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: View
    private lateinit var powerManager: PowerManager
    private lateinit var wakeLock: PowerManager.WakeLock
    private lateinit var mediaPlayer: MediaPlayer
    private lateinit var vibrator: Vibrator
    private lateinit var audioManager: AudioManager
    private var vibrationHandler: Handler? = null
    private var vibrationRunnable: Runnable? = null
    private var isAlarmActive = false
    private var wasMediaPlaying = false
    private var audioFocusChangeListener: OnAudioFocusChangeListener? = null

    companion object {
        const val CHANNEL_ID = "AlarmOverlayChannel"
        const val NOTIFICATION_ID = 1001
        const val EXTRA_ALARM_TITLE = "alarm_title"
        const val EXTRA_ALARM_TIME = "alarm_time"
        const val EXTRA_ALARM_LOCATION = "alarm_location"
        const val EXTRA_ALARM_DAY = "alarm_day"
        const val EXTRA_ALARM_ID = "alarm_id"
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "AlarmWakeLock"
        )
        
        // Initialize MediaPlayer for alarm sound
        mediaPlayer = MediaPlayer()
        mediaPlayer.isLooping = true
        mediaPlayer.setAudioStreamType(AudioManager.STREAM_ALARM)
        
        // Set up audio focus change listener
        audioFocusChangeListener = OnAudioFocusChangeListener { focusChange ->
            when (focusChange) {
                AudioManager.AUDIOFOCUS_LOSS -> {
                    // Media was playing and now stopped
                    wasMediaPlaying = true
                }
                AudioManager.AUDIOFOCUS_GAIN -> {
                    // Media can resume
                    if (wasMediaPlaying && !isAlarmActive) {
                        // Resume media if alarm is not active
                        wasMediaPlaying = false
                    }
                }
            }
        }
        
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val alarmTitle = intent?.getStringExtra(EXTRA_ALARM_TITLE) ?: "Lecture Reminder"
        val alarmTime = intent?.getStringExtra(EXTRA_ALARM_TIME) ?: ""
        val alarmLocation = intent?.getStringExtra(EXTRA_ALARM_LOCATION) ?: ""
        val alarmDay = intent?.getStringExtra(EXTRA_ALARM_DAY) ?: ""
        val alarmId = intent?.getIntExtra(EXTRA_ALARM_ID, 0) ?: 0

        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification(alarmTitle))

        // Acquire wake lock
        if (!wakeLock.isHeld) {
            wakeLock.acquire(10 * 60 * 1000L) // 10 minutes
        }

        // Start alarm sound and vibration
        startAlarm()

        // Show overlay
        showAlarmOverlay(alarmTitle, alarmTime, alarmLocation, alarmDay, alarmId)

        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Overlay",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows alarm overlay over other apps"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(alarmTitle: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Alarm Active")
            .setContentText("$alarmTitle is ringing")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .build()
    }

    private fun startAlarm() {
        try {
            isAlarmActive = true
            
            // Request audio focus to pause other media
            val result = audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
            
            if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                // Media was paused due to audio focus request
                wasMediaPlaying = true
            }
            
            // Set alarm volume to maximum
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)
            
            // Start alarm sound (using system alarm sound)
            mediaPlayer.setDataSource(this, android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI)
            mediaPlayer.prepare()
            mediaPlayer.start()
            
            // Start vibration
            startVibration()
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startVibration() {
        vibrationHandler = Handler(Looper.getMainLooper())
        vibrationRunnable = object : Runnable {
            override fun run() {
                if (isAlarmActive && vibrator.hasVibrator()) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val vibrationEffect = VibrationEffect.createOneShot(1000, VibrationEffect.DEFAULT_AMPLITUDE)
                        vibrator.vibrate(vibrationEffect)
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(1000)
                    }
                }
                vibrationHandler?.postDelayed(this, 2000) // Vibrate every 2 seconds
            }
        }
        vibrationHandler?.post(vibrationRunnable!!)
    }

    private fun stopAlarmSound() {
        try {
            isAlarmActive = false
            
            // Stop sound
            if (mediaPlayer.isPlaying) {
                mediaPlayer.stop()
                mediaPlayer.reset()
            }
            
            // Stop vibration
            vibrationHandler?.removeCallbacksAndMessages(null)
            if (vibrator.hasVibrator()) {
                vibrator.cancel()
            }
            
            // Abandon audio focus to allow media to resume
            audioManager.abandonAudioFocus(audioFocusChangeListener)
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun showAlarmOverlay(title: String, time: String, location: String, day: String, alarmId: Int) {
        try {
            // Create overlay view
            overlayView = LayoutInflater.from(this).inflate(R.layout.alarm_overlay, null)

            // Set alarm details
            overlayView.findViewById<TextView>(R.id.alarmTitle).text = title
            overlayView.findViewById<TextView>(R.id.alarmTime).text = "Time: $time"
            overlayView.findViewById<TextView>(R.id.alarmLocation).text = "Location: $location"
            overlayView.findViewById<TextView>(R.id.alarmDay).text = "Day: $day"

            // Set up buttons
            overlayView.findViewById<Button>(R.id.stopButton).setOnClickListener {
                stopAlarm(alarmId)
            }

            overlayView.findViewById<Button>(R.id.snoozeButton).setOnClickListener {
                snoozeAlarm(alarmId)
            }

            // Window parameters for overlay
            val params = WindowManager.LayoutParams().apply {
                type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                flags = LayoutParams.FLAG_NOT_FOCUSABLE or
                        LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                        LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        LayoutParams.FLAG_DISMISS_KEYGUARD or
                        LayoutParams.FLAG_TURN_SCREEN_ON or
                        LayoutParams.FLAG_KEEP_SCREEN_ON
                format = PixelFormat.TRANSLUCENT
                gravity = Gravity.CENTER
                width = WindowManager.LayoutParams.MATCH_PARENT
                height = WindowManager.LayoutParams.WRAP_CONTENT
            }

            // Add overlay to window
            windowManager.addView(overlayView, params)

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAlarm(alarmId: Int = 0) {
        try {
            // Stop the alarm sound and vibration
            stopAlarmSound()
            
            // Remove overlay
            if (::overlayView.isInitialized) {
                windowManager.removeView(overlayView)
            }
            
            // Send broadcast to notify Flutter about alarm state change
            if (alarmId != 0) {
                val intent = Intent("ALARM_STATE_CHANGED")
                intent.putExtra("alarm_id", alarmId)
                intent.putExtra("state", "stopped")
                sendBroadcast(intent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        if (wakeLock.isHeld) {
            wakeLock.release()
        }
        
        stopForeground(true)
        stopSelf()
    }

    private fun snoozeAlarm(alarmId: Int = 0) {
        try {
            // Stop current alarm sound and vibration
            stopAlarmSound()
            
            // Hide overlay temporarily
            if (::overlayView.isInitialized) {
                windowManager.removeView(overlayView)
            }
            
            // Send broadcast to notify Flutter about alarm state change
            if (alarmId != 0) {
                val intent = Intent("ALARM_STATE_CHANGED")
                intent.putExtra("alarm_id", alarmId)
                intent.putExtra("state", "snoozed")
                sendBroadcast(intent)
            }
            
            // Schedule to show again in 5 minutes
            Handler(Looper.getMainLooper()).postDelayed({
                if (wakeLock.isHeld) {
                    // Restart alarm
                    startAlarm()
                    showAlarmOverlay(
                        "Lecture Reminder",
                        "Snoozed",
                        "Location",
                        "Today",
                        alarmId
                    )
                }
            }, 5 * 60 * 1000) // 5 minutes
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        try {
            // Stop alarm
            stopAlarmSound()
            
            // Remove overlay
            if (::overlayView.isInitialized) {
                windowManager.removeView(overlayView)
            }
            
            // Release MediaPlayer
            if (::mediaPlayer.isInitialized) {
                mediaPlayer.release()
            }
            
            // Clean up audio focus listener
            audioFocusChangeListener?.let { listener ->
                audioManager.abandonAudioFocus(listener)
            }
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        if (wakeLock.isHeld) {
            wakeLock.release()
        }
    }
}
