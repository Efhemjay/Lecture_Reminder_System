package com.lecture_reminder_system.lecture_reminder_system

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.content.Context
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.IntentFilter

class MainActivity: FlutterActivity() {
    private val CHANNEL = "alarm_overlay_channel"
    private var methodChannel: MethodChannel? = null
    private val alarmStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "ALARM_STATE_CHANGED") {
                val alarmId = intent.getIntExtra("alarm_id", 0)
                val state = intent.getStringExtra("state")
                
                // Forward to Flutter via MethodChannel
                methodChannel?.invokeMethod("onAlarmStateChanged", mapOf(
                    "alarm_id" to alarmId,
                    "state" to state
                ))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up broadcast receiver for alarm state changes
        val filter = IntentFilter("ALARM_STATE_CHANGED")
        registerReceiver(alarmStateReceiver, filter)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarmOverlay" -> {
                    val alarmTitle = call.argument<String>("alarm_title") ?: "Lecture Reminder"
                    val alarmTime = call.argument<String>("alarm_time") ?: ""
                    val alarmLocation = call.argument<String>("alarm_location") ?: ""
                    val alarmDay = call.argument<String>("alarm_day") ?: ""
                    val alarmId = call.argument<Int>("alarm_id") ?: 0
                    
                    val intent = Intent(this, AlarmForegroundService::class.java).apply {
                        putExtra(AlarmForegroundService.EXTRA_ALARM_TITLE, alarmTitle)
                        putExtra(AlarmForegroundService.EXTRA_ALARM_TIME, alarmTime)
                        putExtra(AlarmForegroundService.EXTRA_ALARM_LOCATION, alarmLocation)
                        putExtra(AlarmForegroundService.EXTRA_ALARM_DAY, alarmDay)
                        putExtra(AlarmForegroundService.EXTRA_ALARM_ID, alarmId)
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    
                    result.success(true)
                }
                
                "stopAlarmOverlay" -> {
                    val intent = Intent(this, AlarmForegroundService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                
                "snoozeAlarmOverlay" -> {
                    // The snooze functionality is handled in the service itself
                    result.success(true)
                }
                
                "hasOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (!Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivityForResult(intent, 1234)
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                
                "scheduleNativeAlarm" -> {
                    println("🔔 Flutter called scheduleNativeAlarm")
                    val alarmTitle = call.argument<String>("alarm_title") ?: "Lecture Reminder"
                    val alarmTime = call.argument<String>("alarm_time") ?: ""
                    val alarmLocation = call.argument<String>("alarm_location") ?: ""
                    val alarmDay = call.argument<String>("alarm_day") ?: ""
                    val triggerTime = call.argument<Long>("trigger_time") ?: 0L
                    val alarmId = call.argument<Int>("alarm_id") ?: 0
                    
                    println("🔔 Native alarm scheduling - Title: $alarmTitle, Time: $alarmTime, Trigger: $triggerTime, ID: $alarmId")
                    
                    // Always schedule the native alarm - it will check app state at execution time
                    scheduleNativeAlarm(alarmTitle, alarmTime, alarmLocation, alarmDay, triggerTime, alarmId)
                    result.success(true)
                }
                
                "cancelNativeAlarm" -> {
                    val alarmId = call.argument<Int>("alarm_id") ?: 0
                    cancelNativeAlarm(alarmId)
                    result.success(true)
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == 1234) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    // Permission granted
                } else {
                    // Permission denied
                }
            }
        }
    }
    
    private fun scheduleNativeAlarm(alarmTitle: String, alarmTime: String, alarmLocation: String, alarmDay: String, triggerTime: Long, alarmId: Int) {
        println("🔔 scheduleNativeAlarm called with ID: $alarmId, triggerTime: $triggerTime")
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(this, AlarmForegroundService::class.java).apply {
            putExtra(AlarmForegroundService.EXTRA_ALARM_TITLE, alarmTitle)
            putExtra(AlarmForegroundService.EXTRA_ALARM_TIME, alarmTime)
            putExtra(AlarmForegroundService.EXTRA_ALARM_LOCATION, alarmLocation)
            putExtra(AlarmForegroundService.EXTRA_ALARM_DAY, alarmDay)
            putExtra(AlarmForegroundService.EXTRA_ALARM_ID, alarmId)
            action = "START_ALARM_OVERLAY"
        }
        
        println("🔔 Created intent with action: ${intent.action}")
        
        val pendingIntent = PendingIntent.getService(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        println("🔔 Created PendingIntent for alarm ID: $alarmId")
        
        try {
            val now = System.currentTimeMillis()
            val delay = triggerTime - now
            
            println("🔔 Current time: $now, Trigger time: $triggerTime, Delay: $delay ms")
            
            // For very short delays (less than 1 second), trigger immediately
            if (delay < 1000) {
                println("🔔 Native alarm delay too short ($delay ms), triggering immediately for ID: $alarmId")
                startService(intent)
                return
            }
            
            // For short delays (less than 1 minute), use Handler instead of AlarmManager
            if (delay < 60000) {
                println("🔔 Native alarm delay short ($delay ms), using Handler for ID: $alarmId")
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    println("🔔 Handler executing for alarm ID: $alarmId")
                    startService(intent)
                }, delay)
                return
            }
            
            // For longer delays, use AlarmManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(triggerTime, pendingIntent),
                    pendingIntent
                )
                println("🔔 Used setAlarmClock for alarm ID: $alarmId")
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
                println("🔔 Used setExact for alarm ID: $alarmId")
            }
            println("🔔 Native alarm scheduled for ID: $alarmId at time: $triggerTime (delay: $delay ms)")
        } catch (e: Exception) {
            println("❌ Failed to schedule native alarm: ${e.message}")
            e.printStackTrace()
        }
    }
    
    private fun cancelNativeAlarm(alarmId: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(this, AlarmForegroundService::class.java)
        val pendingIntent = PendingIntent.getService(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            println("🔕 Native alarm canceled for ID: $alarmId")
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(alarmStateReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
    }
}
