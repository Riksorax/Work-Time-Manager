import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_work_time/core/utils/logger.dart';

import 'work_entry_checker_service.dart';
import '../../domain/repositories/work_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Function(String)? _onNotificationTapCallback;

  Future<void> initialize({Function(String)? onNotificationTap}) async {
    if (_initialized) return;

    _onNotificationTapCallback = onNotificationTap;

    // Initialize timezone
    tz.initializeTimeZones();

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

  /// Prüft und sendet intelligente Benachrichtigungen basierend auf fehlenden Einträgen
  Future<void> checkAndNotify({
    required WorkRepository workRepository,
    required bool notifyWorkStart,
    required bool notifyWorkEnd,
    required bool notifyBreaks,
  }) async {
    final checker = WorkEntryCheckerService(workRepository);
    final missing = await checker.checkMissingEntries();

    if (!missing.hasMissingEntries) {
      logger.i('[NotificationService] Keine fehlenden Einträge, keine Benachrichtigung gesendet');
      return;
    }

    // Filtere basierend auf Einstellungen
    final typesToNotify = <String>[];
    if (notifyWorkStart && missing.missingWorkStart) typesToNotify.add('Arbeitsbeginn');
    if (notifyWorkEnd && missing.missingWorkEnd) typesToNotify.add('Arbeitsende');
    if (notifyBreaks && missing.missingBreaks) typesToNotify.add('Pausen');

    if (typesToNotify.isEmpty) {
      logger.i('[NotificationService] Fehlende Einträge, aber nicht für aktivierte Typen');
      return;
    }

    String body;
    if (typesToNotify.length == 1) {
      body = 'Bitte tragen Sie Ihren ${typesToNotify[0]} ein!';
    } else {
      final last = typesToNotify.removeLast();
      body = 'Bitte tragen Sie ${typesToNotify.join(", ")} und $last ein!';
    }

    await showImmediateNotification(
      title: 'Arbeitszeit-Erinnerung',
      body: body,
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
