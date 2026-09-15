import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/domain/utils/overtime_warning_utils.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  // Allow injection for testing
  factory NotificationService({FlutterLocalNotificationsPlugin? notificationsPlugin}) {
    if (notificationsPlugin != null) {
      _instance._notifications = notificationsPlugin;
    }
    return _instance;
  }
  
  NotificationService._internal();

  FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Function(String)? _onNotificationTapCallback;

  Future<void> initialize({Function(String)? onNotificationTap}) async {
    if (_initialized) return;

    _onNotificationTapCallback = onNotificationTap;

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
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
      );
    }
  }

  /// Sendet sofort eine Test-Benachrichtigung (für Debugging)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    await _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Tägliche Erinnerungen',
          channelDescription: 'Erinnerungen zum Eintragen von Arbeitszeiten',
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
  }) async {
    if (type == OvertimeWarningType.none) return;

    await initialize();

    final hours = (totalOvertime.inMinutes.abs() / 60).toStringAsFixed(1);
    final title = type == OvertimeWarningType.overtime
        ? 'Überstunden-Warnung'
        : 'Minusstunden-Warnung';
    final body = type == OvertimeWarningType.overtime
        ? 'Dein Gleitzeitkonto hat $hours Überstunden erreicht.'
        : 'Dein Gleitzeitkonto liegt bei $hours Minusstunden.';

    await _notifications.show(
      1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'overtime_warning',
          'Gleitzeit-Warnungen',
          channelDescription: 'Warnung bei Über-/Minusstunden-Schwellwert',
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
  }) async {
    if (day < 1 || day > 7) {
      logger.w('Ungültiger Tag für die Benachrichtigungsplanung: $day');
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Adjust to the correct weekday
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // If the time has already passed today, schedule for next week
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    // Build notification message based on what to check
    final checkTypes = <String>[];
    if (checkWorkStart) checkTypes.add('Arbeitsbeginn');
    if (checkWorkEnd) checkTypes.add('Arbeitsende');
    if (checkBreaks) checkTypes.add('Pausen');

    String body;
    if (checkTypes.isEmpty) {
      body = 'Vergessen Sie nicht, Ihre Arbeitszeiten zu prüfen!';
    } else if (checkTypes.length == 1) {
      body = 'Haben Sie Ihren ${checkTypes[0]} eingetragen?';
    } else {
      final last = checkTypes.removeLast();
      body = 'Haben Sie ${checkTypes.join(", ")} und $last eingetragen?';
    }

    logger.i('Scheduling notification with id $id for $scheduledDate (Day: $day, Hour: $hour, Minute: $minute)');
    await _notifications.zonedSchedule(
      id,
      'Arbeitszeit-Erinnerung',
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Tägliche Erinnerungen',
          channelDescription: 'Erinnerungen zum Eintragen von Arbeitszeiten',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'open_dashboard',
    );
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
