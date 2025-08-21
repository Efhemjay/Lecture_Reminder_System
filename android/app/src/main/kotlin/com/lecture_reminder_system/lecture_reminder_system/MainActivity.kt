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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                    val alarmTitle = call.argument<String>("alarm_title") ?: "Lecture Reminder"
                    val alarmTime = call.argument<String>("alarm_time") ?: ""
                    val alarmLocation = call.argument<String>("alarm_location") ?: ""
                    val alarmDay = call.argument<String>("alarm_day") ?: ""
                    val triggerTime = call.argument<Long>("trigger_time") ?: 0L
                    val alarmId = call.argument<Int>("alarm_id") ?: 0
                    
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
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(this, AlarmForegroundService::class.java).apply {
            putExtra(AlarmForegroundService.EXTRA_ALARM_TITLE, alarmTitle)
            putExtra(AlarmForegroundService.EXTRA_ALARM_TIME, alarmTime)
            putExtra(AlarmForegroundService.EXTRA_ALARM_LOCATION, alarmLocation)
            putExtra(AlarmForegroundService.EXTRA_ALARM_DAY, alarmDay)
            action = "START_ALARM_OVERLAY"
        }
        
        val pendingIntent = PendingIntent.getService(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(triggerTime, pendingIntent),
                    pendingIntent
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }
            println("🔔 Native alarm scheduled for ID: $alarmId at time: $triggerTime")
        } catch (e: Exception) {
            println("❌ Failed to schedule native alarm: ${e.message}")
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
}
