import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_sync_provider.g.dart';

/// Zähler, der nach einem Firestore-Sync mit geänderten Einstellungen erhöht
/// wird (siehe #279). Das `SettingsViewModel` beobachtet ihn und lädt sich
/// neu, ohne dass `settingsRepositoryProvider` neu gebaut werden muss.
@Riverpod(keepAlive: true)
class SettingsSyncTick extends _$SettingsSyncTick {
  @override
  int build() => 0;

  void bump() => state++;
}
