import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_reminder_system/model/alarm_model.dart';

void main() {
  group('Alarm Model Tests', () {
    test('should create alarm with default settings', () {
      final alarm = Alarm(
        title: 'Test Lecture',
        day: 'Monday',
        time: '9:00 AM',
        location: 'Room 101',
      );

      expect(alarm.title, 'Test Lecture');
      expect(alarm.day, 'Monday');
      expect(alarm.time, '9:00 AM');
      expect(alarm.location, 'Room 101');
      expect(alarm.state, AlarmState.idle);
      expect(alarm.snoozeCount, 0);
      expect(alarm.settings.ringtonePath, 'alarm');
      expect(alarm.settings.vibrate, true);
      expect(alarm.settings.volume, 100);
      expect(alarm.settings.snoozeInterval, SnoozeInterval.fiveMinutes);
      expect(alarm.settings.maxSnoozeCount, 3);
      expect(alarm.settings.autoStop, false);
    });

    test('should create alarm with custom settings', () {
      final customSettings = AlarmSettings(
        ringtonePath: 'gentle',
        vibrate: false,
        volume: 75,
        snoozeInterval: SnoozeInterval.tenMinutes,
        maxSnoozeCount: 5,
        autoStop: true,
      );

      final alarm = Alarm(
        title: 'Test Lecture',
        day: 'Tuesday',
        time: '10:30 AM',
        location: 'Room 202',
        settings: customSettings,
      );

      expect(alarm.settings.ringtonePath, 'gentle');
      expect(alarm.settings.vibrate, false);
      expect(alarm.settings.volume, 75);
      expect(alarm.settings.snoozeInterval, SnoozeInterval.tenMinutes);
      expect(alarm.settings.maxSnoozeCount, 5);
      expect(alarm.settings.autoStop, true);
    });

    test('should check snooze availability', () {
      final alarm = Alarm(
        title: 'Test Lecture',
        day: 'Wednesday',
        time: '2:00 PM',
        location: 'Room 303',
        settings: const AlarmSettings(maxSnoozeCount: 2),
        snoozeCount: 1,
      );

      expect(alarm.canSnooze, true);

      final maxSnoozedAlarm = alarm.copyWith(snoozeCount: 2);
      expect(maxSnoozedAlarm.canSnooze, false);
    });

    test('should serialize and deserialize alarm', () {
      final originalAlarm = Alarm(
        title: 'Test Lecture',
        day: 'Thursday',
        time: '3:30 PM',
        location: 'Room 404',
        settings: const AlarmSettings(
          ringtonePath: 'energetic',
          vibrate: true,
          volume: 80,
          snoozeInterval: SnoozeInterval.fifteenMinutes,
          maxSnoozeCount: 4,
          autoStop: false,
        ),
        state: AlarmState.ringing,
        snoozeCount: 1,
      );

      final json = originalAlarm.toJson();
      final deserializedAlarm = Alarm.fromJson(json);

      expect(deserializedAlarm.title, originalAlarm.title);
      expect(deserializedAlarm.day, originalAlarm.day);
      expect(deserializedAlarm.time, originalAlarm.time);
      expect(deserializedAlarm.location, originalAlarm.location);
      expect(deserializedAlarm.state, originalAlarm.state);
      expect(deserializedAlarm.snoozeCount, originalAlarm.snoozeCount);
      expect(
        deserializedAlarm.settings.ringtonePath,
        originalAlarm.settings.ringtonePath,
      );
      expect(
        deserializedAlarm.settings.vibrate,
        originalAlarm.settings.vibrate,
      );
      expect(deserializedAlarm.settings.volume, originalAlarm.settings.volume);
      expect(
        deserializedAlarm.settings.snoozeInterval,
        originalAlarm.settings.snoozeInterval,
      );
      expect(
        deserializedAlarm.settings.maxSnoozeCount,
        originalAlarm.settings.maxSnoozeCount,
      );
      expect(
        deserializedAlarm.settings.autoStop,
        originalAlarm.settings.autoStop,
      );
    });

    test('should copy alarm with modifications', () {
      final originalAlarm = Alarm(
        title: 'Original Lecture',
        day: 'Friday',
        time: '4:00 PM',
        location: 'Room 505',
      );

      final modifiedAlarm = originalAlarm.copyWith(
        title: 'Modified Lecture',
        state: AlarmState.ringing,
        snoozeCount: 2,
      );

      expect(modifiedAlarm.title, 'Modified Lecture');
      expect(modifiedAlarm.day, 'Friday'); // Unchanged
      expect(modifiedAlarm.time, '4:00 PM'); // Unchanged
      expect(modifiedAlarm.location, 'Room 505'); // Unchanged
      expect(modifiedAlarm.state, AlarmState.ringing);
      expect(modifiedAlarm.snoozeCount, 2);
    });
  });

  group('SnoozeInterval Tests', () {
    test('should have correct minute values', () {
      expect(SnoozeInterval.fiveMinutes.minutes, 5);
      expect(SnoozeInterval.tenMinutes.minutes, 10);
      expect(SnoozeInterval.fifteenMinutes.minutes, 15);
      expect(SnoozeInterval.thirtyMinutes.minutes, 30);
    });
  });

  group('AlarmState Tests', () {
    test('should check alarm states', () {
      final idleAlarm = Alarm(
        title: 'Test',
        day: 'Monday',
        time: '9:00 AM',
        location: 'Room 1',
        state: AlarmState.idle,
      );

      final ringingAlarm = idleAlarm.copyWith(state: AlarmState.ringing);
      final snoozedAlarm = idleAlarm.copyWith(state: AlarmState.snoozed);
      final stoppedAlarm = idleAlarm.copyWith(state: AlarmState.stopped);

      expect(idleAlarm.isRinging, false);
      expect(idleAlarm.isSnoozed, false);

      expect(ringingAlarm.isRinging, true);
      expect(ringingAlarm.isSnoozed, false);

      expect(snoozedAlarm.isRinging, false);
      expect(snoozedAlarm.isSnoozed, true);

      expect(stoppedAlarm.isRinging, false);
      expect(stoppedAlarm.isSnoozed, false);
    });
  });
}
