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

          // Check if alarm was recently handled (stopped or snoozed)
          if (alarmStateService.wasRecentlyHandled(alarm.hashCode)) {
            final state = alarmStateService.getAlarmState(alarm.hashCode);
            debugPrint(
              '🔔 Alarm ${alarm.title} was recently $state - not showing alarm screen',
            );
            return;
          }

          // Check if app is in focus/active
          final isAppActive =
              WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed;

          if (isAppActive) {
            // App is open and in focus - ALWAYS use Flutter alarm screen
            // Never show native overlay when app is open
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
            final overlayAlarmService = OverlayAlarmService();
            final hasPermission = await overlayAlarmService
                .hasOverlayPermission();

            if (hasPermission) {
              // Permission granted - show native overlay over other apps
              await overlayAlarmService.startAlarmOverlay(alarm);
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
  @override
  void initState() {
    super.initState();
    // Check if app was launched from notification and request overlay permission
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationLaunch();
      _requestOverlayPermissionOnAppReady();
    });
  }

  void _checkNotificationLaunch() async {
    // Check if app was launched from notification
    if (_initialNotificationPayload != null) {
      try {
        final alarmData = jsonDecode(_initialNotificationPayload!);
        final alarm = Alarm.fromJson(alarmData);
        final alarmStateService = AlarmStateService();

        // Check if alarm was recently handled (stopped or snoozed)
        if (alarmStateService.wasRecentlyHandled(alarm.hashCode)) {
          final state = alarmStateService.getAlarmState(alarm.hashCode);
          debugPrint(
            '🔔 Alarm ${alarm.title} was recently $state - not showing alarm screen',
          );
          _initialNotificationPayload = null;
          return;
        }

        // Since this is called when app is launched from notification,
        // we should use the Flutter alarm screen approach
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
