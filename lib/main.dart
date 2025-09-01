import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lecture_reminder_system/presentation/screens/lecture_list_page/lecture_list_page.dart';
import 'package:lecture_reminder_system/presentation/screens/alarm_screen/alarm_screen.dart';
import 'package:lecture_reminder_system/model/alarm_model.dart';
import 'package:lecture_reminder_system/core/services/alarm_service.dart';
import 'package:lecture_reminder_system/core/services/overlay_alarm_service.dart';
import 'package:lecture_reminder_system/core/services/alarm_state_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global variable to track if app was launched from notification
String? _initialNotificationPayload;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database
  tz.initializeTimeZones();

  // Initialize local notifications
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      debugPrint('Notification tapped: ${response.payload}');
      // Handle alarm notification tap (works when app is closed or open)
      if (response.payload != null) {
        // Store the payload for initial launch
        _initialNotificationPayload = response.payload;

        try {
          final alarmData = jsonDecode(response.payload!);
          final alarm = Alarm.fromJson(alarmData);
          final alarmStateService = AlarmStateService();

          // Check if alarm is already showing or was recently stopped
          if (alarmStateService.isAlarmShowing(alarm.hashCode)) {
            debugPrint(
              '🔔 Alarm ${alarm.title} is already showing - not triggering again',
            );
            return;
          }

          if (alarmStateService.wasRecentlyStopped(alarm.hashCode)) {
            debugPrint(
              '🔔 Alarm ${alarm.title} was recently stopped - not showing again',
            );
            return;
          }

          // Additional check: if app is active and alarm is already ringing, don't show again
          final isCurrentlyActive =
              WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed;
          if (isCurrentlyActive &&
              alarmStateService.isAlarmRinging(alarm.hashCode)) {
            debugPrint(
              '🔔 Alarm ${alarm.title} is already ringing in Flutter - not showing duplicate UI',
            );
            return;
          }

          // Check if this is a snoozed alarm that should be shown
          if (alarmStateService.getAlarmState(alarm.hashCode) ==
              AlarmState.snoozed) {
            if (!alarmStateService.shouldShowSnoozedAlarm(alarm.hashCode)) {
              debugPrint('🔔 Snoozed alarm ${alarm.title} not ready yet');
              return;
            }
            debugPrint('🔔 Showing snoozed alarm ${alarm.title}');
          }

          // Check if app is in focus/active
          final isAppActive =
              WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed;

          if (isAppActive) {
            // App is open and in focus - ALWAYS use Flutter alarm screen
            // Never show native overlay when app is open
            debugPrint(
              '🔔 App is active - using Flutter alarm screen for: ${alarm.title}',
            );

            // Mark this alarm as showing in Flutter UI
            alarmStateService.setActiveUI(alarm.hashCode, 'flutter');
            alarmStateService.setAlarmState(alarm.hashCode, AlarmState.ringing);

            // IMPORTANT: Cancel any native alarm that might be trying to show
            // This prevents double UIs when both are scheduled
            try {
              final overlayAlarmService = OverlayAlarmService();
              await overlayAlarmService.cancelNativeAlarm(alarm);
              debugPrint(
                '🔔 Cancelled scheduled native alarm for ${alarm.title} to prevent double UI',
              );
            } catch (e) {
              debugPrint('⚠️ Failed to cancel native alarm: $e');
            }

            final alarmService = AlarmService();
            await alarmService.startAlarm(alarm);

            // Navigate to alarm screen
            Future.delayed(const Duration(milliseconds: 500), () {
              if (navigatorKey.currentContext != null) {
                Navigator.of(navigatorKey.currentContext!).push(
                  MaterialPageRoute(
                    builder: (context) => AlarmScreen(alarm: alarm),
                    fullscreenDialog: true,
                  ),
                );
              }
            });
          } else {
            // App is closed or not in focus - check overlay permission
            debugPrint(
              '🔔 App is not active - checking overlay permission for: ${alarm.title}',
            );

            final overlayAlarmService = OverlayAlarmService();
            final hasPermission = await overlayAlarmService
                .hasOverlayPermission();

            if (hasPermission) {
              // Permission granted - show native overlay over other apps
              // But first double-check that app is still not active
              final isStillActive =
                  WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed;
              if (!isStillActive) {
                // Mark this alarm as showing in native UI
                alarmStateService.setActiveUI(alarm.hashCode, 'native');
                alarmStateService.setAlarmState(
                  alarm.hashCode,
                  AlarmState.ringing,
                );

                await overlayAlarmService.startAlarmOverlay(alarm);
              } else {
                debugPrint(
                  '🔔 App became active - using Flutter alarm screen instead',
                );
                // App became active, use Flutter alarm screen
                // Mark this alarm as showing in Flutter UI
                alarmStateService.setActiveUI(alarm.hashCode, 'flutter');
                alarmStateService.setAlarmState(
                  alarm.hashCode,
                  AlarmState.ringing,
                );

                // IMPORTANT: Cancel any native alarm that might be trying to show
                // This prevents double UIs when both are scheduled
                try {
                  await overlayAlarmService.cancelNativeAlarm(alarm);
                  debugPrint(
                    '🔔 Cancelled scheduled native alarm for ${alarm.title} to prevent double UI',
                  );
                } catch (e) {
                  debugPrint('⚠️ Failed to cancel native alarm: $e');
                }

                final alarmService = AlarmService();
                await alarmService.startAlarm(alarm);

                Future.delayed(const Duration(milliseconds: 500), () {
                  if (navigatorKey.currentContext != null) {
                    Navigator.of(navigatorKey.currentContext!).push(
                      MaterialPageRoute(
                        builder: (context) => AlarmScreen(alarm: alarm),
                        fullscreenDialog: true,
                      ),
                    );
                  }
                });
              }
            } else {
              // Permission denied - just show notification, no overlay
              // The notification will be handled by the notification system
              debugPrint(
                '🔔 Overlay permission denied - showing notification only',
              );
            }
          }
        } catch (e) {
          debugPrint('Error parsing alarm data: $e');
        }
      }
    },
  );

  // Register notification channel (Android 8+)
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'alarm_channel',
    'Alarm Notifications',
    description: 'Lecture alarm notifications',
    importance: Importance.max,
  );

  await androidPlugin?.createNotificationChannel(channel);

  // Set up broadcast receiver for alarm state changes from native service
  const MethodChannel alarmChannel = MethodChannel('alarm_overlay_channel');
  alarmChannel.setMethodCallHandler((call) async {
    if (call.method == 'onAlarmStateChanged') {
      final alarmId = call.arguments['alarm_id'] as int?;
      final state = call.arguments['state'] as String?;

      if (alarmId != null && state != null) {
        final alarmStateService = AlarmStateService();

        switch (state) {
          case 'stopped':
            alarmStateService.stopAlarmCompletely(alarmId);
            debugPrint('🔕 Native alarm completely stopped for ID: $alarmId');
            break;
          case 'snoozed':
            // Get snooze duration from native service
            final snoozeMinutes = call.arguments['snooze_minutes'] as int? ?? 5;
            alarmStateService.snoozeAlarm(alarmId, snoozeMinutes);
            debugPrint(
              '⏰ Native alarm snoozed for ID: $alarmId for $snoozeMinutes minutes',
            );

            // Get alarm data from native service to reschedule
            final alarmTitle =
                call.arguments['alarm_title'] as String? ?? 'Lecture Reminder';
            final alarmTime = call.arguments['alarm_time'] as String? ?? '';
            final alarmLocation =
                call.arguments['alarm_location'] as String? ?? '';
            final alarmDay = call.arguments['alarm_day'] as String? ?? '';

            // Create a temporary alarm object for rescheduling
            final tempAlarm = Alarm(
              title: alarmTitle,
              time: alarmTime,
              location: alarmLocation,
              day: alarmDay,
              settings: AlarmSettings(), // Use default settings
            );

            // Schedule the snoozed alarm to show again after snooze duration
            Future.delayed(Duration(minutes: snoozeMinutes), () {
              // Check if app is active to decide which UI to show
              final isAppActive =
                  WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed;

              if (isAppActive) {
                // App is open - show Flutter UI
                debugPrint(
                  '🔔 Snoozed alarm ready - showing Flutter UI for ${tempAlarm.title}',
                );
                _showFlutterAlarmFromMain(tempAlarm);
              } else {
                // App is closed - show native overlay
                debugPrint(
                  '🔔 Snoozed alarm ready - showing native overlay for ${tempAlarm.title}',
                );
                _showNativeAlarmFromMain(tempAlarm);
              }
            });
            break;
        }
      }
    }
  });

  // Request overlay permission on app startup
  await _requestOverlayPermissionOnStartup();

  // Get the initial notification if app was launched from notification
  final initialNotification = await flutterLocalNotificationsPlugin
      .getNotificationAppLaunchDetails();
  if (initialNotification?.didNotificationLaunchApp == true &&
      initialNotification?.notificationResponse?.payload != null) {
    _initialNotificationPayload =
        initialNotification!.notificationResponse!.payload;
    debugPrint('App launched from notification: $_initialNotificationPayload');
  }

  runApp(const LectureReminderApp());
}

