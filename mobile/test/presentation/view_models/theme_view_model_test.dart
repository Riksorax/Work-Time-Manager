import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/app_theme_mode.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/presentation/view_models/theme_view_model.dart';

import 'theme_view_model_test.mocks.dart';

@GenerateMocks([SettingsRepository])
void main() {
  late MockSettingsRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockSettingsRepository();
    container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(mockRepository)],
    );
  });

  tearDown(() => container.dispose());

  group('ThemeViewModel — Umwandlung AppThemeMode <-> ThemeMode (siehe #293)', () {
    test('build() wandelt den gespeicherten AppThemeMode.dark in ThemeMode.dark um', () {
      when(mockRepository.getThemeMode()).thenReturn(AppThemeMode.dark);

      final state = container.read(themeViewModelProvider);

      expect(state, ThemeMode.dark);
    });

    test('build() wandelt AppThemeMode.system in ThemeMode.system um', () {
      when(mockRepository.getThemeMode()).thenReturn(AppThemeMode.system);

      expect(container.read(themeViewModelProvider), ThemeMode.system);
    });

    test('setTheme(ThemeMode.light) speichert AppThemeMode.light in der Domain-Schicht', () async {
      when(mockRepository.getThemeMode()).thenReturn(AppThemeMode.system);
      when(mockRepository.setThemeMode(any)).thenAnswer((_) async {});

      await container.read(themeViewModelProvider.notifier).setTheme(ThemeMode.light);

      verify(mockRepository.setThemeMode(AppThemeMode.light)).called(1);
      expect(container.read(themeViewModelProvider), ThemeMode.light);
    });

    test('setTheme() macht nichts, wenn der Modus bereits aktiv ist', () async {
      when(mockRepository.getThemeMode()).thenReturn(AppThemeMode.dark);

      // build() liest einmalig; danach nicht mehr erneut aufrufen lassen.
      container.read(themeViewModelProvider);
      await container.read(themeViewModelProvider.notifier).setTheme(ThemeMode.dark);

      verifyNever(mockRepository.setThemeMode(any));
    });
  });
}
