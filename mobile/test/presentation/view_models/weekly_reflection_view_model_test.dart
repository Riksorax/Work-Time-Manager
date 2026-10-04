import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/weekly_reflection_entity.dart';
import 'package:flutter_work_time/domain/repositories/weekly_reflection_repository.dart';
import 'package:flutter_work_time/presentation/view_models/weekly_reflection_view_model.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'weekly_reflection_view_model_test.mocks.dart';

@GenerateMocks([WeeklyReflectionRepository])
void main() {
  late MockWeeklyReflectionRepository mockRepository;

  setUp(() {
    mockRepository = MockWeeklyReflectionRepository();
    when(mockRepository.getReflection(any, any)).thenAnswer((_) async => null);
    when(mockRepository.saveReflection(any)).thenAnswer((_) async {});
  });

  ProviderContainer createContainer(WeeklyReflectionRepository? repository) {
    final container = ProviderContainer(overrides: [
      weeklyReflectionRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('loadReflection berechnet den Schlüssel aus dem ISO-Wochenjahr (#354)',
      () {
    for (final (monday, year, week, id) in [
      (DateTime(2025, 12, 29), 2026, 1, '2026-W01'),
      (DateTime(2024, 12, 30), 2025, 1, '2025-W01'),
      (DateTime(2024, 1, 1), 2024, 1, '2024-W01'),
      (DateTime(2026, 3, 9), 2026, 11, '2026-W11'),
      (DateTime(2026, 12, 28), 2026, 53, '2026-W53'),
      // #387 Regression (bewusst gruen): Jahreswechsel 2026/2027.
      (DateTime(2027, 1, 4), 2027, 1, '2027-W01'),
    ]) {
      test('Montag $monday -> $id', () async {
        final container = createContainer(mockRepository);

        await container
            .read(weeklyReflectionViewModelProvider.notifier)
            .loadReflection(monday);

        verify(mockRepository.getReflection(year, week)).called(1);
        expect(container.read(weeklyReflectionViewModelProvider).reflection!.id,
            id);
      });
    }

    test('Silvesterwoche 2026-W53 und Folgewoche 2027-W01 getrennt (#387)',
        () async {
      final container = createContainer(mockRepository);
      final notifier =
          container.read(weeklyReflectionViewModelProvider.notifier);

      await notifier.loadReflection(DateTime(2026, 12, 28));
      verify(mockRepository.getReflection(2026, 53)).called(1);
      await notifier.loadReflection(DateTime(2027, 1, 4));
      verify(mockRepository.getReflection(2027, 1)).called(1);
      verifyNever(mockRepository.getReflection(2027, 53));
    });

    test('Kollisionswochen bekommen getrennte Schlüssel', () async {
      final container = createContainer(mockRepository);
      final notifier =
          container.read(weeklyReflectionViewModelProvider.notifier);

      await notifier.loadReflection(DateTime(2024, 1, 1));
      final first =
          container.read(weeklyReflectionViewModelProvider).reflection!.id;
      await notifier.loadReflection(DateTime(2024, 12, 30));
      final second =
          container.read(weeklyReflectionViewModelProvider).reflection!.id;

      expect(first, '2024-W01');
      expect(second, '2025-W01');
      expect(first, isNot(second));
    });

    test('Repository liefert null -> leere Reflexion mit ISO-Schlüssel',
        () async {
      final container = createContainer(mockRepository);

      await container
          .read(weeklyReflectionViewModelProvider.notifier)
          .loadReflection(DateTime(2025, 12, 29));

      final reflection =
          container.read(weeklyReflectionViewModelProvider).reflection!;
      expect(reflection.id, '2026-W01');
      expect(reflection.isEmpty, isTrue);
    });

    test('Repository wirft -> leere Reflexion mit ISO-Schlüssel', () async {
      when(mockRepository.getReflection(any, any)).thenThrow(Exception('boom'));
      final container = createContainer(mockRepository);

      await container
          .read(weeklyReflectionViewModelProvider.notifier)
          .loadReflection(DateTime(2025, 12, 29));

      final state = container.read(weeklyReflectionViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.reflection!.id, '2026-W01');
    });

    test('Ausgeloggt (Repository null) -> ISO-Schlüssel ohne Repository-Aufruf',
        () async {
      final container = createContainer(null);

      await container
          .read(weeklyReflectionViewModelProvider.notifier)
          .loadReflection(DateTime(2025, 12, 29));

      expect(container.read(weeklyReflectionViewModelProvider).reflection!.id,
          '2026-W01');
      verifyZeroInteractions(mockRepository);
    });

    test('saveReflection speichert unter dem ISO-Schlüssel', () async {
      final container = createContainer(mockRepository);
      final notifier =
          container.read(weeklyReflectionViewModelProvider.notifier);

      await notifier.loadReflection(DateTime(2025, 12, 29));
      await notifier.saveReflection(whatWentWell: 'a', whatWasHard: 'b');

      final saved = verify(mockRepository.saveReflection(captureAny))
          .captured
          .single as WeeklyReflectionEntity;
      expect(saved.id, '2026-W01');
      expect(saved.whatWentWell, 'a');
    });
  });
}
