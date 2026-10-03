import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/app_lock_service.dart';
import 'package:flutter_work_time/domain/utils/pin_hash.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
