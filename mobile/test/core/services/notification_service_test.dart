import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_work_time/core/services/notification_service.dart';
import 'package:flutter_work_time/domain/utils/overtime_warning_utils.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;

import 'notification_service_test.mocks.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin])
void main() {
  late MockFlutterLocalNotificationsPlugin mockNotificationsPlugin;
  late NotificationService notificationService;
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC')); // Use UTC for stable testing
  });

  setUp(() {
    mockNotificationsPlugin = MockFlutterLocalNotificationsPlugin();
    // Inject mock
    notificationService =
        NotificationService(notificationsPlugin: mockNotificationsPlugin);

    // Stub initialize
    when(mockNotificationsPlugin.initialize(
      any,
      onDidReceiveNotificationResponse:
          anyNamed('onDidReceiveNotificationResponse'),
      onDidReceiveBackgroundNotificationResponse:
          anyNamed('onDidReceiveBackgroundNotificationResponse'),
    )).thenAnswer((_) async => true);

    // Stub cancelAll
    when(mockNotificationsPlugin.cancelAll()).thenAnswer((_) async {});

    // Stub zonedSchedule
    when(mockNotificationsPlugin.zonedSchedule(
      any,
      any,
      any,
      any,
      any,
      androidScheduleMode: anyNamed('androidScheduleMode'),
      matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
      payload: anyNamed('payload'),
    )).thenAnswer((_) async {});
  });

  group('NotificationService', () {
    test('scheduleDailyReminder cancels existing notifications', () async {
      await notificationService.scheduleDailyReminder(
        time: '09:00',
        days: [1],
        checkWorkStart: true,
        checkWorkEnd: false,
        checkBreaks: false,
        l10n: de,
      );

      verify(mockNotificationsPlugin.cancelAll()).called(1);
    });

    test('scheduleDailyReminder schedules notifications for selected days',
        () async {
      // Monday (1) and Wednesday (3)
      final days = [1, 3];

      await notificationService.scheduleDailyReminder(
        time: '09:00',
        days: days,
        checkWorkStart: true,
        checkWorkEnd: false,
        checkBreaks: false,
        l10n: de,
      );

      // Verify zonedSchedule called 2 times
      verify(mockNotificationsPlugin.zonedSchedule(
        any,
        any,
        any,
        any,
        any,
        androidScheduleMode: anyNamed('androidScheduleMode'),
        matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
        payload: anyNamed('payload'),
      )).called(2);
    });

    test('scheduleDailyReminder creates correct body for single check',
        () async {
      await notificationService.scheduleDailyReminder(
        time: '09:00',
        days: [1],
        checkWorkStart: true,
        checkWorkEnd: false,
        checkBreaks: false,
        l10n: de,
      );

      final captured = verify(mockNotificationsPlugin.zonedSchedule(
        any,
        any,
        captureAny, // body
        any,
        any,
        androidScheduleMode: anyNamed('androidScheduleMode'),
        matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
        payload: anyNamed('payload'),
      )).captured;

      expect(captured.single, 'Hast du deinen Arbeitsbeginn eingetragen?');
    });

    test('scheduleDailyReminder creates correct body for multiple checks',
        () async {
      await notificationService.scheduleDailyReminder(
        time: '09:00',
        days: [1],
        checkWorkStart: true,
        checkWorkEnd: true,
        checkBreaks: false,
        l10n: de,
      );

      final captured = verify(mockNotificationsPlugin.zonedSchedule(
        any,
        any,
        captureAny, // body
        any,
        any,
        androidScheduleMode: anyNamed('androidScheduleMode'),
        matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
        payload: anyNamed('payload'),
      )).captured;

      expect(captured.single,
          'Hast du Arbeitsbeginn und Arbeitsende eingetragen?');
    });
    Future<List<dynamic>> scheduleAndCapture({
      required AppLocalizations l10n,
      bool start = false,
      bool end = false,
      bool breaks = false,
    }) async {
      await notificationService.scheduleDailyReminder(
        time: '09:00',
        days: [1],
        checkWorkStart: start,
        checkWorkEnd: end,
        checkBreaks: breaks,
        l10n: l10n,
      );
      return verify(mockNotificationsPlugin.zonedSchedule(
        any,
        captureAny, // title
        captureAny, // body
        any,
        any,
        androidScheduleMode: anyNamed('androidScheduleMode'),
        matchDateTimeComponents: anyNamed('matchDateTimeComponents'),
        payload: anyNamed('payload'),
      )).captured;
    }

    test('Erinnerung auf Deutsch: Pausen mit richtigem Possessivpronomen',
        () async {
      final captured = await scheduleAndCapture(l10n: de, breaks: true);

      expect(captured, [
        'Arbeitszeit-Erinnerung',
        'Hast du deine Pausen eingetragen?',
      ]);
    });

    test('Erinnerung auf Englisch folgt der übergebenen Sprache', () async {
      final captured = await scheduleAndCapture(l10n: en, start: true);

      expect(captured, [
        'Work time reminder',
        'Have you logged your work start?',
      ]);
    });

    test('Erinnerung auf Englisch mit drei Prüfungen', () async {
      final captured = await scheduleAndCapture(
          l10n: en, start: true, end: true, breaks: true);

      expect(captured.last, 'Have you logged work start, work end and breaks?');
    });

    test('Erinnerung ohne aktive Prüfung nutzt den allgemeinen Text', () async {
      final captured = await scheduleAndCapture(l10n: en);

      expect(captured.last, "Don't forget to check your work times!");
    });
    test('Überstunden-Warnung folgt der übergebenen Sprache', () async {
      when(mockNotificationsPlugin.show(any, any, any, any,
              payload: anyNamed('payload')))
          .thenAnswer((_) async {});

      await notificationService.showOvertimeWarning(
        type: OvertimeWarningType.overtime,
        totalOvertime: const Duration(hours: 10),
        l10n: en,
      );
      await notificationService.showOvertimeWarning(
        type: OvertimeWarningType.undertime,
        totalOvertime: const Duration(hours: -5),
        l10n: de,
      );

      final captured = verify(mockNotificationsPlugin.show(
        any,
        captureAny,
        captureAny,
        any,
        payload: anyNamed('payload'),
      )).captured;
      expect(captured, [
        'Overtime warning',
        'Your overtime balance has reached 10.0 hours of overtime.',
        'Minusstunden-Warnung',
        'Dein Gleitzeitkonto liegt bei 5.0 Minusstunden.',
      ]);
    });
  });

  group('nextWeeklyOccurrence (#362)', () {
    late tz.Location berlin;
    setUpAll(() => berlin = tz.getLocation('Europe/Berlin'));

    tz.TZDateTime at(int y, int m, int d, [int h = 10, int min = 0]) =>
        tz.TZDateTime(berlin, y, m, d, h, min);

    void expectAt(tz.TZDateTime r, int y, int m, int d, int offsetHours) {
      expect([r.year, r.month, r.day, r.hour, r.minute], [y, m, d, 8, 0]);
      expect(r.timeZoneOffset, Duration(hours: offsetHours));
    }

    test('Fr 28.03.2025 -> So 30.03.2025 08:00 (Sommerzeit)', () {
      expectAt(nextWeeklyOccurrence(at(2025, 3, 28), 7, 8, 0), 2025, 3, 30, 2);
    });

    test('Sa 29.03.2025 -> Mo 31.03.2025 08:00', () {
      expectAt(nextWeeklyOccurrence(at(2025, 3, 29), 1, 8, 0), 2025, 3, 31, 2);
    });

    test('Mo 24.03.2025 nach 08:00 -> Mo 31.03.2025 08:00', () {
      expectAt(nextWeeklyOccurrence(at(2025, 3, 24), 1, 8, 0), 2025, 3, 31, 2);
    });

    test('Fr 24.10.2025 -> Di 28.10.2025 08:00 (Winterzeit)', () {
      expectAt(
          nextWeeklyOccurrence(at(2025, 10, 24), 2, 8, 0), 2025, 10, 28, 1);
    });

    test('Mo 20.10.2025 nach 08:00 -> Mo 27.10.2025 08:00', () {
      expectAt(
          nextWeeklyOccurrence(at(2025, 10, 20), 1, 8, 0), 2025, 10, 27, 1);
    });

    test('gleicher Wochentag, Zeit noch offen -> heute', () {
      expectAt(
          nextWeeklyOccurrence(at(2025, 6, 2, 7, 0), 1, 8, 0), 2025, 6, 2, 2);
    });

    test('gleicher Wochentag, Zeit vorbei -> +7 Tage', () {
      expectAt(
          nextWeeklyOccurrence(at(2025, 6, 2, 9, 0), 1, 8, 0), 2025, 6, 9, 2);
    });

    test('Jahreswechsel: Mi 31.12.2025 -> Do 01.01.2026', () {
      expectAt(nextWeeklyOccurrence(at(2025, 12, 31), 4, 8, 0), 2026, 1, 1, 1);
    });
  });
}
