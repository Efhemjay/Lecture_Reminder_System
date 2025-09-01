import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lecture_reminder_system/main.dart';
import 'package:lecture_reminder_system/model/alarm_model.dart';
import 'package:lecture_reminder_system/presentation/screens/add_lecture_page/add_lecture_page.dart';
import 'package:lecture_reminder_system/presentation/screens/alarm_screen/alarm_screen.dart';
import 'package:lecture_reminder_system/core/services/alarm_service.dart';
import 'package:lecture_reminder_system/core/services/overlay_alarm_service.dart';
import 'package:lecture_reminder_system/core/services/alarm_state_service.dart';
import 'package:lecture_reminder_system/presentation/widgets/overlay_permission_request.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class LectureListPage extends StatefulWidget {
  const LectureListPage({super.key});

  @override
  _LectureListPageState createState() => _LectureListPageState();
}

class _LectureListPageState extends State<LectureListPage> {
  List<Alarm> alarms = [];
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AlarmService _alarmService = AlarmService();
  final OverlayAlarmService _overlayAlarmService = OverlayAlarmService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadLectures();
  }

  Future<void> _initializeNotifications() async {
    // Only set timezone once
    final location = tz.getLocation('Africa/Lagos');
    tz.setLocalLocation(location);
    debugPrint('📍 Timezone set to: ${tz.local.name}');

    // Already initialized in main.dart, so no need to reinitialize here
    // Request Android 13+ permissions
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      final exactGranted = await androidPlugin.requestExactAlarmsPermission();
      debugPrint(
        '🔔 Notification permission: $granted | Exact alarms: $exactGranted',
      );
    }

    // iOS permissions
    final iosPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🍏 iOS permission granted: $granted');
    }

    // Schedule test notification in 10s
    // final now = tz.TZDateTime.now(tz.local);
    // final testDate = now.add(const Duration(seconds: 30)); // safer buffer
    // final diff = testDate.difference(now);

    // debugPrint('🧪 Scheduling test notification in ${diff.inSeconds} seconds');

    // await flutterLocalNotificationsPlugin.zonedSchedule(
    //   999,
    //   'Test Notification',
    //   'This is to confirm notifications work.',
    //   testDate,
    //   const NotificationDetails(
    //     android: AndroidNotificationDetails(
    //       'lecture_channel',
    //       'Lecture Reminders',
    //       channelDescription: 'Lecture schedule reminder',
    //       importance: Importance.max,
    //       priority: Priority.high,
    //       playSound: true,
    //       enableVibration: true,
    //     ),
    //     iOS: DarwinNotificationDetails(),
    //   ),
    //   androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    // );

    // debugPrint('🧪 Test notification scheduled for $testDate');
  }

  Future<void> _loadLectures() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmStrings = prefs.getStringList('alarms') ?? [];
    setState(() {
      alarms = alarmStrings.map((e) => Alarm.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveLectures() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmStrings = alarms.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('alarms', alarmStrings);
  }

  Future<void> _scheduleAlarmScreen(
    Alarm alarm, {
    bool forceToday = false,
    DateTime? scheduledDate,
  }) async {
    final now = DateTime.now();

    // Remove forceNow testing logic - no more automatic test alarms
    // if (forceNow) {
    //   // Schedule for 10 seconds from now for testing
    //   Future.delayed(const Duration(seconds: 10), () {
    //     if (mounted) {
    //       _triggerAlarmScreen(alarm);
    //     }
    //   });
    //   return;
    // }

    // If scheduledDate is provided, use it directly
    if (scheduledDate != null) {
      final delay = scheduledDate.difference(now);
      if (delay.isNegative) return;

      Future.delayed(delay, () {
        if (mounted) {
          _triggerAlarmScreen(alarm);
        }
      });

      debugPrint(
        '🔔 Alarm screen scheduled for ${alarm.title} at exact time: $scheduledDate (in ${delay.inSeconds} seconds)',
      );
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

    final int? targetWeekday = weekdayMap[alarm.day];
    if (targetWeekday == null) return;

    try {
      final timeString = alarm.time.trim().toLowerCase();
      final normalizedTimeString = timeString
          .replaceAll(RegExp(r'[\u202F\u00A0\s]+'), ' ')
          .replaceAllMapped(
            RegExp(r'(am|pm)', caseSensitive: false),
            (Match match) => match.group(0)!.toUpperCase(),
          )
          .trim();

      int hour;
      int minute;

      final is12Hour = normalizedTimeString.contains(RegExp(r'AM|PM'));

      if (is12Hour) {
        final parsedTime = DateFormat(
          'h:mm a',
        ).parseStrict(normalizedTimeString);
        hour = parsedTime.hour;
        minute = parsedTime.minute;
      } else {
        final timeParts = normalizedTimeString.split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
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
        daysToAdd = 0;
        if (scheduledDate.isBefore(now)) {
          scheduledDate = now.add(const Duration(seconds: 10));
        }
      } else if (daysToAdd == 0 && scheduledDate.isBefore(now)) {
        daysToAdd = 7;
      }

      scheduledDate = scheduledDate.add(Duration(days: daysToAdd));
      final delay = scheduledDate.difference(now);

      if (delay.isNegative) return;

      Future.delayed(delay, () {
        if (mounted) {
          _triggerAlarmScreen(alarm);
        }
      });

      debugPrint(
        '🔔 Alarm screen scheduled for ${alarm.title} in ${delay.inSeconds} seconds',
      );
    } catch (e) {
      debugPrint('❌ Failed to schedule alarm screen: $e');
    }
  }

  void _triggerAlarmScreen(Alarm alarm) async {
    final alarmStateService = AlarmStateService();
    final alarmId = alarm.hashCode;

    // Check if alarm is already showing in any UI
    if (alarmStateService.isAlarmShowing(alarmId)) {
      debugPrint(
        '🔔 Alarm ${alarm.title} is already showing - not triggering again',
      );
      return;
    }

    // Check if alarm was recently stopped
    if (alarmStateService.wasRecentlyStopped(alarmId)) {
      debugPrint(
        '🔔 Alarm ${alarm.title} was recently stopped - not showing again',
      );
      return;
    }

    // Check if this is a snoozed alarm that should be shown
    if (alarmStateService.getAlarmState(alarmId) == AlarmState.snoozed) {
      if (!alarmStateService.shouldShowSnoozedAlarm(alarmId)) {
        debugPrint('🔔 Snoozed alarm ${alarm.title} not ready yet');
        return;
      }
      debugPrint('🔔 Showing snoozed alarm ${alarm.title}');
    }

    // Check if app is in focus/active
    final isAppActive =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (isAppActive) {
      // App is open and in focus - use Flutter alarm screen
      debugPrint(
        '🔔 App is active - using Flutter alarm screen for: ${alarm.title}',
      );

      // IMPORTANT: Cancel any native alarm that might be trying to show
      // This prevents double UIs when both are scheduled
      try {
        await _overlayAlarmService.cancelNativeAlarm(alarm);
        debugPrint(
          '🔔 Cancelled scheduled native alarm for ${alarm.title} to prevent double UI',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to cancel native alarm: $e');
      }

      // Mark this alarm as showing in Flutter UI
      alarmStateService.setActiveUI(alarmId, 'flutter');
      alarmStateService.setAlarmState(alarmId, AlarmState.ringing);

      await _alarmService.startAlarm(alarm);

      // Navigate to alarm screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AlarmScreen(alarm: alarm),
          fullscreenDialog: true,
        ),
      );
    } else {
      // App is closed or not in focus - check overlay permission
      debugPrint(
        '🔔 App is not active - checking overlay permission for: ${alarm.title}',
      );

      final hasPermission = await _overlayAlarmService.hasOverlayPermission();

      if (hasPermission) {
        // Permission granted - show native overlay over other apps
        // Mark this alarm as showing in native UI
        alarmStateService.setActiveUI(alarmId, 'native');
        alarmStateService.setAlarmState(alarmId, AlarmState.ringing);

        await _overlayAlarmService.startAlarmOverlay(alarm);
      } else {
        // Permission denied - fallback to Flutter alarm
        debugPrint(
          '⚠️ No overlay permission - using Flutter alarm as fallback',
        );
        alarmStateService.setActiveUI(alarmId, 'flutter');
        alarmStateService.setAlarmState(alarmId, AlarmState.ringing);

        await _alarmService.startAlarm(alarm);

        // Navigate to alarm screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlarmScreen(alarm: alarm),
            fullscreenDialog: true,
          ),
        );
      }
    }
  }

  Future<void> _scheduleNotification(
    Alarm alarm, {
    bool forceToday = false,
  }) async {
    final now = DateTime.now();
    debugPrint(
      'Scheduling: ${alarm.title} on ${alarm.day} at ${alarm.time} '
      '(Current time: $now, Force today: $forceToday)',
    );

    // Remove forceNow testing logic - no more automatic test notifications
    // if (forceNow) {
    //   // Schedule for 10 seconds from now for testing
    //   final tzScheduledDate = tz.TZDateTime.now(
    //     tz.local,
    //   ).add(const Duration(seconds: 10));
    //   await _notificationsPlugin.zonedSchedule(
    //     alarm.hashCode,
    //     alarm.title,
    //     'Lecture at ${alarm.location} on ${alarm.day}',
    //     tzScheduledDate,
    //     const NotificationDetails(
    //       android: AndroidNotificationDetails(
    //         'lecture_channel',
    //         'Lecture Reminders',
    //         channelDescription: 'Lecture schedule reminder',
    //         importance: Importance.max,
    //         priority: Priority.high,
    //         playSound: true,
    //         enableVibration: true,
    //     ),
    //       iOS: DarwinNotificationDetails(),
    //     ),
    //     androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    //   );
    //   debugPrint('🔔 Test notification scheduled for: $tzScheduledDate');
    //   return;
    // }

    final Map<String, int> weekdayMap = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    final int? targetWeekday = weekdayMap[alarm.day];
    if (targetWeekday == null) {
      debugPrint('❌ Invalid day: ${alarm.day}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid day: ${alarm.day}. Use full weekday names.'),
        ),
      );
      return;
    }

    try {
      final timeString = alarm.time.trim().toLowerCase();
      // Normalize spaces and AM/PM variations
      final normalizedTimeString = timeString
          .replaceAll(RegExp(r'[\u202F\u00A0\s]+'), ' ')
          .replaceAllMapped(
            RegExp(r'(am|pm)', caseSensitive: false),
            (Match match) => match.group(0)!.toUpperCase(),
          )
          .trim();

      int hour;
      int minute;

      final is12Hour = normalizedTimeString.contains(RegExp(r'AM|PM'));

      if (is12Hour) {
        try {
          // Parse 12-hour format with strict format
          final parsedTime = DateFormat(
            'h:mm a',
          ).parseStrict(normalizedTimeString);
          hour = parsedTime.hour;
          minute = parsedTime.minute;
        } catch (e) {
          debugPrint(
            '❌ Failed to parse 12-hour time: $normalizedTimeString, error: $e',
          );
          throw FormatException(
            'Invalid 12-hour time format: $normalizedTimeString',
          );
        }
      } else {
        final timeParts = normalizedTimeString.split(':');
        if (timeParts.length != 2) {
          throw FormatException(
            'Invalid 24-hour time format: $normalizedTimeString',
          );
        }
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
        if (hour > 23) {
          // Convert 24-hour to 12-hour if needed
          hour = hour % 12 == 0 ? 12 : hour % 12;
        }
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
        // If it's the same day but time has passed, schedule for today (10 seconds from now)
        // This is more user-friendly - if they're setting an alarm, they probably want it now
        scheduledDate = now.add(const Duration(seconds: 10));
        debugPrint(
          '⏰ Time has passed, scheduling for today (10 seconds from now)',
        );
      }

      scheduledDate = scheduledDate.add(Duration(days: daysToAdd));
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      debugPrint('🔔 Scheduled for: $tzScheduledDate');

      // Schedule Flutter notification
      await _notificationsPlugin.zonedSchedule(
        alarm.hashCode,
        alarm.title,
        'Lecture at ${alarm.location} on ${alarm.day}${forceToday ? ' (Today)' : ''}',
        tzScheduledDate,
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
        matchDateTimeComponents: forceToday
            ? null
            : DateTimeComponents.dayOfWeekAndTime,
        payload: jsonEncode(alarm.toJson()),
      );

      // Always schedule Flutter alarm (primary)
      debugPrint('🔔 Scheduling Flutter alarm for ${alarm.title}');
      _scheduleAlarmScreen(
        alarm,
        forceToday: forceToday,
        scheduledDate: scheduledDate,
      );

      // Also schedule native alarm as backup (will only show if app is closed when triggered)
      final hasPermission = await _overlayAlarmService.hasOverlayPermission();
      if (hasPermission) {
        await _overlayAlarmService.scheduleNativeAlarm(alarm, scheduledDate);
        debugPrint(
          '✅ Native alarm also scheduled as backup for ${alarm.title}',
        );
      } else {
        debugPrint('⚠️ No overlay permission - native backup not available');
      }

      debugPrint('✅ Notification scheduled for ${alarm.title}');
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
      appBar: AppBar(
        title: const Text('My Lectures'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showOverlayPermissionDialog,
            tooltip: 'Overlay Settings',
          ),
        ],
      ),
      body: alarms.isEmpty
          ? const Center(child: Text('No lectures added yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alarms.length,
              itemBuilder: (context, index) {
                final alarm = alarms[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      alarm.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      '${alarm.day} at ${alarm.time} - ${alarm.location}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            final updatedAlarm = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddLecturePage(
                                  lectureToEdit: alarm,
                                  index: index,
                                ),
                              ),
                            );
                            if (updatedAlarm != null) {
                              setState(() {
                                alarms[index] = updatedAlarm;
                              });
                              _saveLectures();
                              _notificationsPlugin.cancel(alarm.hashCode);
                              _scheduleNotification(updatedAlarm);
                              debugPrint(
                                'Updated alarm: ${updatedAlarm.title}',
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              alarms.removeAt(index);
                            });
                            _saveLectures();
                            _notificationsPlugin.cancel(alarm.hashCode);
                            debugPrint(
                              'Cancelled notification for ${alarm.title}',
                            );
                          },
                        ),
                        // Test alarm button
                        // IconButton(
                        //   icon: const Icon(Icons.alarm, color: Colors.green),
                        //   onPressed: () async {
                        //     // Start the alarm service directly
                        //     await _alarmService.startAlarm(alarm);
                        //     // Navigate to alarm screen
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (context) => AlarmScreen(alarm: alarm),
                        //         fullscreenDialog: true,
                        //       ),
                        //     );
                        //   },
                        // ),
                        // IconButton(
                        //   icon: const Icon(
                        //     Icons.notifications_active,
                        //     color: Colors.green,
                        //   ),
                        //   onPressed: () {
                        //     _scheduleNotification(lecture, forceNow: true);
                        //     ScaffoldMessenger.of(context).showSnackBar(
                        //       const SnackBar(
                        //         content: Text(
                        //           'Test notification scheduled for 10 seconds from now',
                        //         ),
                        //       ),
                        //     );
                        //   },
                        // ),
                        // IconButton(
                        //   icon: const Icon(Icons.today, color: Colors.orange),
                        //   onPressed: () {
                        //     _scheduleNotification(lecture, forceToday: true);
                        //     ScaffoldMessenger.of(context).showSnackBar(
                        //       const SnackBar(
                        //         content: Text(
                        //           'Notification scheduled for today',
                        //         ),
                        //       ),
                        //     );
                        //   },
                        // ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newLecture = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddLecturePage()),
          );
          if (newLecture != null) {
            setState(() {
              alarms.add(newLecture);
            });
            _saveLectures();
            _scheduleNotification(newLecture); // Regular schedule
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Lecture added successfully!'),
                backgroundColor: const Color(0xFF6366F1),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Lecture'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_outlined,
              size: 80,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Lectures Yet',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first lecture to get started',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final newLecture = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddLecturePage()),
              );
              if (newLecture != null) {
                setState(() {
                  alarms.add(newLecture);
                });
                _saveLectures();
                _scheduleNotification(newLecture);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Lecture'),
          ),
        ],
      ),
    );
  }

  void _showOverlayPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => const OverlayPermissionRequest(),
    );
  }

  Widget _buildLectureList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alarms.length,
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Color(0xFF6366F1),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alarm.title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${alarm.day} at ${alarm.time}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final updatedAlarm = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddLecturePage(
                                  lectureToEdit: alarm,
                                  index: index,
                                ),
                              ),
                            );
                            if (updatedAlarm != null) {
                              setState(() {
                                alarms[index] = updatedAlarm;
                              });
                              _saveLectures();
                              _notificationsPlugin.cancel(alarm.hashCode);
                              _scheduleNotification(updatedAlarm);
                            }
                          } else if (value == 'delete') {
                            setState(() {
                              alarms.removeAt(index);
                            });
                            _saveLectures();
                            _notificationsPlugin.cancel(alarm.hashCode);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Color(0xFF6366F1)),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          alarm.location,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
