import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_work_time/core/services/notification_service.dart';

import 'notification_service_test.mocks.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin])
void main() {
  late MockFlutterLocalNotificationsPlugin mockNotificationsPlugin;
  late NotificationService notificationService;

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC')); // Use UTC for stable testing
  });

  setUp(() {
    mockNotificationsPlugin = MockFlutterLocalNotificationsPlugin();
    // Inject mock
    notificationService = NotificationService(notificationsPlugin: mockNotificationsPlugin);
    
    // Stub initialize
    when(mockNotificationsPlugin.initialize(
      any,
      onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      onDidReceiveBackgroundNotificationResponse: anyNamed('onDidReceiveBackgroundNotificationResponse'),
    )).thenAnswer((_) async => true);

    // Stub cancelAll
    when(mockNotificationsPlugin.cancelAll()).thenAnswer((_) async {});
    
    // Stub zonedSchedule
    when(mockNotificationsPlugin.zonedSchedule(
      any, any, any, any, any,
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
      );

      verify(mockNotificationsPlugin.cancelAll()).called(1);
    });

    test('scheduleDailyReminder schedules notifications for selected days', () async {
      // Monday (1) and Wednesday (3)
      final days = [1, 3];
      
      await notificationService.scheduleDailyReminder(
        time: '09:00',
        days: days,
        checkWorkStart: true,
        checkWorkEnd: false,
        checkBreaks: false,
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

    test('scheduleDailyReminder creates correct body for single check', () async {
      await notificationService.scheduleDailyReminder(
        time: '09:00',
        days: [1],
        checkWorkStart: true,
        checkWorkEnd: false,
        checkBreaks: false,
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

      expect(captured.single, 'Haben Sie Ihren Arbeitsbeginn eingetragen?');
    });

    test('scheduleDailyReminder creates correct body for multiple checks', () async {
      await notificationService.scheduleDailyReminder(
        time: '09:00',
        days: [1],
        checkWorkStart: true,
        checkWorkEnd: true,
        checkBreaks: false,
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

      expect(captured.single, 'Haben Sie Arbeitsbeginn und Arbeitsende eingetragen?');
    });
  });
}
