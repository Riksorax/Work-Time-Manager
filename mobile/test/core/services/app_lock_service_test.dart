import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/app_lock_service.dart';
import 'package:flutter_work_time/domain/utils/app_lock_lockout.dart';
import 'package:flutter_work_time/domain/utils/pin_hash.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/app_lock_fakes.dart';

void main() {
  late SharedPreferences prefs;
  late AppLockService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = AppLockService(prefs: prefs, localAuth: LocalAuthentication());
  });

  test('setPin/verifyPin', () async {
    await service.setPin('1234');
    expect(service.hasPin, isTrue);
    expect(service.verifyPin('1234'), isTrue);
    expect(service.verifyPin('0000'), isFalse);
  });

  test('Legacy-PIN (Salt in separatem Key) bleibt verifizierbar', () async {
    SharedPreferences.setMockInitialValues({
      'app_lock_pin_salt': 'salt',
      'app_lock_pin_hash': hashPin('1234', 'salt'),
    });
    prefs = await SharedPreferences.getInstance();
    service = AppLockService(prefs: prefs, localAuth: LocalAuthentication());
    expect(service.verifyPin('1234'), isTrue);
    expect(service.verifyPin('0000'), isFalse);
  });

  test('setPin schreibt Salt und Hash atomar in einen Wert', () async {
    await service.setPin('1234');
    expect(prefs.getKeys().where((k) => k.contains('salt')), isEmpty);
  });

  test('clearPin entfernt PIN, lässt isEnabled unverändert', () async {
    await service.setEnabled(true);
    await service.setPin('1234');
    await service.clearPin();
    expect(service.hasPin, isFalse);
    expect(service.verifyPin('1234'), isFalse);
    expect(service.isEnabled, isTrue);
  });

  group('Recovery-Code', () {
    test('setPinWithRecoveryCode speichert PIN und Code', () async {
      await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
      expect(service.hasPin, isTrue);
      expect(service.hasRecoveryCode, isTrue);
      expect(service.verifyPin('1234'), isTrue);
      expect(service.verifyRecoveryCode('ABCDEFGHJKLMNPQR'), isTrue);
      expect(service.verifyRecoveryCode('ABCD-EFGH-JKLM-NPQR'), isTrue);
      expect(service.verifyRecoveryCode('abcd-efgh-jklm-npqr'), isTrue);
      expect(service.verifyRecoveryCode('AAAAAAAAAAAAAAAA'), isFalse);
    });

    test('ohne Code ist verifyRecoveryCode false', () {
      expect(service.hasRecoveryCode, isFalse);
      expect(service.verifyRecoveryCode('ABCDEFGHJKLMNPQR'), isFalse);
    });

    test('kein Klartext in den Prefs', () async {
      await service.setPinWithRecoveryCode('4711', 'ABCDEFGHJKLMNPQR');
      for (final key in prefs.getKeys()) {
        final v = prefs.get(key).toString();
        expect(v.contains('ABCDEFGHJKLMNPQR'), isFalse);
        if (key != 'app_lock_enabled') expect(v, isNot('4711'));
      }
    });

    test('erneutes Setzen ersetzt PIN und macht alten Code ungültig', () async {
      await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
      await service.setPinWithRecoveryCode('9999', 'ZZZZ2222YYYY3333');
      expect(service.verifyPin('1234'), isFalse);
      expect(service.verifyPin('9999'), isTrue);
      expect(service.verifyRecoveryCode('ABCDEFGHJKLMNPQR'), isFalse);
      expect(service.verifyRecoveryCode('ZZZZ2222YYYY3333'), isTrue);
    });

    test('formatierter Code beim Setzen wird normalisiert gespeichert',
        () async {
      await service.setPinWithRecoveryCode('1234', 'abcd-efgh-jklm-npqr');
      expect(service.verifyRecoveryCode('ABCDEFGHJKLMNPQR'), isTrue);
    });

    test('clearPin lässt den Wiederherstellungscode unberührt', () async {
      await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
      await service.clearPin();
      expect(service.hasPin, isFalse);
      expect(service.hasRecoveryCode, isTrue);
      expect(service.verifyRecoveryCode('ABCDEFGHJKLMNPQR'), isTrue);
    });

    test('leere Eingabe ist kein gültiger Code', () async {
      await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
      expect(service.verifyRecoveryCode(''), isFalse);
      expect(service.verifyRecoveryCode('----  '), isFalse);
    });
  });

  group('Brute-Force-Limit', () {
    const failedKey = 'app_lock_failed_attempts';
    const untilKey = 'app_lock_locked_until_ms';
    const lastSeenKey = 'app_lock_last_seen_ms';
    const sec5 = Duration(seconds: 5);
    const sec30 = Duration(seconds: 30);
    const sec300 = Duration(seconds: 300);

    late FakeClock clock;
    late FakeMonotonic mono;

    AppLockService build([SharedPreferences? p]) => AppLockService(
          prefs: p ?? prefs,
          localAuth: LocalAuthentication(),
          now: clock.call,
          monotonic: mono.call,
        );

    setUp(() async {
      clock = FakeClock();
      mono = FakeMonotonic();
      service = build();
      await service.setPinWithRecoveryCode('1234', 'ABCDEFGHJKLMNPQR');
    });

    void wait(Duration d) {
      clock.advance(d);
      mono.advance(d);
    }

    Future<AttemptResult> wrong() => service.attemptPin('0000');

    test('Stufen 2 frei, dann 5 s / 30 s / 300 s mit Deckel', () async {
      expect(((await wrong()) as AttemptWrong).remaining, Duration.zero);
      expect(((await wrong()) as AttemptWrong).remaining, Duration.zero);
      expect(((await wrong()) as AttemptWrong).remaining, sec5);
      wait(sec5);
      expect(((await wrong()) as AttemptWrong).remaining, sec5);
      wait(sec5);
      expect(((await wrong()) as AttemptWrong).remaining, sec30);
      wait(sec30);
      expect(((await wrong()) as AttemptWrong).remaining, sec30);
      wait(sec30);
      expect(((await wrong()) as AttemptWrong).remaining, sec300);
      wait(sec300);
      expect(((await wrong()) as AttemptWrong).remaining, sec300);
      expect(prefs.getInt(failedKey), 8);
    });

    test('während der Sperre wird auch die richtige PIN abgelehnt', () async {
      for (var i = 0; i < 3; i++) {
        await wrong();
      }
      final r = await service.attemptPin('1234');
      expect(r, isA<AttemptLocked>());
      expect((r as AttemptLocked).remaining, sec5);
      expect(prefs.getInt(failedKey), 3);
    });

    test('parallel gestartet: richtige PIN nach der sperrenden wird abgelehnt',
        () async {
      final results = await Future.wait([
        service.attemptPin('0000'),
        service.attemptRecoveryCode('WRONGWRONGWRONG1'),
        service.attemptPin('0000'),
        service.attemptPin('1234'),
      ]);
      expect(results[2], isA<AttemptWrong>());
      expect((results[2] as AttemptWrong).remaining, sec5);
      expect(results[3], isA<AttemptLocked>());
      expect(prefs.getInt(failedKey), 3);
    });

    test('parallele falsche Versuche: Zähler entspricht der Versuchszahl',
        () async {
      final results = await Future.wait([
        for (var i = 0; i < 4; i++) service.attemptPin('0000'),
      ]);
      expect(results.whereType<AttemptWrong>().length, 3);
      expect(results.whereType<AttemptLocked>().length, 1);
      expect(prefs.getInt(failedKey), 3);
      expect(service.remainingLockout, sec5);
    });

    test('richtige PIN nach Ablauf entsperrt und setzt zurück', () async {
      for (var i = 0; i < 3; i++) {
        await wrong();
      }
      wait(sec5);
      expect(await service.attemptPin('1234'), isA<AttemptSuccess>());
      expect(prefs.getInt(failedKey), isNull);
      expect(prefs.getInt(untilKey), isNull);
      expect(service.remainingLockout, Duration.zero);
    });

    test('Zeitablauf allein setzt den Zähler nicht zurück', () async {
      for (var i = 0; i < 3; i++) {
        await wrong();
      }
      wait(sec5);
      await service.syncLockout();
      expect(prefs.getInt(failedKey), 3);
    });

    test('Persist-before-verify: Zähler wird vor dem Hash-Lesen geschrieben',
        () async {
      final rec = RecordingSharedPreferences(prefs);
      final s = build(rec);
      await s.attemptPin('0000');
      final write = rec.log.indexOf('setInt:$failedKey=1');
      final read = rec.log.indexOf('getString:app_lock_pin_hash');
      expect(write, greaterThanOrEqualTo(0));
      expect(read, greaterThan(write));
    });

    test('Hard-Kill beim Verifizieren verliert den Versuch nicht', () async {
      final rec = RecordingSharedPreferences(prefs,
          throwOnGetString: 'app_lock_pin_hash');
      final s = build(rec);
      await expectLater(s.attemptPin('0000'), throwsStateError);
      final restarted = build();
      expect(prefs.getInt(failedKey), 1);
      await restarted.attemptPin('0000');
      await restarted.attemptPin('0000');
      expect(restarted.remainingLockout, sec5);
    });

    test('PIN und Wiederherstellungscode teilen den Zähler', () async {
      await service.attemptPin('0000');
      await service.attemptPin('0000');
      final r = await service.attemptRecoveryCode('WRONGWRONGWRONG1');
      expect((r as AttemptWrong).remaining, sec5);
      expect(await service.attemptRecoveryCode('ABCDEFGHJKLMNPQR'),
          isA<AttemptLocked>());
      expect(await service.attemptPin('1234'), isA<AttemptLocked>());
    });

    test('umgekehrt: Code zuerst, dann PIN', () async {
      await service.attemptRecoveryCode('WRONGWRONGWRONG1');
      await service.attemptRecoveryCode('WRONGWRONGWRONG1');
      expect(((await wrong()) as AttemptWrong).remaining, sec5);
    });

    test('Wiederherstellungscode-Erfolg setzt zurück', () async {
      await wrong();
      expect(await service.attemptRecoveryCode('ABCDEFGHJKLMNPQR'),
          isA<AttemptSuccess>());
      expect(prefs.getInt(failedKey), isNull);
    });

    test('ohne gesetzte PIN zählt der Versuch trotzdem', () async {
      await service.clearPin();
      final r = await service.attemptPin('1234');
      expect(r, isA<AttemptWrong>());
      expect(prefs.getInt(failedKey), 1);
    });

    group('Reset-Punkte', () {
      Future<void> seed() async {
        await prefs.setInt(failedKey, 7);
        await prefs.setInt(untilKey, clock().millisecondsSinceEpoch + 100000);
      }

      void expectReset() {
        expect(prefs.getInt(failedKey), isNull);
        expect(prefs.getInt(untilKey), isNull);
        expect(service.remainingLockout, Duration.zero);
      }

      test('setPinWithRecoveryCode', () async {
        await seed();
        await service.setPinWithRecoveryCode('5555', 'ZZZZ2222YYYY3333');
        expectReset();
      });

      test('setPin', () async {
        await seed();
        await service.setPin('5555');
        expectReset();
      });

      test('clearPin', () async {
        await seed();
        await service.clearPin();
        expectReset();
      });

      test('setEnabled ändert nichts', () async {
        await seed();
        await service.setEnabled(false);
        expect(prefs.getInt(failedKey), 7);
        expect(prefs.getInt(untilKey), isNotNull);
      });

      test('resetAttempts behält lastSeen', () async {
        await wrong();
        final seen = prefs.getInt(lastSeenKey);
        expect(seen, isNotNull);
        await service.resetAttempts();
        expect(prefs.getInt(failedKey), isNull);
        expect(prefs.getInt(lastSeenKey), seen);
      });
    });

    group('Neustart und Uhr', () {
      Future<void> lockWith(int attempts) async {
        for (var i = 0; i < attempts; i++) {
          await wrong();
          // Zwischen den Versuchen ablaufen lassen.
          wait(sec300);
        }
        // Letzte Wartezeit "zurückdrehen": Uhr auf Zeitpunkt des letzten
        // Versuchs setzen, damit die Sperre noch läuft.
        clock.advance(-sec300);
        mono.advance(-sec300);
      }

      test('Neustart während Sperre: Restdauer über die Wanduhr', () async {
        for (var i = 0; i < 3; i++) {
          await wrong();
        }
        final restarted = build();
        expect(await restarted.syncLockout(), sec5);
        clock.advance(const Duration(seconds: 2));
        expect(await restarted.syncLockout(), const Duration(seconds: 3));
        clock.advance(const Duration(seconds: 10));
        expect(await restarted.syncLockout(), Duration.zero);
      });

      test('Session: Wanduhr-Rückstellung beeinflusst die Sperre nicht',
          () async {
        for (var i = 0; i < 3; i++) {
          await wrong();
        }
        clock.advance(const Duration(hours: -1));
        expect(service.remainingLockout, sec5);
        mono.advance(const Duration(seconds: 2));
        expect(service.remainingLockout, const Duration(seconds: 3));
        mono.advance(const Duration(seconds: 3));
        expect(service.remainingLockout, Duration.zero);
      });

      test('Uhr-Rückstellung nach Neustart: volle Stufendauer, kein Re-Lock',
          () async {
        await lockWith(5);
        final t = clock();
        expect(prefs.getInt(failedKey), 5);
        final restarted = build();
        clock.set(t.subtract(const Duration(minutes: 10)));
        expect(await restarted.syncLockout(), sec30);
        expect(prefs.getInt(lastSeenKey),
            t.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch);
        clock.advance(const Duration(seconds: 10));
        expect(await restarted.syncLockout(), const Duration(seconds: 20));
      });

      test('Toleranz: 90 s zurück gilt nicht als Rückstellung', () async {
        for (var i = 0; i < 3; i++) {
          await wrong();
        }
        final restarted = build();
        clock.set(clock().subtract(const Duration(seconds: 90)));
        expect(await restarted.syncLockout(), const Duration(seconds: 95));
      });

      test('Zukunfts-lockedUntil wird auf die Stufendauer begrenzt', () async {
        clock.advance(const Duration(days: 30));
        for (var i = 0; i < 3; i++) {
          await wrong();
        }
        final restarted = build();
        clock.advance(const Duration(days: -30));
        expect(await restarted.syncLockout(), sec5);
      });

      test('Uhr vorwärts lässt die Sperre früher ablaufen (Restrisiko)',
          () async {
        for (var i = 0; i < 3; i++) {
          await wrong();
        }
        final restarted = build();
        clock.advance(const Duration(hours: 1));
        expect(await restarted.syncLockout(), Duration.zero);
      });

      test('UTC und Lokalzeit liefern identische gespeicherte Werte', () async {
        final utc = DateTime.utc(2026, 3, 1, 10);
        final a = AppLockService(
            prefs: prefs,
            localAuth: LocalAuthentication(),
            now: () => utc,
            monotonic: mono.call);
        await a.attemptPin('0000');
        final first = prefs.getInt(lastSeenKey);
        SharedPreferences.setMockInitialValues({});
        final prefs2 = await SharedPreferences.getInstance();
        final b = AppLockService(
            prefs: prefs2,
            localAuth: LocalAuthentication(),
            now: () => utc.toLocal(),
            monotonic: mono.call);
        await b.attemptPin('0000');
        expect(prefs2.getInt(lastSeenKey), first);
      });

      test('fehlende Keys: keine Sperre, kein Fehler', () async {
        SharedPreferences.setMockInitialValues({});
        final fresh = await SharedPreferences.getInstance();
        final s = build(fresh);
        expect(s.remainingLockout, Duration.zero);
        expect(await s.syncLockout(), Duration.zero);
      });
    });
  });
}