// Helper functions for handling snoozed alarms from main scope
void _showFlutterAlarmFromMain(Alarm alarm) {
  final alarmStateService = AlarmStateService();
  final alarmId = alarm.hashCode;

  // Mark this alarm as showing in Flutter UI
  alarmStateService.setActiveUI(alarmId, 'flutter');
  alarmStateService.setAlarmState(alarmId, AlarmState.ringing);

  // Navigate to alarm screen
  if (navigatorKey.currentContext != null) {
    Navigator.push(
      navigatorKey.currentContext!,
      MaterialPageRoute(
        builder: (context) => AlarmScreen(alarm: alarm),
        fullscreenDialog: true,
      ),
    );
  }
}

void _showNativeAlarmFromMain(Alarm alarm) {
  final alarmStateService = AlarmStateService();
  final alarmId = alarm.hashCode;

  // Mark this alarm as showing in native UI
  alarmStateService.setActiveUI(alarmId, 'native');
  alarmStateService.setAlarmState(alarmId, AlarmState.ringing);

  // Start native overlay
  final overlayService = OverlayAlarmService();
  overlayService.startAlarmOverlay(alarm);
}

/// Request overlay permission when the app starts up
Future<void> _requestOverlayPermissionOnStartup() async {
  try {
    final overlayAlarmService = OverlayAlarmService();
    final hasPermission = await overlayAlarmService.hasOverlayPermission();

    if (!hasPermission) {
      debugPrint(
        '🔔 Overlay permission not granted. Will request when app is ready.',
      );
      // We'll request permission after the app is fully loaded
      // This is handled in the _LectureReminderAppState.initState()
    } else {
      debugPrint('✅ Overlay permission already granted.');
    }
  } catch (e) {
    debugPrint('❌ Error checking overlay permission on startup: $e');
  }
}

