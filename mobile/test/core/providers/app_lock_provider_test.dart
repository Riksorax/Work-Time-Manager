import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/services/app_lock_store.dart';
import 'package:flutter_work_time/domain/utils/app_lock_lockout.dart';

import '../../helpers/app_lock_fakes.dart';

void main() {
  test('appLockServiceProvider nutzt clockProvider für die Sperre', () async {
    final store = AppLockStore.inMemory();
    final clock = FakeClock();

    ProviderContainer create() => ProviderContainer(overrides: [
          appLockStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(clock.call),
        ]);

    final first = create();
    addTearDown(first.dispose);
    final service = first.read(appLockServiceProvider);
    await service.setPin('1234');
    for (var i = 0; i < 3; i++) {
      await service.attemptPin('0000');
    }
    // Sitzungspfad nutzt die echte monotone Uhr (Default), daher nur Grenzen.
    expect(service.remainingLockout,
        lessThanOrEqualTo(const Duration(seconds: 5)));
    expect(service.remainingLockout, greaterThan(const Duration(seconds: 4)));
    expect(await service.attemptPin('1234'), isA<AttemptLocked>());

    // "Neustart": neuer Container, Wanduhrpfad.
    final second = create();
    addTearDown(second.dispose);
    final restarted = second.read(appLockServiceProvider);
    clock.advance(const Duration(seconds: 2));
    expect(await restarted.syncLockout(), const Duration(seconds: 3));
    clock.advance(const Duration(seconds: 3));
    expect(await restarted.syncLockout(), Duration.zero);
  });

  group('isAppLockedProvider (Start-Race, #375)', () {
    ProviderContainer create(AppLockStore? store) {
      final container = ProviderContainer(overrides: [
        if (store != null) appLockStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('mit vorab befülltem Store ist schon der erste Read gesperrt', () {
      final store = AppLockStore.inMemory({
        'app_lock_enabled': 'true',
        'app_lock_pin_hash': 'salt:hash',
      });
      expect(create(store).read(isAppLockedProvider), isTrue);
    });

    test('ohne Override gilt der In-Memory-Default: nicht gesperrt', () {
      expect(create(null).read(isAppLockedProvider), isFalse);
      expect(create(null).read(appLockServiceProvider).hasPin, isFalse);
    });

    test('enabled ohne PIN (Restore-Fall) sperrt nicht', () {
      final store = AppLockStore.inMemory({'app_lock_enabled': 'true'});
      expect(create(store).read(isAppLockedProvider), isFalse);
    });

    test('PIN ohne enabled sperrt nicht', () {
      final store = AppLockStore.inMemory({'app_lock_pin_hash': 'salt:hash'});
      expect(create(store).read(isAppLockedProvider), isFalse);
    });
  });
}
