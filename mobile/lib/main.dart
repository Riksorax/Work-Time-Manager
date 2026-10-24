import 'dart:async' show unawaited;

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
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_work_time/core/utils/timezone_utils.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io' show Platform;

import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain/utils/timer_action.dart';
import 'core/providers/app_lock_provider.dart';
import 'core/providers/providers.dart';
import 'core/services/app_lock_store.dart';
import 'core/providers/widget_sync_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/shortcut_service.dart';
import 'core/services/timer_action_background.dart';
import 'core/services/timer_action_inbox.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_navigator.dart';
import 'core/utils/revenuecat_state.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'presentation/view_models/settings_view_model.dart';
import 'presentation/view_models/theme_view_model.dart';
import 'presentation/view_models/timer_action_view_model.dart';
import 'presentation/widgets/app_lock_layer.dart';
import 'presentation/widgets/common/edge_to_edge.dart';

/// Wie der Tap auf eine Erinnerung: zum Dashboard (HomeScreen, Index 0).
/// Beim Kaltstart gibt es den Navigator noch nicht, dann ist das Dashboard
/// ohnehin die Startseite.
void _openDashboard() {
  navigatorKey.currentState?.pushReplacement(
    MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 0)),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-Edge auf allen Android-Versionen (#468), vor dem ersten Frame.
  await enableEdgeToEdge();

  // SharedPreferences früh laden, damit eine manuelle Zeitzone-Überschreibung
  // (siehe #221) schon vor der Zeitzone-Initialisierung verfügbar ist.
  final prefs = await SharedPreferences.getInstance();

  // App-Sperre (#375): Sperr-Werte liegen im sicheren Speicher (Ausnahme zur
  // Prefs-Regel, nur für Secrets). Der Ladevorgang samt Migration läuft
  // parallel zur restlichen Initialisierung und wird unmittelbar vor `runApp`
  // abgewartet, damit der erste Build den Sperrzustand schon kennt. `load`
  // wirft nie und hat ein Zeitlimit.
  final lockStoreFuture = AppLockStore.load(prefs: prefs);

  // Initialize timezone
  tz_data.initializeTimeZones();
  await applyTimezone(prefs.getString(timezoneOverridePrefsKey));

  // Beide unterstützten Sprachen laden (siehe #221) - unabhängig von der
  // aktuellen Auswahl, damit ein Sprachwechsel zur Laufzeit ohne erneutes
  // Nachladen funktioniert.
  await initializeDateFormatting('de_DE', null);
  await initializeDateFormatting('en_US', null);
  final locale = prefs.getString('locale') ?? 'de';
  Intl.defaultLocale = locale == 'en' ? 'en_US' : 'de_DE';

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
      try {
        await Purchases.configure(PurchasesConfiguration(activeKey));
        revenueCatConfigured = true;
      } catch (e, stackTrace) {
        logger.e('RevenueCat-Konfiguration fehlgeschlagen',
            error: e, stackTrace: stackTrace);
      }
    } else {
      logger.w(
          'RevenueCat nicht initialisiert – kein API-Key via --dart-define übergeben.');
    }
  }

  // Der Site Key wird sicher via --dart-define=RECAPTCHA_SITE_KEY=your_key beim Build injiziert
  const String kWebRecaptchaSiteKey =
      String.fromEnvironment('RECAPTCHA_SITE_KEY');

  await AppBootstrap.ensureInitializedForEnv(
    webRecaptchaSiteKey:
        kWebRecaptchaSiteKey.isEmpty ? null : kWebRecaptchaSiteKey,
  );

  // Timer-Aktionen von außen (Notification-Buttons, App-Shortcuts, #274):
  // die Callbacks feuern vor dem Widget-Baum und legen die Aktion in den
  // Briefkasten; das TimerActionViewModel führt sie nach Auth/Entsperren aus.
  final inbox = TimerActionInbox.instance;
  // Aktionen ohne Oberfläche (#485) übergibt ein Hintergrund-Isolate über
  // diesen Port, solange die App läuft; ohne App führt es sie selbst aus.
  if (!kIsWeb && Platform.isAndroid) registerTimerActionPort(inbox);
  // Eine bei aktiver App-Sperre gemerkte Aktion (Hinweis „App entsperren“).
  final pendingAction = takePendingTimerAction(prefs, DateTime.now());
  if (pendingAction != null) inbox.push(pendingAction);
  void onTimerAction(TimerAction action) {
    inbox.push(action);
    _openDashboard();
  }

  // Initialize notification service with deep-link callback
  final notificationService = NotificationService();
  await notificationService.initialize(
    onNotificationTap: (payload) {
      if (payload == 'open_dashboard') {
        _openDashboard();
      }
    },
    onTimerAction: onTimerAction,
  );

  // Kaltstart über einen Notification-Button: das Plugin ruft den Callback dann
  // nicht auf, die Aktion steckt in den Start-Details.
  final launchAction = await notificationService.launchTimerAction();
  if (launchAction != null) inbox.push(launchAction);

  // App-Icon-Shortcuts (nur Android; Kaltstart-Shortcut kommt direkt nach
  // `initialize` an den Handler).
  final shortcutService = ShortcutService();
  await shortcutService.initialize(onTimerAction);
  await shortcutService.setShortcuts(
      lookupAppLocalizations(Locale(prefs.getString('locale') ?? 'de')));

  // Request notification permissions
  await notificationService.requestPermissions();

  // Der Sperrzustand entscheidet, ob Erinnerungs-Buttons im Hintergrund laufen.
  final lockStore = await lockStoreFuture;

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
      notificationDays =
          notificationDaysString.split(',').map((e) => int.parse(e)).toList();
    }
    final notifyWorkStart = prefs.getBool('notify_work_start') ?? true;
    final notifyWorkEnd = prefs.getBool('notify_work_end') ?? true;
    final notifyBreaks = prefs.getBool('notify_breaks') ?? true;

    logger.i(
        'Scheduling daily reminder with time: $notificationTime, days: $notificationDays, checkWorkStart: $notifyWorkStart, checkWorkEnd: $notifyWorkEnd, checkBreaks: $notifyBreaks');
    await notificationService.scheduleDailyReminder(
      time: notificationTime,
      days: notificationDays,
      checkWorkStart: notifyWorkStart,
      checkWorkEnd: notifyWorkEnd,
      checkBreaks: notifyBreaks,
      // Ohne App-Sperre laufen die Buttons im Hintergrund (#485).
      headlessActions: !(lockStore.getBool(AppLockKeys.enabled) == true &&
          lockStore.getString(AppLockKeys.pinHash) != null),
      l10n: lookupAppLocalizations(Locale(prefs.getString('locale') ?? 'de')),
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockStoreProvider.overrideWithValue(lockStore),
        shortcutServiceProvider.overrideWithValue(shortcutService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Siehe #223: beim Wechsel in den Hintergrund erneut sperren, damit die
  // App nicht offen bleibt, wenn sie später aus dem Task-Switcher zurückkehrt.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb || state != AppLifecycleState.paused) return;
    final appLockService = ref.read(appLockServiceProvider);
    if (appLockService.isEnabled && appLockService.hasPin) {
      ref.read(isAppLockedProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeViewModelProvider);
    // Siehe #218: steuert app-weit, ob Zeitpicker/-anzeigen, die auf
    // MediaQuery.alwaysUse24HourFormat reagieren (z. B. showTimePicker,
    // MaterialLocalizations.formatTimeOfDay), 24h- oder 12h-Format nutzen.
    final use24HourFormat =
        ref.watch(settingsViewModelProvider).value?.settings.use24HourFormat ??
            true;
    // Siehe #221: steuert die Sprache der App-Oberfläche zur Laufzeit.
    final localeCode =
        ref.watch(settingsViewModelProvider).value?.settings.locale ?? 'de';
    final isLocked = !kIsWeb && ref.watch(isAppLockedProvider);
    // Siehe #276: haelt das Android-Status-Widget aktuell (auf anderen
    // Plattformen ein No-op, auf Web gar nicht erst gestartet).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      ref.watch(widgetSyncProvider);
    }
    // Timer-Aktionen von außen (#274): hält das ViewModel am Leben, das sie
    // nach Auth und Entsperren ausführt.
    ref.watch(timerActionViewModelProvider);
    // Shortcut-Labels folgen der App-Sprache (nie `watch`: kein Neuaufbau).
    ref.listen<String>(
      settingsViewModelProvider.select((s) => s.value?.settings.locale ?? 'de'),
      (previous, next) {
        if (previous == next) return;
        unawaited(ref
            .read(shortcutServiceProvider)
            .setShortcuts(lookupAppLocalizations(Locale(next))));
      },
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Work Time Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: Locale(localeCode),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(alwaysUse24HourFormat: use24HourFormat),
          child: SystemBarsStyle(
            child: AppLockLayer(
              isLocked: isLocked,
              // Die Sperre sichert sich selbst ab (eigener SafeArea).
              child: HorizontalSafeInsets(child: child!),
            ),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
