import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/entities/app_theme_mode.dart';

final themeViewModelProvider =
    NotifierProvider<ThemeViewModel, ThemeMode>(ThemeViewModel.new);

/// Wandelt zwischen der Domain-Repräsentation [AppThemeMode] (siehe #293)
/// und Flutters `ThemeMode`, den `MaterialApp` erwartet. Diese Umwandlung
/// gehört bewusst hierher (Presentation-Layer) und nicht in die Domain.
AppThemeMode _toDomain(ThemeMode mode) => switch (mode) {
      ThemeMode.system => AppThemeMode.system,
      ThemeMode.light => AppThemeMode.light,
      ThemeMode.dark => AppThemeMode.dark,
    };

ThemeMode _toFlutter(AppThemeMode mode) => switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

class ThemeViewModel extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Lade den initialen Theme-Modus beim Start.
    final getThemeMode = ref.watch(getThemeModeUseCaseProvider);
    return _toFlutter(
        getThemeMode()); // Annahme: getThemeMode ist jetzt synchron
  }

  /// Ändert den Theme-Modus und speichert ihn.
  Future<void> setTheme(ThemeMode newMode) async {
    if (state == newMode) return;

    final setThemeMode = ref.read(setThemeModeUseCaseProvider);
    await setThemeMode(_toDomain(newMode));
    state = newMode;
  }
}
