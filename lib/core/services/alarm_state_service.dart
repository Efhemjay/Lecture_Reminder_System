import 'package:lecture_reminder_system/model/alarm_model.dart';

class AlarmStateService {
  static final AlarmStateService _instance = AlarmStateService._internal();
  factory AlarmStateService() => _instance;
  AlarmStateService._internal();

  // Map to track alarm states by alarm ID
  final Map<int, AlarmState> _alarmStates = {};
  final Map<int, DateTime> _alarmStopTimes = {};

  /// Get the current state of an alarm
  AlarmState getAlarmState(int alarmId) {
    return _alarmStates[alarmId] ?? AlarmState.idle;
  }

  /// Set the state of an alarm
  void setAlarmState(int alarmId, AlarmState state) {
    _alarmStates[alarmId] = state;

    if (state == AlarmState.stopped) {
      _alarmStopTimes[alarmId] = DateTime.now();
    }

    print('🔔 Alarm $alarmId state changed to: $state');
  }

  /// Check if an alarm was recently stopped (within last 30 seconds)
  bool wasRecentlyStopped(int alarmId) {
    final stopTime = _alarmStopTimes[alarmId];
    if (stopTime == null) return false;

    final timeSinceStop = DateTime.now().difference(stopTime);
    return timeSinceStop.inSeconds < 30;
  }

  /// Check if an alarm was recently snoozed (within last 30 seconds)
  bool wasRecentlySnoozed(int alarmId) {
    final state = getAlarmState(alarmId);
    return state == AlarmState.snoozed;
  }

  /// Check if an alarm was recently handled (stopped or snoozed)
  bool wasRecentlyHandled(int alarmId) {
    return wasRecentlyStopped(alarmId) || wasRecentlySnoozed(alarmId);
  }

  /// Check if an alarm is currently active (ringing or snoozed)
  bool isAlarmActive(int alarmId) {
    final state = getAlarmState(alarmId);
    return state == AlarmState.ringing || state == AlarmState.snoozed;
  }

  /// Clear alarm state (useful when scheduling new alarms)
  void clearAlarmState(int alarmId) {
    _alarmStates.remove(alarmId);
    _alarmStopTimes.remove(alarmId);
    print('🔔 Alarm $alarmId state cleared');
  }

  /// Clear all alarm states
  void clearAllAlarmStates() {
    _alarmStates.clear();
    _alarmStopTimes.clear();
    print('🔔 All alarm states cleared');
  }
}
