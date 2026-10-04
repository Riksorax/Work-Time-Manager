import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/app_lock_lockout.dart';

void main() {
  group('lockoutDurationFor', () {
    test('freie Versuche', () {
      for (final n in [-3, 0, 1, 2]) {
        expect(lockoutDurationFor(n), Duration.zero);
      }
    });

    test('Stufen', () {
      expect(lockoutDurationFor(3), const Duration(seconds: 5));
      expect(lockoutDurationFor(4), const Duration(seconds: 5));
      expect(lockoutDurationFor(5), const Duration(seconds: 30));
      expect(lockoutDurationFor(6), const Duration(seconds: 30));
    });

    test('Deckel bei 300 s', () {
      for (final n in [7, 8, 50]) {
        expect(lockoutDurationFor(n), const Duration(seconds: 300));
      }
    });
  });

  group('formatLockoutCountdown', () {
    test('formatiert mm:ss', () {
      expect(formatLockoutCountdown(Duration.zero), '00:00');
      expect(formatLockoutCountdown(const Duration(seconds: 5)), '00:05');
      expect(formatLockoutCountdown(const Duration(seconds: 65)), '01:05');
      expect(formatLockoutCountdown(const Duration(seconds: 300)), '05:00');
    });

    test('rundet Sekundenbruchteile auf', () {
      expect(
          formatLockoutCountdown(const Duration(milliseconds: 4200)), '00:05');
    });
  });

  test('AttemptResult-Varianten tragen remaining', () {
    const wrong = AttemptWrong(Duration(seconds: 5));
    const locked = AttemptLocked(Duration(seconds: 30));
    expect(wrong.remaining, const Duration(seconds: 5));
    expect(locked.remaining, const Duration(seconds: 30));
    expect(const AttemptSuccess(), isA<AttemptResult>());
  });
}
