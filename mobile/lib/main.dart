import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/presentation/screens/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/app_check_initializer.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io' show Platform;

import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/providers/providers.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/view_models/settings_view_model.dart';
import 'presentation/view_models/theme_view_model.dart';

// Global key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {

  // Initialize timezone
  tz_data.initializeTimeZones();
  try {
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName.toString()));
  } catch (e) {
    WidgetsFlutterBinding.ensureInitialized();
    logger.w("Could not get local timezone, falling back to UTC/Europe/Berlin");
    // Fallback logic
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }


  await initializeDateFormatting('de_DE', null);
  Intl.defaultLocale = 'de_DE';

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crash-/Fehler-Tracking (siehe #207): Crashlytics ist nur auf
  // Android/iOS verfügbar, auf Web gibt es keine native Absturzerfassung.
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // RevenueCat Setup
  // Wir initialisieren RevenueCat NUR auf mobilen Plattformen (Android/iOS),
  // da wir im Web aktuell keine Zahlungen unterstützen und die Initialisierung
  // ohne gültigen Web-Billing-Key sonst zu einem Absturz führt.
  if (!kIsWeb) {
    await Purchases.setLogLevel(LogLevel.debug);

    // Lese Keys aus Environment Variables (via --dart-define)
    const rcAndroidKey = String.fromEnvironment('RC_ANDROID_KEY');
    const rcIosKey = String.fromEnvironment('RC_IOS_KEY');

    final String? activeKey = Platform.isAndroid
        ? (rcAndroidKey.isEmpty ? null : rcAndroidKey)
        : Platform.isIOS
            ? (rcIosKey.isEmpty ? null : rcIosKey)
            : null;

    if (activeKey != null) {
      await Purchases.configure(PurchasesConfiguration(activeKey));
    } else {
      logger.w('RevenueCat nicht initialisiert – kein API-Key via --dart-define übergeben.');
    }
  }

  // Der Site Key wird sicher via --dart-define=RECAPTCHA_SITE_KEY=your_key beim Build injiziert
  const String kWebRecaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
  
  await AppBootstrap.ensureInitializedForEnv(
    webRecaptchaSiteKey: kWebRecaptchaSiteKey.isEmpty ? null : kWebRecaptchaSiteKey,
  );

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

  // Request notification permissions
  await notificationService.requestPermissions();

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
    // Siehe #218: steuert app-weit, ob Zeitpicker/-anzeigen, die auf
    // MediaQuery.alwaysUse24HourFormat reagieren (z. B. showTimePicker,
    // MaterialLocalizations.formatTimeOfDay), 24h- oder 12h-Format nutzen.
    final use24HourFormat =
        ref.watch(settingsViewModelProvider).value?.settings.use24HourFormat ?? true;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Work Time Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('de', 'DE'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de', 'DE'),
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24HourFormat),
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}