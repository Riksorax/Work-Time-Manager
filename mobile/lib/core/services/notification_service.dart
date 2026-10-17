import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/domain/utils/overtime_warning_utils.dart';
import 'package:flutter_work_time/domain/utils/timer_action.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';

/// Nächster Zeitpunkt ab [now] (Wochentag [day], 1 = Montag ... 7 = Sonntag,
/// Uhrzeit [hour]:[minute]) in der Zeitzone von [now].
///
/// Kalenderarithmetik statt `add(Duration(days: n))`: bleibt über
/// Zeitumstellungen hinweg auf der gewünschten Wandzeit (#362).
tz.TZDateTime nextWeeklyOccurrence(
    tz.TZDateTime now, int day, int hour, int minute) {
  final delta = (day - now.weekday + 7) % 7;
  var scheduled = tz.TZDateTime(
      now.location, now.year, now.month, now.day + delta, hour, minute);
  // Zeit heute schon vorbei: nächste Woche (7 Kalendertage).
  if (scheduled.isBefore(now)) {
    scheduled = tz.TZDateTime(
        now.location, now.year, now.month, now.day + delta + 7, hour, minute);
  }
  return scheduled;
}

/// Timer-Aktion, mit der die App aus einer Notification-Action kalt gestartet
/// wurde (#274), sonst `null`. Das Plugin ruft den Response-Callback beim
/// Kaltstart nicht auf; die Antwort steckt in den Start-Details.
TimerAction? timerActionFromLaunchDetails(NotificationAppLaunchDetails? d) {
  if (d == null || !d.didNotificationLaunchApp) return null;
  return timerActionFromId(d.notificationResponse?.actionId);
}

