import 'package:lecture_reminder_system/model/alarm_model.dart';

class AlarmStateService {
  static final AlarmStateService _instance = AlarmStateService._internal();
  factory AlarmStateService() => _instance;
  AlarmStateService._internal();

  // Map to track alarm states by alarm ID
  final Map<int, AlarmState> _alarmStates = {};
  final Map<int, DateTime> _alarmStopTimes = {};

  // Map to track snooze information
  final Map<int, DateTime> _snoozeTimes = {};
  final Map<int, int> _snoozeCounts = {};

  // Map to track which UI is currently showing the alarm
  final Map<int, String> _activeUI = {}; // 'flutter' or 'native'

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

  /// Check if an alarm was recently stopped (within last 2 minutes)
  bool wasRecentlyStopped(int alarmId) {
    final stopTime = _alarmStopTimes[alarmId];
    if (stopTime == null) return false;

    final timeSinceStop = DateTime.now().difference(stopTime);
    return timeSinceStop.inMinutes < 2;
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

  /// Check if an alarm is currently ringing
  bool isAlarmRinging(int alarmId) {
    final state = getAlarmState(alarmId);
    return state == AlarmState.ringing;
  }

  /// Check if an alarm should be restarted (not stopped and not recently handled)
  bool shouldRestartAlarm(int alarmId) {
    final state = getAlarmState(alarmId);
    return state != AlarmState.stopped && !wasRecentlyHandled(alarmId);
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
    _snoozeTimes.clear();
    _snoozeCounts.clear();
    _activeUI.clear();
    print('🔔 All alarm states cleared');
  }

  /// Set which UI is currently showing the alarm
  void setActiveUI(int alarmId, String uiType) {
    _activeUI[alarmId] = uiType;
    print('🔔 Alarm $alarmId now showing in $uiType UI');
  }

  /// Get which UI is currently showing the alarm
  String? getActiveUI(int alarmId) {
    return _activeUI[alarmId];
  }

  /// Check if alarm is already showing in any UI
  bool isAlarmShowing(int alarmId) {
    return _activeUI.containsKey(alarmId);
  }

  /// Handle snooze for an alarm
  void snoozeAlarm(int alarmId, int snoozeMinutes) {
    final now = DateTime.now();
    final snoozeTime = now.add(Duration(minutes: snoozeMinutes));

    _snoozeTimes[alarmId] = snoozeTime;
    _snoozeCounts[alarmId] = (_snoozeCounts[alarmId] ?? 0) + 1;
    _alarmStates[alarmId] = AlarmState.snoozed;

    print(
      '⏰ Alarm $alarmId snoozed for $snoozeMinutes minutes until $snoozeTime',
    );
  }

  /// Get snooze time for an alarm
  DateTime? getSnoozeTime(int alarmId) {
    return _snoozeTimes[alarmId];
  }

  /// Get snooze count for an alarm
  int getSnoozeCount(int alarmId) {
    return _snoozeCounts[alarmId] ?? 0;
  }

  /// Check if alarm should be shown based on snooze
  bool shouldShowSnoozedAlarm(int alarmId) {
    final snoozeTime = _snoozeTimes[alarmId];
    if (snoozeTime == null) return false;

    final now = DateTime.now();
    return now.isAfter(snoozeTime);
  }

  /// Completely stop an alarm (including snooze)
  void stopAlarmCompletely(int alarmId) {
    _alarmStates[alarmId] = AlarmState.stopped;
    _alarmStopTimes[alarmId] = DateTime.now();
    _snoozeTimes.remove(alarmId);
    _snoozeCounts.remove(alarmId);
    _activeUI.remove(alarmId);

    print('🔕 Alarm $alarmId completely stopped and snooze cancelled');
  }

  /// Check if alarm can be snoozed
  bool canSnooze(int alarmId, int maxSnoozeCount) {
    final currentCount = _snoozeCounts[alarmId] ?? 0;
    return currentCount < maxSnoozeCount;
  }
}
