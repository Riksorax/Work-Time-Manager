// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Zähler, der nach einem Firestore-Sync mit geänderten Einstellungen erhöht
/// wird (siehe #279). Das `SettingsViewModel` beobachtet ihn und lädt sich
/// neu, ohne dass `settingsRepositoryProvider` neu gebaut werden muss.

@ProviderFor(SettingsSyncTick)
const settingsSyncTickProvider = SettingsSyncTickProvider._();

/// Zähler, der nach einem Firestore-Sync mit geänderten Einstellungen erhöht
/// wird (siehe #279). Das `SettingsViewModel` beobachtet ihn und lädt sich
/// neu, ohne dass `settingsRepositoryProvider` neu gebaut werden muss.
final class SettingsSyncTickProvider
    extends $NotifierProvider<SettingsSyncTick, int> {
  /// Zähler, der nach einem Firestore-Sync mit geänderten Einstellungen erhöht
  /// wird (siehe #279). Das `SettingsViewModel` beobachtet ihn und lädt sich
  /// neu, ohne dass `settingsRepositoryProvider` neu gebaut werden muss.
  const SettingsSyncTickProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'settingsSyncTickProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$settingsSyncTickHash();

  @$internal
  @override
  SettingsSyncTick create() => SettingsSyncTick();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$settingsSyncTickHash() => r'acaa46a71a4f5b081279cfe3bcd80ed516394e22';

/// Zähler, der nach einem Firestore-Sync mit geänderten Einstellungen erhöht
/// wird (siehe #279). Das `SettingsViewModel` beobachtet ihn und lädt sich
/// neu, ohne dass `settingsRepositoryProvider` neu gebaut werden muss.

abstract class _$SettingsSyncTick extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element = ref.element
        as $ClassProviderElement<AnyNotifier<int, int>, int, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
