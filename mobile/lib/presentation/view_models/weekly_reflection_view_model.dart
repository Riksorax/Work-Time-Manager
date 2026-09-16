import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../domain/entities/weekly_reflection_entity.dart';
import '../state/weekly_reflection_state.dart';

final weeklyReflectionViewModelProvider =
    NotifierProvider<WeeklyReflectionViewModel, WeeklyReflectionState>(
        WeeklyReflectionViewModel.new);

/// Lädt und speichert die Wochen-Reflexion (siehe #137) für eine bestimmte
/// Kalenderwoche. Setzt ein eingeloggtes Premium-Konto voraus - ist kein
/// Nutzer eingeloggt, bleibt die Reflexion rein lokal im Dialog-State
/// (nicht persistiert), da `weeklyReflectionRepositoryProvider` dann `null`
/// liefert.
class WeeklyReflectionViewModel extends Notifier<WeeklyReflectionState> {
  @override
  WeeklyReflectionState build() {
    ref.watch(core_providers.weeklyReflectionRepositoryProvider);
    return WeeklyReflectionState.initial();
  }

  Future<void> loadReflection(int year, int week) async {
    state = state.copyWith(isLoading: true);

    final repository = ref.read(core_providers.weeklyReflectionRepositoryProvider);
    if (repository == null) {
      state = state.copyWith(
        isLoading: false,
        reflection: WeeklyReflectionEntity(year: year, week: week),
      );
      return;
    }

    try {
      final reflection = await repository.getReflection(year, week);
      state = state.copyWith(
        isLoading: false,
        reflection: reflection ?? WeeklyReflectionEntity(year: year, week: week),
      );
    } catch (e, stackTrace) {
      logger.e('[WeeklyReflectionViewModel] Fehler beim Laden: $e', stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        reflection: WeeklyReflectionEntity(year: year, week: week),
      );
    }
  }

  Future<void> saveReflection({
    required String whatWentWell,
    required String whatWasHard,
  }) async {
    final current = state.reflection;
    if (current == null) return;

    final updated = current.copyWith(
      whatWentWell: whatWentWell,
      whatWasHard: whatWasHard,
      updatedAt: DateTime.now(),
    );

    final repository = ref.read(core_providers.weeklyReflectionRepositoryProvider);
    if (repository == null) {
      state = state.copyWith(reflection: updated);
      return;
    }

    state = state.copyWith(isSaving: true);
    try {
      await repository.saveReflection(updated);
      state = state.copyWith(isSaving: false, reflection: updated);
    } catch (e, stackTrace) {
      logger.e('[WeeklyReflectionViewModel] Fehler beim Speichern: $e', stackTrace: stackTrace);
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }
}
