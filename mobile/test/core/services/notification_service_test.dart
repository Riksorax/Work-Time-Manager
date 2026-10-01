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
}
