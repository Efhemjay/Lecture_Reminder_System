import 'package:lecture_reminder_system/model/lecture_model.dart';

enum AlarmState { idle, ringing, snoozed, stopped }

enum SnoozeInterval {
  fiveMinutes(5),
  tenMinutes(10),
  fifteenMinutes(15),
  thirtyMinutes(30);

  const SnoozeInterval(this.minutes);
  final int minutes;
}

class AlarmSettings {
  final String ringtonePath;
  final bool vibrate;
  final int volume;
  final SnoozeInterval snoozeInterval;
  final int maxSnoozeCount;
  final bool autoStop;

  const AlarmSettings({
    this.ringtonePath = 'alarm',
    this.vibrate = true,
    this.volume = 100,
    this.snoozeInterval = SnoozeInterval.fiveMinutes,
    this.maxSnoozeCount = 3,
    this.autoStop = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'ringtonePath': ringtonePath,
      'vibrate': vibrate,
      'volume': volume,
      'snoozeInterval': snoozeInterval.name,
      'maxSnoozeCount': maxSnoozeCount,
      'autoStop': autoStop,
    };
  }

  factory AlarmSettings.fromJson(Map<String, dynamic> json) {
    return AlarmSettings(
      ringtonePath: json['ringtonePath'] ?? 'alarm',
      vibrate: json['vibrate'] ?? true,
      volume: json['volume'] ?? 100,
      snoozeInterval: SnoozeInterval.values.firstWhere(
        (e) => e.name == json['snoozeInterval'],
        orElse: () => SnoozeInterval.fiveMinutes,
      ),
      maxSnoozeCount: json['maxSnoozeCount'] ?? 3,
      autoStop: json['autoStop'] ?? false,
    );
  }

  AlarmSettings copyWith({
    String? ringtonePath,
    bool? vibrate,
    int? volume,
    SnoozeInterval? snoozeInterval,
    int? maxSnoozeCount,
    bool? autoStop,
  }) {
    return AlarmSettings(
      ringtonePath: ringtonePath ?? this.ringtonePath,
      vibrate: vibrate ?? this.vibrate,
      volume: volume ?? this.volume,
      snoozeInterval: snoozeInterval ?? this.snoozeInterval,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      autoStop: autoStop ?? this.autoStop,
    );
  }
}

class Alarm extends Lecture {
  final AlarmSettings settings;
  final AlarmState state;
  final int snoozeCount;
  final DateTime? lastSnoozeTime;
  final DateTime? nextAlarmTime;

  Alarm({
    required super.title,
    required super.day,
    required super.time,
    required super.location,
    this.settings = const AlarmSettings(),
    this.state = AlarmState.idle,
    this.snoozeCount = 0,
    this.lastSnoozeTime,
    this.nextAlarmTime,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'settings': settings.toJson(),
      'state': state.name,
      'snoozeCount': snoozeCount,
      'lastSnoozeTime': lastSnoozeTime?.toIso8601String(),
      'nextAlarmTime': nextAlarmTime?.toIso8601String(),
    };
  }

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      title: json['title'],
      day: json['day'],
      time: json['time'],
      location: json['location'],
      settings: AlarmSettings.fromJson(json['settings'] ?? {}),
      state: AlarmState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => AlarmState.idle,
      ),
      snoozeCount: json['snoozeCount'] ?? 0,
      lastSnoozeTime: json['lastSnoozeTime'] != null
          ? DateTime.parse(json['lastSnoozeTime'])
          : null,
      nextAlarmTime: json['nextAlarmTime'] != null
          ? DateTime.parse(json['nextAlarmTime'])
          : null,
    );
  }

  Alarm copyWith({
    String? title,
    String? day,
    String? time,
    String? location,
    AlarmSettings? settings,
    AlarmState? state,
    int? snoozeCount,
    DateTime? lastSnoozeTime,
    DateTime? nextAlarmTime,
  }) {
    return Alarm(
      title: title ?? this.title,
      day: day ?? this.day,
      time: time ?? this.time,
      location: location ?? this.location,
      settings: settings ?? this.settings,
      state: state ?? this.state,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      lastSnoozeTime: lastSnoozeTime ?? this.lastSnoozeTime,
      nextAlarmTime: nextAlarmTime ?? this.nextAlarmTime,
    );
  }

  bool get canSnooze => snoozeCount < settings.maxSnoozeCount;
  bool get isRinging => state == AlarmState.ringing;
  bool get isSnoozed => state == AlarmState.snoozed;
}
