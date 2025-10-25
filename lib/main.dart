import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/presentation/screens/home_screen.dart'; // Geändert
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/app_check_initializer.dart';

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
    final notificationDays = notificationDaysString != null && notificationDaysString.isNotEmpty
        ? notificationDaysString.split(',').map((e) => int.parse(e)).toList()
        : [1, 2, 3, 4, 5];
    final notifyWorkStart = prefs.getBool('notify_work_start') ?? true;
    final notifyWorkEnd = prefs.getBool('notify_work_end') ?? true;
    final notifyBreaks = prefs.getBool('notify_breaks') ?? true;

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
      home: const HomeScreen(), // Geändert von AuthGate zu HomeScreen
    );
  }
}
