import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../domain/utils/insights_utils.dart';
import '../state/insights_state.dart';

final insightsViewModelProvider =
    NotifierProvider<InsightsViewModel, InsightsState>(InsightsViewModel.new);

/// Lädt und berechnet die Arbeitszeit-Insights (siehe #134): Wochentags-
/// Analyse, Burnout-Indikator und Produktivitäts-Heatmap.
///
/// Datenbasis sind die letzten [_monthCount] Kalendermonate (inkl. aktuellem
/// Monat) - analog zu `YearlyReportViewModel` per `Future.wait` über die
/// bestehende `WorkRepository.getWorkEntriesForMonth`, statt einer neuen
/// Repository-Methode über alle Implementierungsschichten hinweg.
class InsightsViewModel extends Notifier<InsightsState> {
  static const int _monthCount = 3;
  static const int _burnoutWarningThresholdDays = 5;

  @override
  InsightsState build() {
    ref.watch(core_providers.workRepositoryProvider);
    return InsightsState.initial();
  }

  Future<void> loadInsights() async {
    state = state.copyWith(isLoading: true);

    final workRepository = ref.read(core_providers.workRepositoryProvider);
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    final workdays = settingsRepository.getWorkdays();
    final targetWeeklyHours = settingsRepository.getTargetWeeklyHours();
    final dailyTarget = workdays.isEmpty
        ? Duration.zero
        : Duration(minutes: (targetWeeklyHours / workdays.length * 60).round());

    final now = DateTime.now();
    final months = List.generate(_monthCount, (i) {
      final date = DateTime(now.year, now.month - i, 1);
      return (year: date.year, month: date.month);
    });

    try {
      final entriesPerMonth = await Future.wait(
        months.map((m) => workRepository.getWorkEntriesForMonth(m.year, m.month)),
      );
      final entries = entriesPerMonth.expand((e) => e).toList();

      state = state.copyWith(
        isLoading: false,
        weekdayAverages: calculateWeekdayAverages(entries),
        burnoutStatus: detectOvertimeStreak(
          entries: entries,
          workdays: workdays,
          dailyTarget: dailyTarget,
          warningThresholdDays: _burnoutWarningThresholdDays,
        ),
        heatmap: buildStartTimeHeatmap(entries: entries, dailyTarget: dailyTarget),
      );
    } catch (e, stackTrace) {
      logger.e('[InsightsViewModel] Fehler beim Laden der Insights: $e', stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, weekdayAverages: [], heatmap: []);
    }
  }
}
