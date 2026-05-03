import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';

final themeViewModelProvider = NotifierProvider<ThemeViewModel, ThemeMode>(ThemeViewModel.new);

class ThemeViewModel extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Lade den initialen Theme-Modus beim Start.
    final getThemeMode = ref.watch(getThemeModeUseCaseProvider);
    return getThemeMode(); // Annahme: getThemeMode ist jetzt synchron
  }

  /// Ändert den Theme-Modus und speichert ihn.
  Future<void> setTheme(ThemeMode newMode) async {
    if (state == newMode) return;

    final setThemeMode = ref.read(setThemeModeUseCaseProvider);
    await setThemeMode(newMode);
    state = newMode;
  }
}