import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/utils/app_lock_lockout.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/app_lock_fakes.dart';

void main() {
  test('appLockServiceProvider nutzt clockProvider für die Sperre', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final clock = FakeClock();

    ProviderContainer create() => ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
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
}
