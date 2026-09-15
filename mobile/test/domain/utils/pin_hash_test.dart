import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/pin_hash.dart';

void main() {
  group('hashPin', () {
    test('liefert für gleiche PIN und Salt immer denselben Hash', () {
      final hash1 = hashPin('1234', 'fixed-salt');
      final hash2 = hashPin('1234', 'fixed-salt');
      expect(hash1, equals(hash2));
    });

    test('liefert unterschiedliche Hashes für unterschiedliche PINs', () {
      final hash1 = hashPin('1234', 'fixed-salt');
      final hash2 = hashPin('4321', 'fixed-salt');
      expect(hash1, isNot(equals(hash2)));
    });

    test('liefert unterschiedliche Hashes für denselben PIN mit unterschiedlichem Salt', () {
      final hash1 = hashPin('1234', 'salt-a');
      final hash2 = hashPin('1234', 'salt-b');
      expect(hash1, isNot(equals(hash2)));
    });

    test('Hash ist ein 64-stelliger Hex-String (SHA-256)', () {
      final hash = hashPin('1234', 'fixed-salt');
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });
  });

  group('generateSalt', () {
    test('liefert bei jedem Aufruf einen unterschiedlichen Salt', () {
      final salt1 = generateSalt();
      final salt2 = generateSalt();
      expect(salt1, isNot(equals(salt2)));
    });

    test('liefert einen nicht-leeren Salt', () {
      expect(generateSalt().isNotEmpty, isTrue);
    });
  });
}