class LectureReminderApp extends StatefulWidget {
  const LectureReminderApp({super.key});

  @override
  State<LectureReminderApp> createState() => _LectureReminderAppState();
}

class _LectureReminderAppState extends State<LectureReminderApp> {
  Timer? _snoozeCheckTimer;

  @override
  void initState() {
    super.initState();
    // Check if app was launched from notification and request overlay permission
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationLaunch();
      _requestOverlayPermissionOnAppReady();
      _startSnoozeCheckTimer();
    });
  }

  @override
  void dispose() {
    _snoozeCheckTimer?.cancel();
    super.dispose();
  }

  void _startSnoozeCheckTimer() {
    // Check for snoozed alarms every 10 seconds
    _snoozeCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkSnoozedAlarms();
    });
  }

  void _checkSnoozedAlarms() {
    final alarmStateService = AlarmStateService();

    // Check if there are any snoozed alarms that are ready to show
    // We need to find the alarm that was snoozed and check if it's time to show it
    // For now, we'll implement a basic check - in a real app, you'd want to store
    // the alarm data somewhere to retrieve it when needed

    debugPrint('🔍 Checking for snoozed alarms...');

    // TODO: Implement proper snoozed alarm checking
    // This would involve:
    // 1. Storing alarm data when it's snoozed
    // 2. Checking if any stored alarms are ready to show
    // 3. Triggering the appropriate UI (Flutter or native) based on app state
  }

  void _checkNotificationLaunch() async {
    // Check if app was launched from notification
    if (_initialNotificationPayload != null) {
      try {
        final alarmData = jsonDecode(_initialNotificationPayload!);
        final alarm = Alarm.fromJson(alarmData);
        final alarmStateService = AlarmStateService();

        // Check if alarm is already showing or was recently stopped
        if (alarmStateService.isAlarmShowing(alarm.hashCode)) {
          debugPrint(
            '🔔 Alarm ${alarm.title} is already showing - not triggering again',
          );
          _initialNotificationPayload = null;
          return;
        }

        if (alarmStateService.wasRecentlyStopped(alarm.hashCode)) {
          debugPrint(
            '🔔 Alarm ${alarm.title} was recently stopped - not showing again',
          );
          _initialNotificationPayload = null;
          return;
        }

        // Additional check: if app is active and alarm is already ringing, don't show again
        final isCurrentlyActive =
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
        if (isCurrentlyActive &&
            alarmStateService.isAlarmRinging(alarm.hashCode)) {
          debugPrint(
            '🔔 Alarm ${alarm.title} is already ringing in Flutter - not showing duplicate UI',
          );
          _initialNotificationPayload = null;
          return;
        }

        // Check if this is a snoozed alarm that should be shown
        if (alarmStateService.getAlarmState(alarm.hashCode) ==
            AlarmState.snoozed) {
          if (!alarmStateService.shouldShowSnoozedAlarm(alarm.hashCode)) {
            debugPrint('🔔 Snoozed alarm ${alarm.title} not ready yet');
            _initialNotificationPayload = null;
            return;
          }
          debugPrint('🔔 Showing snoozed alarm ${alarm.title}');
        }

        // Since this is called when app is launched from notification,
        // we should use the Flutter alarm screen approach
        // But first check if app is currently active
        final isAppActive =
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

        if (isAppActive) {
          // Mark this alarm as showing in Flutter UI
          alarmStateService.setActiveUI(alarm.hashCode, 'flutter');
          alarmStateService.setAlarmState(alarm.hashCode, AlarmState.ringing);

          // IMPORTANT: Cancel any native alarm that might be trying to show
          // This prevents double UIs when both are scheduled
          try {
            final overlayAlarmService = OverlayAlarmService();
            await overlayAlarmService.cancelNativeAlarm(alarm);
            debugPrint(
              '🔔 Cancelled scheduled native alarm for ${alarm.title} to prevent double UI',
            );
          } catch (e) {
            debugPrint('⚠️ Failed to cancel native alarm: $e');
          }

          final alarmService = AlarmService();
          await alarmService.startAlarm(alarm);

          // Navigate to alarm screen
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (navigatorKey.currentContext != null) {
              Navigator.of(navigatorKey.currentContext!).push(
                MaterialPageRoute(
                  builder: (context) => AlarmScreen(alarm: alarm),
                  fullscreenDialog: true,
                ),
              );
            }
          });
        } else {
          // App is not active, use native overlay
          final overlayAlarmService = OverlayAlarmService();
          final hasPermission = await overlayAlarmService
              .hasOverlayPermission();

          if (hasPermission) {
            // Mark this alarm as showing in native UI
            alarmStateService.setActiveUI(alarm.hashCode, 'native');
            alarmStateService.setAlarmState(alarm.hashCode, AlarmState.ringing);

            await overlayAlarmService.startAlarmOverlay(alarm);
          }
        }

        // Clear the payload after handling
        _initialNotificationPayload = null;
      } catch (e) {
        debugPrint('Error handling initial notification: $e');
        _initialNotificationPayload = null;
      }
    }
  }

  /// Request overlay permission with a user-friendly dialog when the app is ready
  Future<void> _requestOverlayPermissionOnAppReady() async {
    try {
      final overlayAlarmService = OverlayAlarmService();
      final hasPermission = await overlayAlarmService.hasOverlayPermission();

      if (!hasPermission && mounted) {
        // Show a dialog explaining why we need the permission
        final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Permission Required'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To show alarm overlays over other apps, we need the "Display over other apps" permission.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  'This allows the alarm to appear even when you\'re using other apps, just like a system alarm.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(height: 16),
                Text(
                  'Would you like to grant this permission now?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        );

        if (shouldRequest == true && mounted) {
          final granted = await overlayAlarmService.requestOverlayPermission();

          if (mounted) {
            if (granted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '✅ Overlay permission granted! Alarms will appear over other apps.',
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '❌ Permission denied. Alarms will work normally but won\'t appear over other apps.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error requesting overlay permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Lecture Reminder',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1E293B),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6366F1),
            side: const BorderSide(color: Color(0xFF6366F1)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
          ),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF475569)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
      ),
      home: const LectureListPage(),
    );
  }
}
