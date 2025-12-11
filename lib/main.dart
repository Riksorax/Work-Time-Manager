import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/presentation/screens/home_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/app_check_initializer.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'core/config/google_sign_in_config.dart';
import 'core/providers/providers.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/view_models/theme_view_model.dart';

// Global key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone
  tz_data.initializeTimeZones();
  try {
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    logger.e("Could not get local timezone, falling back to 'Europe/Berlin'", error: e);
    tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
  }


  await initializeDateFormatting('de_DE', null);
  Intl.defaultLocale = 'de_DE';

  await GoogleSignIn.instance.initialize(
    serverClientId: GoogleSignInConfig.serverClientId,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AppBootstrap.ensureInitializedForEnv();

  final prefs = await SharedPreferences.getInstance();

  // Initialize notification service with deep-link callback
  final notificationService = NotificationService();
  await notificationService.initialize(
    onNotificationTap: (payload) {
      if (payload == 'open_dashboard') {
        // Navigate to dashboard (HomeScreen with index 0)
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 0)),
        );
      }
    },
  );

  // Reschedule notifications if enabled
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
  if (notificationsEnabled) {
    final notificationTime = prefs.getString('notification_time') ?? '18:00';
    final notificationDaysString = prefs.getString('notification_days');
    final List<int> notificationDays;
    if (notificationDaysString == null) {
      notificationDays = [1, 2, 3, 4, 5]; // Default for first run
    } else if (notificationDaysString.isEmpty) {
      notificationDays = []; // No days selected
    } else {
      notificationDays = notificationDaysString.split(',').map((e) => int.parse(e)).toList();
    }
    final notifyWorkStart = prefs.getBool('notify_work_start') ?? true;
    final notifyWorkEnd = prefs.getBool('notify_work_end') ?? true;
    final notifyBreaks = prefs.getBool('notify_breaks') ?? true;

    logger.i('Scheduling daily reminder with time: $notificationTime, days: $notificationDays, checkWorkStart: $notifyWorkStart, checkWorkEnd: $notifyWorkEnd, checkBreaks: $notifyBreaks');
    await notificationService.scheduleDailyReminder(
      time: notificationTime,
      days: notificationDays,
      checkWorkStart: notifyWorkStart,
      checkWorkEnd: notifyWorkEnd,
      checkBreaks: notifyBreaks,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeViewModelProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Work Time Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}