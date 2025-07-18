import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lecture_reminder_system/model/lecture_model.dart';
import 'package:lecture_reminder_system/presentation/screens/add_lecture_page/add_lecture_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class LectureListPage extends StatefulWidget {
  const LectureListPage({super.key});

  @override
  _LectureListPageState createState() => _LectureListPageState();
}

class _LectureListPageState extends State<LectureListPage> {
  List<Lecture> lectures = [];
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadLectures();
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();
    final localTimezone = tz.getLocation(
      'Africa/Lagos',
    ); // Explicitly set to WAT
    tz.setLocalLocation(localTimezone);
    debugPrint('Current timezone: ${tz.local.name}');

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    final bool? initResult = await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint(
          'Notification triggered: ID=${response.id}, Payload=${response.payload}',
        );
      },
    );
    debugPrint(
      'Notification initialization: ${initResult == true ? "Success" : "Failed or null"}',
    );

    // Clear all existing notifications to avoid conflicts
    await _notificationsPlugin.cancelAll();
    debugPrint('Cleared all existing notifications');

    // Android permissions (Android 13+)
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final bool? notificationGranted = await androidPlugin
          .requestNotificationsPermission();
      debugPrint(
        'Notification permission granted: ${notificationGranted == true}',
      );
      final bool? exactAlarmGranted = await androidPlugin
          .requestExactAlarmsPermission();
      debugPrint(
        'Exact alarm permission: ${exactAlarmGranted == true ? "Granted" : "Denied or null"}',
      );
    }

    // iOS permissions
    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      final bool? iosGranted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('iOS notification permission granted: ${iosGranted == true}');
    }

    // Test notification (triggers 10 seconds from now)
    final testDate = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(seconds: 10));
    await _notificationsPlugin.zonedSchedule(
      999,
      'Test Notification',
      'This is a test to verify notifications work.',
      testDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lecture_channel',
          'Lecture Reminders',
          channelDescription: 'Lecture schedule reminder',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('Test notification scheduled for: $testDate');
  }

  Future<void> _loadLectures() async {
    final prefs = await SharedPreferences.getInstance();
    final lectureStrings = prefs.getStringList('lectures') ?? [];
    setState(() {
      lectures = lectureStrings
          .map((e) => Lecture.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  Future<void> _saveLectures() async {
    final prefs = await SharedPreferences.getInstance();
    final lectureStrings = lectures.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('lectures', lectureStrings);
  }

  Future<void> _scheduleNotification(
    Lecture lecture, {
    bool forceNow = false,
    bool forceToday = false,
  }) async {
    final now = DateTime.now();
    debugPrint(
      'Scheduling: ${lecture.title} on ${lecture.day} at ${lecture.time} '
      '(Current time: $now, Force now: $forceNow, Force today: $forceToday)',
    );

    if (forceNow) {
      // Schedule for 10 seconds from now for testing
      final tzScheduledDate = tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(seconds: 10));
      await _notificationsPlugin.zonedSchedule(
        lecture.hashCode,
        lecture.title,
        'Lecture at ${lecture.location} on ${lecture.day} (Test)',
        tzScheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lecture_channel',
            'Lecture Reminders',
            channelDescription: 'Lecture schedule reminder',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('🔔 Test notification scheduled for: $tzScheduledDate');
      return;
    }

    final Map<String, int> weekdayMap = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    final int? targetWeekday = weekdayMap[lecture.day];
    if (targetWeekday == null) {
      debugPrint('❌ Invalid day: ${lecture.day}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid day: ${lecture.day}. Use full weekday names.'),
        ),
      );
      return;
    }

    try {
      final timeString = lecture.time.trim();
      final is12Hour =
          timeString.toLowerCase().contains('am') ||
          timeString.toLowerCase().contains('pm');

      int hour;
      int minute;

      if (is12Hour) {
        // Replace non-breaking spaces and normalize
        final cleanedTimeString = timeString
            .replaceAll(RegExp(r'[\u202F\u00A0\s]+'), ' ')
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');
        try {
          final dateTime = DateFormat.jm().parse(cleanedTimeString);
          hour = dateTime.hour;
          minute = dateTime.minute;
        } catch (e) {
          debugPrint(
            '❌ Failed to parse 12-hour time: $cleanedTimeString, error: $e',
          );
          throw FormatException(
            'Invalid 12-hour time format: $cleanedTimeString',
          );
        }
      } else {
        final timeParts = timeString.split(':');
        if (timeParts.length != 2) {
          throw FormatException('Invalid 24-hour time format: $timeString');
        }
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        throw RangeError('Time out of range: hour=$hour, minute=$minute');
      }

      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      int daysToAdd = (targetWeekday - now.weekday + 7) % 7;
      if (forceToday) {
        daysToAdd = 0; // Force scheduling for today
        if (scheduledDate.isBefore(now)) {
          // If time has passed, schedule 10 seconds from now
          scheduledDate = now.add(const Duration(seconds: 10));
        }
      } else if (daysToAdd == 0 && scheduledDate.isBefore(now)) {
        daysToAdd = 7; // Schedule for next week if time has passed
      }

      scheduledDate = scheduledDate.add(Duration(days: daysToAdd));
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      debugPrint('🔔 Scheduled for: $tzScheduledDate');

      await _notificationsPlugin.zonedSchedule(
        lecture.hashCode,
        lecture.title,
        'Lecture at ${lecture.location} on ${lecture.day}${forceToday ? ' (Today)' : ''}',
        tzScheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lecture_channel',
            'Lecture Reminders',
            channelDescription: 'Lecture schedule reminder',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: forceToday
            ? null
            : DateTimeComponents.dayOfWeekAndTime,
      );

      debugPrint('✅ Notification scheduled for ${lecture.title}');
    } catch (e) {
      debugPrint('❌ Failed to schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling notification: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Lectures'), centerTitle: true),
      body: lectures.isEmpty
          ? const Center(child: Text('No lectures added yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lectures.length,
              itemBuilder: (context, index) {
                final lecture = lectures[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      lecture.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      '${lecture.day} at ${lecture.time} - ${lecture.location}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            final updatedLecture = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddLecturePage(
                                  lectureToEdit: lecture,
                                  index: index,
                                ),
                              ),
                            );
                            if (updatedLecture != null) {
                              setState(() {
                                lectures[index] = updatedLecture;
                              });
                              _saveLectures();
                              _notificationsPlugin.cancel(lecture.hashCode);
                              _scheduleNotification(updatedLecture);
                              debugPrint(
                                'Updated lecture: ${updatedLecture.title}',
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              lectures.removeAt(index);
                            });
                            _saveLectures();
                            _notificationsPlugin.cancel(lecture.hashCode);
                            debugPrint(
                              'Cancelled notification for ${lecture.title}',
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_active,
                            color: Colors.green,
                          ),
                          onPressed: () {
                            _scheduleNotification(lecture, forceNow: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Test notification scheduled for 10 seconds from now',
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.today, color: Colors.orange),
                          onPressed: () {
                            _scheduleNotification(lecture, forceToday: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Notification scheduled for today',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newLecture = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddLecturePage()),
          );
          if (newLecture != null) {
            setState(() {
              lectures.add(newLecture);
            });
            _saveLectures();
            _scheduleNotification(
              newLecture,
              forceNow: true,
            ); // Test immediately
            _scheduleNotification(newLecture); // Regular schedule
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Lecture added and test notification scheduled for 10 seconds from now',
                ),
              ),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
