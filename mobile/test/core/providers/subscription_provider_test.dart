import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';

void main() {
  group('maxWorkProfileCountProvider', () {
    test('liefert 1 ohne Premium (siehe #240)', () {
      final container = ProviderContainer(overrides: [
        isPremiumProvider.overrideWithValue(false),
      ]);
      addTearDown(container.dispose);

      expect(container.read(maxWorkProfileCountProvider), 1);
    });

    test('liefert 2 mit Premium (siehe #240)', () {
      final container = ProviderContainer(overrides: [
        isPremiumProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);

      expect(container.read(maxWorkProfileCountProvider), 2);
    });
  });
}
