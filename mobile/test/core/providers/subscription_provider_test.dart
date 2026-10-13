import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/subscription_provider.dart';
import 'package:flutter_work_time/core/utils/revenuecat_state.dart';

void main() {
  group('ohne konfiguriertes RevenueCat (#454)', () {
    test('customerInfoProvider erreicht das SDK nicht, Premium bleibt false',
        () async {
      expect(revenueCatConfigured, isFalse);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.listen(customerInfoProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      expect(container.read(isPremiumProvider), isFalse);
    });

    test('getSubscriptionManagementUrl liefert null', () async {
      expect(await getSubscriptionManagementUrl(), isNull);
    });
  });

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
