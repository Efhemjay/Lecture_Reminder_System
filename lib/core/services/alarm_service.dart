import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:lecture_reminder_system/model/alarm_model.dart';
import 'package:lecture_reminder_system/main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:audioplayers/audioplayers.dart' as audio_players;

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();
  final audio_players.AudioPlayer _mediaPlayer = audio_players.AudioPlayer();
  Timer? _vibrationTimer;
  Timer? _autoStopTimer;
  Alarm? _currentAlarm;
  bool _isPlaying = false;
  bool _wasMediaPlaying = false;

  // Stream controllers for UI updates
  final StreamController<Alarm?> _alarmStateController =
      StreamController<Alarm?>.broadcast();
  Stream<Alarm?> get alarmStateStream => _alarmStateController.stream;

  // Available ringtones using system sounds
  static const Map<String, String> availableRingtones = {
    'alarm': 'Alarm Sound',
    'notification': 'Notification Sound',
    'ringtone': 'Ringtone Sound',
    'system': 'System Sound',
  };

  void dispose() {
    _audioPlayer.dispose();
    _vibrationTimer?.cancel();
    _autoStopTimer?.cancel();
    _alarmStateController.close();
  }

  Future<void> startAlarm(Alarm alarm) async {
    if (_isPlaying) {
      await stopAlarm();
    }

    _currentAlarm = alarm.copyWith(state: AlarmState.ringing);
    _alarmStateController.add(_currentAlarm);
    _isPlaying = true;

    try {
      // Pause any currently playing media
      await _pauseCurrentMedia();

      // Play ringtone
      await _playRingtone(alarm.settings.ringtonePath);

      // Start vibration if enabled
      if (alarm.settings.vibrate) {
        _startVibration();
      }

      // Auto-stop timer if enabled
      if (alarm.settings.autoStop) {
        _autoStopTimer = Timer(const Duration(minutes: 5), () {
          stopAlarm();
        });
      }

      debugPrint('🔔 Alarm started for: ${alarm.title}');
    } catch (e) {
      debugPrint('❌ Error starting alarm: $e');
      await stopAlarm();
    }
  }

  Future<void> _playRingtone(String ringtonePath) async {
    try {
      switch (ringtonePath) {
        case 'alarm':
          await _ringtonePlayer.playAlarm(looping: true, volume: 1.0);
          break;
        case 'notification':
          await _ringtonePlayer.playNotification(looping: true, volume: 1.0);
          break;
        case 'ringtone':
          await _ringtonePlayer.playRingtone(looping: true, volume: 1.0);
          break;
        case 'system':
          // Use system sound (similar to notification but different)
          await _ringtonePlayer.playNotification(looping: true, volume: 1.0);
          break;
        default:
          // Default to alarm sound
          await _ringtonePlayer.playAlarm(looping: true, volume: 1.0);
      }
    } catch (e) {
      debugPrint('❌ Error playing ringtone: $e');
      // Fallback to system alarm
      await _ringtonePlayer.playAlarm(looping: true, volume: 1.0);
    }
  }

  void _startVibration() {
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(duration: 1000);
      }
    });
  }

  Future<void> stopAlarm() async {
    if (!_isPlaying) return;

    _isPlaying = false;
    _vibrationTimer?.cancel();
    _autoStopTimer?.cancel();

    try {
      await _audioPlayer.stop();
      await _ringtonePlayer.stop();
      if (await Vibration.hasVibrator() == true) {
        Vibration.cancel();
      }

      // Resume media if it was playing before alarm
      await _resumeMedia();
    } catch (e) {
      debugPrint('❌ Error stopping alarm: $e');
    }

    if (_currentAlarm != null) {
      // Cancel any pending snooze notifications
      await flutterLocalNotificationsPlugin.cancel(
        _currentAlarm!.hashCode + 1000,
      );

      _currentAlarm = _currentAlarm!.copyWith(
        state: AlarmState.stopped,
        snoozeCount: 0,
        lastSnoozeTime: null,
        nextAlarmTime: null,
      );
      _alarmStateController.add(_currentAlarm);
    }

    debugPrint('🔇 Alarm stopped');
  }

  Future<void> snoozeAlarm() async {
    if (_currentAlarm == null || !_currentAlarm!.canSnooze) return;

    await stopAlarm();

    final now = DateTime.now();
    final snoozeTime = now.add(
      Duration(minutes: _currentAlarm!.settings.snoozeInterval.minutes),
    );

    _currentAlarm = _currentAlarm!.copyWith(
      state: AlarmState.snoozed,
      snoozeCount: _currentAlarm!.snoozeCount + 1,
      lastSnoozeTime: now,
      nextAlarmTime: snoozeTime,
    );

    _alarmStateController.add(_currentAlarm);

    // Schedule snooze notification
    await _scheduleSnoozeNotification(_currentAlarm!, snoozeTime);

    debugPrint(
      '⏰ Alarm snoozed for ${_currentAlarm!.settings.snoozeInterval.minutes} minutes',
    );
  }

  Future<void> _scheduleSnoozeNotification(
    Alarm alarm,
    DateTime snoozeTime,
  ) async {
    final tzSnoozeTime = tz.TZDateTime.from(snoozeTime, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      alarm.hashCode + 1000, // Different ID for snooze
      '${alarm.title} - Snoozed',
      'Lecture reminder (Snoozed) at ${alarm.location}',
      tzSnoozeTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarm Notifications',
          channelDescription: 'Lecture alarm notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'alarm'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Alarm? get currentAlarm => _currentAlarm;
  bool get isPlaying => _isPlaying;

  // Method to get available ringtones
  static Map<String, String> getAvailableRingtones() => availableRingtones;

  // Method to preview ringtone
  Future<void> previewRingtone(String ringtonePath) async {
    try {
      await _playRingtone(ringtonePath);
      await Future.delayed(const Duration(seconds: 3));
      await stopAlarm();
    } catch (e) {
      debugPrint('❌ Error previewing ringtone: $e');
    }
  }

  /// Pause any currently playing media
  Future<void> _pauseCurrentMedia() async {
    try {
      // Check if any media is currently playing
      final playingState = await _mediaPlayer.state;
      if (playingState == audio_players.PlayerState.playing) {
        _wasMediaPlaying = true;
        await _mediaPlayer.pause();
        debugPrint('⏸️ Media paused due to alarm');
      } else {
        _wasMediaPlaying = false;
      }
    } catch (e) {
      debugPrint('❌ Error pausing media: $e');
      _wasMediaPlaying = false;
    }
  }

  /// Resume media if it was playing before alarm
  Future<void> _resumeMedia() async {
    try {
      if (_wasMediaPlaying) {
        await _mediaPlayer.resume();
        _wasMediaPlaying = false;
        debugPrint('▶️ Media resumed after alarm');
      }
    } catch (e) {
      debugPrint('❌ Error resuming media: $e');
      _wasMediaPlaying = false;
    }
  }

  /// Cancel snooze notification for a specific alarm
  Future<void> cancelSnoozeNotification(Alarm alarm) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(alarm.hashCode + 1000);
      debugPrint('🔕 Snooze notification canceled for: ${alarm.title}');
    } catch (e) {
      debugPrint('❌ Error canceling snooze notification: $e');
    }
  }
}
