import 'package:flutter/services.dart';
import 'package:lecture_reminder_system/model/alarm_model.dart';
import 'package:lecture_reminder_system/core/services/alarm_service.dart';
import 'package:lecture_reminder_system/core/services/alarm_state_service.dart';

class OverlayAlarmService {
  static const MethodChannel _channel = MethodChannel('alarm_overlay_channel');
  final AlarmService _alarmService = AlarmService();
  final AlarmStateService _alarmStateService = AlarmStateService();

  /// Start the alarm overlay service that appears over other apps
  Future<void> startAlarmOverlay(Alarm alarm) async {
    try {
      // Set alarm state to ringing
      _alarmStateService.setAlarmState(alarm.hashCode, AlarmState.ringing);

      // Start the Android foreground service with alarm details
      // The native service will handle sound, vibration, and overlay
      await _channel.invokeMethod('startAlarmOverlay', {
        'alarm_title': alarm.title,
        'alarm_time': alarm.time,
        'alarm_location': alarm.location,
        'alarm_day': alarm.day,
        'alarm_id': alarm.hashCode,
      });

      print('🔔 Alarm overlay started for: ${alarm.title}');
    } catch (e) {
      print('❌ Failed to start alarm overlay: $e');
      // Fallback to regular alarm service
      await _alarmService.startAlarm(alarm);
    }
  }

  /// Schedule a native alarm that will work even when app is closed
  Future<void> scheduleNativeAlarm(Alarm alarm, DateTime triggerTime) async {
    try {
      await _channel.invokeMethod('scheduleNativeAlarm', {
        'alarm_title': alarm.title,
        'alarm_time': alarm.time,
        'alarm_location': alarm.location,
        'alarm_day': alarm.day,
        'trigger_time': triggerTime.millisecondsSinceEpoch,
        'alarm_id': alarm.hashCode,
      });

      print('🔔 Native alarm scheduled for: ${alarm.title} at $triggerTime');
    } catch (e) {
      print('❌ Failed to schedule native alarm: $e');
    }
  }

  /// Cancel a scheduled native alarm
  Future<void> cancelNativeAlarm(Alarm alarm) async {
    try {
      await _channel.invokeMethod('cancelNativeAlarm', {
        'alarm_id': alarm.hashCode,
      });

      print('🔕 Native alarm canceled for: ${alarm.title}');
    } catch (e) {
      print('❌ Failed to cancel native alarm: $e');
    }
  }

  /// Stop the alarm overlay service
  Future<void> stopAlarmOverlay() async {
    try {
      await _channel.invokeMethod('stopAlarmOverlay');
      print('🔕 Alarm overlay stopped');
    } catch (e) {
      print('❌ Failed to stop alarm overlay: $e');
      await _alarmService.stopAlarm();
    }
  }

  /// Stop a specific alarm and update its state
  Future<void> stopSpecificAlarm(Alarm alarm) async {
    try {
      await _channel.invokeMethod('stopAlarmOverlay');
      // Set alarm state to stopped
      _alarmStateService.setAlarmState(alarm.hashCode, AlarmState.stopped);
      print('🔕 Alarm ${alarm.title} stopped');
    } catch (e) {
      print('❌ Failed to stop alarm: $e');
      await _alarmService.stopAlarm();
    }
  }

  /// Snooze the alarm overlay
  Future<void> snoozeAlarmOverlay() async {
    try {
      await _channel.invokeMethod('snoozeAlarmOverlay');
      print('⏰ Alarm overlay snoozed');
    } catch (e) {
      print('❌ Failed to snooze alarm overlay: $e');
      await _alarmService.snoozeAlarm();
    }
  }

  /// Snooze a specific alarm and update its state
  Future<void> snoozeSpecificAlarm(Alarm alarm) async {
    try {
      await _channel.invokeMethod('snoozeAlarmOverlay');
      // Set alarm state to snoozed
      _alarmStateService.setAlarmState(alarm.hashCode, AlarmState.snoozed);
      print('⏰ Alarm ${alarm.title} snoozed');
    } catch (e) {
      print('❌ Failed to snooze alarm: $e');
      await _alarmService.snoozeAlarm();
    }
  }

  /// Check if overlay permission is granted
  Future<bool> hasOverlayPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod(
        'hasOverlayPermission',
      );
      return hasPermission;
    } catch (e) {
      print('❌ Failed to check overlay permission: $e');
      return false;
    }
  }

  /// Request overlay permission
  Future<bool> requestOverlayPermission() async {
    try {
      final bool granted = await _channel.invokeMethod(
        'requestOverlayPermission',
      );
      return granted;
    } catch (e) {
      print('❌ Failed to request overlay permission: $e');
      return false;
    }
  }
}