/// Buttons einer Erinnerung (#274): „Einstempeln“ beim Start-Check,
/// „Ausstempeln“ beim Ende-Check, in dieser Reihenfolge. Pausen-only ohne
/// Button. Die App öffnet sich (kein Headless), die Notification wird
/// geschlossen.
List<AndroidNotificationAction> reminderTimerActions({
  required bool checkWorkStart,
  required bool checkWorkEnd,
  required AppLocalizations l10n,
}) =>
    [
      if (checkWorkStart)
        AndroidNotificationAction(
          timerStartActionId,
          l10n.timerActionStart,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      if (checkWorkEnd)
        AndroidNotificationAction(
          timerStopActionId,
          l10n.timerActionStop,
          showsUserInterface: true,
          cancelNotification: true,
        ),
    ];

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  // Allow injection for testing
  factory NotificationService(
      {FlutterLocalNotificationsPlugin? notificationsPlugin}) {
    if (notificationsPlugin != null) {
      _instance._notifications = notificationsPlugin;
    }
    return _instance;
  }

  NotificationService._internal();

  FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Function(String)? _onNotificationTapCallback;
  void Function(TimerAction)? _onTimerActionCallback;

  /// Setzt den Initialisierungszustand zurück (nur Tests: das Singleton
  /// behält sonst Callbacks und `_initialized` über Testfälle hinweg).
  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    _onNotificationTapCallback = null;
    _onTimerActionCallback = null;
  }

  Future<void> initialize({
    Function(String)? onNotificationTap,
    void Function(TimerAction)? onTimerAction,
  }) async {
    if (_initialized) return;

    _onNotificationTapCallback = onNotificationTap;
    _onTimerActionCallback = onTimerAction;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      // Button der Notification (#274): nie als normaler Tap behandeln.
      final action = timerActionFromId(actionId);
      if (action == null) {
        logger
            .w('[NotificationService] Unbekannte Action ignoriert: $actionId');
        return;
      }
      logger.i('[NotificationService] Timer-Action: $actionId');
      _onTimerActionCallback?.call(action);
      return;
    }
    logger.i('[NotificationService] Notification tapped: ${response.payload}');
    if (_onNotificationTapCallback != null && response.payload != null) {
      _onNotificationTapCallback!(response.payload!);
    }
  }

  Future<void> scheduleDailyReminder({
    required String time, // Format: "HH:mm"
    required List<int> days, // 1 = Monday, 7 = Sunday
    required bool checkWorkStart,
    required bool checkWorkEnd,
    required bool checkBreaks,
    required AppLocalizations l10n,
  }) async {
    await initialize();

    // Cancel all existing notifications
    await _notifications.cancelAll();

    if (days.isEmpty) return;

    // Parse time
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    // Schedule notification for each selected day
    for (final day in days) {
      await _scheduleWeeklyNotification(
        id: day,
        day: day,
        hour: hour,
        minute: minute,
        checkWorkStart: checkWorkStart,
        checkWorkEnd: checkWorkEnd,
        checkBreaks: checkBreaks,
        l10n: l10n,
      );
    }
  }

  /// Sendet sofort eine Test-Benachrichtigung (für Debugging)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    required AppLocalizations l10n,
    String? payload,
  }) async {
    await initialize();

    await _notifications.show(
      0,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          l10n.notificationChannelReminderName,
          channelDescription: l10n.notificationChannelReminderDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  /// Sendet eine sofortige Warnung bei Über-/Minusstunden-Schwellwert
  /// (siehe #219). Eigener Channel, damit Nutzer diese Warnungen unabhängig
  /// von den täglichen Erinnerungen stumm schalten können.
  Future<void> showOvertimeWarning({
    required OvertimeWarningType type,
    required Duration totalOvertime,
    required AppLocalizations l10n,
  }) async {
    if (type == OvertimeWarningType.none) return;

    await initialize();

    final hours = (totalOvertime.inMinutes.abs() / 60).toStringAsFixed(1);
    final title = type == OvertimeWarningType.overtime
        ? l10n.notificationOvertimeWarningTitle
        : l10n.notificationUndertimeWarningTitle;
    final body = type == OvertimeWarningType.overtime
        ? l10n.notificationOvertimeWarningBody(hours)
        : l10n.notificationUndertimeWarningBody(hours);

    await _notifications.show(
      1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'overtime_warning',
          l10n.notificationChannelOvertimeName,
          channelDescription: l10n.notificationChannelOvertimeDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'open_dashboard',
    );
  }

  Future<void> _scheduleWeeklyNotification({
    required int id,
    required int day, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
    required bool checkWorkStart,
    required bool checkWorkEnd,
    required bool checkBreaks,
    required AppLocalizations l10n,
  }) async {
    if (day < 1 || day > 7) {
      logger.w('Ungültiger Tag für die Benachrichtigungsplanung: $day');
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = nextWeeklyOccurrence(now, day, hour, minute);

    final checks = <({String item, String single})>[
      if (checkWorkStart)
        (
          item: l10n.notificationItemWorkStart,
          single: l10n.notificationReminderSingleWorkStart
        ),
      if (checkWorkEnd)
        (
          item: l10n.notificationItemWorkEnd,
          single: l10n.notificationReminderSingleWorkEnd
        ),
      if (checkBreaks)
        (
          item: l10n.notificationItemBreaks,
          single: l10n.notificationReminderSingleBreaks
        ),
    ];

    final String body;
    if (checks.isEmpty) {
      body = l10n.notificationReminderGeneric;
    } else if (checks.length == 1) {
      body = checks.single.single;
    } else {
      final items = checks.map((c) => c.item).toList();
      final last = items.removeLast();
      body = l10n.notificationReminderMultiple(items.join(', '), last);
    }

    logger.i(
        'Scheduling notification with id $id for $scheduledDate (Day: $day, Hour: $hour, Minute: $minute)');
    await _notifications.zonedSchedule(
      id,
      l10n.notificationReminderTitle,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          l10n.notificationChannelReminderName,
          channelDescription: l10n.notificationChannelReminderDescription,
          importance: Importance.high,
          priority: Priority.high,
          actions: reminderTimerActions(
            checkWorkStart: checkWorkStart,
            checkWorkEnd: checkWorkEnd,
            l10n: l10n,
          ),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'open_dashboard',
    );
  }

  /// Antwort der Notification, mit der die App kalt gestartet wurde (#274),
  /// falls es eine Timer-Action war. Einmal beim Start nach [initialize] lesen.
  Future<TimerAction?> launchTimerAction() async {
    await initialize();
    try {
      return timerActionFromLaunchDetails(
          await _notifications.getNotificationAppLaunchDetails());
    } catch (e, st) {
      logger.e('[NotificationService] Start-Details nicht lesbar',
          error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> cancelAllNotifications() async {
    await initialize();
    await _notifications.cancelAll();
  }

  Future<bool> requestPermissions() async {
    await initialize();

    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }
}
