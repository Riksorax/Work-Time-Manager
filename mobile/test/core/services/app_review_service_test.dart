import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/app_review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppReviewService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
        'zählt abgeschlossene Arbeitstage maximal einmal pro Kalendertag und fordert vor dem Schwellwert kein Review an',
        () async {
      final prefs = await SharedPreferences.getInstance();
      var reviewRequestedCount = 0;

      final service = AppReviewService(
        prefs: prefs,
        completedDaysThreshold: 3,
        isAvailable: () async => true,
        requestReview: () async {
          reviewRequestedCount++;
        },
      );

      final day1Morning = DateTime(2026, 3, 10, 16, 0);
      final day1Evening = DateTime(2026, 3, 10, 18, 30);
      final day2 = DateTime(2026, 3, 11, 17, 0);

      final triggered1 = await service
          .recordCompletedWorkDayAndMaybeRequestReview(day1Morning);
      final triggered1Duplicate = await service
          .recordCompletedWorkDayAndMaybeRequestReview(day1Evening);
      final triggered2 =
          await service.recordCompletedWorkDayAndMaybeRequestReview(day2);

      expect(triggered1, isFalse);
      expect(triggered1Duplicate, isFalse);
      expect(triggered2, isFalse);
      expect(service.completedDaysCount, 2);
      expect(reviewRequestedCount, 0);
      expect(service.hasShownReviewPrompt, isFalse);
    });

    test(
        'fordert beim Erreichen des Schwellwerts genau einmalig das In-App-Review an',
        () async {
      final prefs = await SharedPreferences.getInstance();
      var reviewRequestedCount = 0;

      final service = AppReviewService(
        prefs: prefs,
        completedDaysThreshold: 3,
        isAvailable: () async => true,
        requestReview: () async {
          reviewRequestedCount++;
        },
      );

      await service
          .recordCompletedWorkDayAndMaybeRequestReview(DateTime(2026, 3, 10));
      await service
          .recordCompletedWorkDayAndMaybeRequestReview(DateTime(2026, 3, 11));
      final triggeredOnThirdDay = await service
          .recordCompletedWorkDayAndMaybeRequestReview(DateTime(2026, 3, 12));
      final triggeredOnFourthDay = await service
          .recordCompletedWorkDayAndMaybeRequestReview(DateTime(2026, 3, 13));

      expect(triggeredOnThirdDay, isTrue);
      expect(triggeredOnFourthDay, isFalse);
      expect(service.completedDaysCount, 4);
      expect(service.hasShownReviewPrompt, isTrue);
      expect(reviewRequestedCount, 1);
    });

    test(
        'setzt das Flag nicht, wenn InAppReview auf dem Gerät noch nicht verfügbar ist',
        () async {
      final prefs = await SharedPreferences.getInstance();
      var available = false;
      var reviewRequestedCount = 0;

      final service = AppReviewService(
        prefs: prefs,
        completedDaysThreshold: 1,
        isAvailable: () async => available,
        requestReview: () async {
          reviewRequestedCount++;
        },
      );

      final firstAttempt = await service
          .recordCompletedWorkDayAndMaybeRequestReview(DateTime(2026, 3, 10));
      expect(firstAttempt, isFalse);
      expect(service.hasShownReviewPrompt, isFalse);
      expect(reviewRequestedCount, 0);

      available = true;
      final secondAttempt = await service
          .recordCompletedWorkDayAndMaybeRequestReview(DateTime(2026, 3, 11));
      expect(secondAttempt, isTrue);
      expect(service.hasShownReviewPrompt, isTrue);
      expect(reviewRequestedCount, 1);
    });

    test('openStoreListing ruft den konfigurierten Callback auf', () async {
      final prefs = await SharedPreferences.getInstance();
      var storeOpened = false;

      final service = AppReviewService(
        prefs: prefs,
        openStoreListing: () async {
          storeOpened = true;
        },
      );

      await service.openStoreListing();
      expect(storeOpened, isTrue);
    });
  });
}
