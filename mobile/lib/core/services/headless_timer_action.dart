import 'dart:async';
import 'dart:ui' show DartPluginRegistrant, Locale;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import '../../app_check_initializer.dart';
import '../../domain/utils/timer_action.dart';
import '../../firebase_options.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/view_models/dashboard_view_model.dart';
import '../providers/app_lock_provider.dart';
import '../providers/providers.dart';
import '../providers/widget_sync_provider.dart';
import '../utils/logger.dart';
import '../utils/timezone_utils.dart';
import 'app_lock_store.dart';
import 'timer_action_background.dart';

/// Kennung der Benachrichtigung „App entsperren“ (#485).
const int _unlockHintNotificationId = 9101;

/// Führt eine Timer-Aktion aus, ohne dass die App läuft (#485): im Isolate, das
/// `flutter_local_notifications` für eine Notification-Aktion ohne Oberfläche
/// startet.
///
/// Ablauf: Plugins und Einstellungen laden, bei aktiver App-Sperre nur merken
/// und zum Entsperren auffordern (die Sperre wird nie umgangen), sonst
/// Firebase starten, den ersten Auth-Wert abwarten (sonst landen Daten
/// eines eingeloggten Nutzers im lokalen Speicher) und die Aktion über das
/// bestehende [DashboardViewModel] ausführen, damit Hybrid-Repositories,
/// Profile, Pausenregeln und Saldo-Logik dieselben sind wie in der App.
Future<TimerActionDispatch> runHeadlessTimerAction(TimerAction action) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final lockStore = await AppLockStore.load(prefs: prefs);
  final locale = prefs.getString('locale') ?? 'de';

  if (lockStore.getBool(AppLockKeys.enabled) == true &&
      lockStore.getString(AppLockKeys.pinHash) != null) {
    await storePendingTimerAction(prefs, action, DateTime.now());
    await _showUnlockHint(lookupAppLocalizations(Locale(locale)));
    return TimerActionDispatch.deferred;
  }

  tz_data.initializeTimeZones();
  await applyTimezone(prefs.getString(timezoneOverridePrefsKey));
  await initializeDateFormatting('de_DE', null);
  await initializeDateFormatting('en_US', null);
  Intl.defaultLocale = locale == 'en' ? 'en_US' : 'de_DE';

  // Wie `main()`: Firebase mit den Optionen starten (App Check allein tut das im
  // Debug-Build nicht, dann scheitert schon `FirebaseAuth.instance`).
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }
  const siteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
  await AppBootstrap.ensureInitializedForEnv(
    webRecaptchaSiteKey: siteKey.isEmpty ? null : siteKey,
  );

  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appLockStoreProvider.overrideWithValue(lockStore),
  ]);
  ProviderSubscription<AsyncValue<Object?>>? authSub;
  try {
    // Erster Auth-Wert: ohne ihn fielen die Repositories auf den lokalen
    // Speicher zurück.
    // `authStateProvider` ist auto-dispose: ohne Listener wird er schon beim ersten
    // `.future`-Read wieder verworfen, bevor der Stream einen Wert liefert.
    authSub = container.listen(authStateProvider, (_, __) {});
    await container
        .read(authStateProvider.future)
        .timeout(const Duration(seconds: 15));
    // Hält das Home-Screen-Widget aktuell, solange der Container lebt.
    container.read(widgetSyncProvider);
    final result = await container
        .read(dashboardViewModelProvider.notifier)
        .performTimerAction(action);
    logger.i('[TimerAction] Hintergrund-Aktion ${timerActionId(action)}: '
        '${result.name}');
    // Das Widget schreibt seinen Snapshot asynchron; kurz warten.
    await Future<void>.delayed(const Duration(seconds: 1));
  } finally {
    authSub?.close();
    container.dispose();
  }
  return TimerActionDispatch.headless;
}

Future<void> _showUnlockHint(AppLocalizations l10n) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@drawable/ic_notification'),
  ));
  await plugin.show(
    _unlockHintNotificationId,
    l10n.notificationReminderTitle,
    l10n.timerActionUnlockHint,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        l10n.notificationChannelReminderName,
        channelDescription: l10n.notificationChannelReminderDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: 'open_dashboard',
  );
}
