import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../domain/utils/yearly_report_utils.dart';
import '../state/yearly_report_state.dart';

final yearlyReportViewModelProvider =
    NotifierProvider<YearlyReportViewModel, YearlyReportState>(
        YearlyReportViewModel.new);

/// Lädt und berechnet den Jahresbericht (siehe #136).
///
/// Nutzt bewusst die bestehende `WorkRepository.getWorkEntriesForMonth`
/// (12 parallele Aufrufe statt einer neuen Repository-Methode über alle
/// vier Implementierungsschichten hinweg) und verfeinert die Überstunden
/// pro Monat anschließend optional mit den serverseitig berechneten Werten
/// (`ApiClient.getMonthlyReport`) — analog zum bestehenden Muster in
/// `ReportsViewModel._loadReportsFromApi`. Schlägt ein API-Aufruf fehl
/// (offline/401), bleibt der lokal berechnete Wert für diesen Monat stehen.
class YearlyReportViewModel extends Notifier<YearlyReportState> {
  @override
  YearlyReportState build() {
    ref.watch(core_providers.workRepositoryProvider);
    return YearlyReportState.initial();
  }

  Future<void> loadYear(int year) async {
    state = state.copyWith(isLoading: true, year: year);

    final workRepository = ref.read(core_providers.workRepositoryProvider);
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    final workdaysPerWeek = settingsRepository.getWorkdaysPerWeek();
    final targetWeeklyHours = settingsRepository.getTargetWeeklyHours();

    List<MonthSummary> months;
    try {
      final entriesPerMonth = await Future.wait(
        List.generate(12, (i) => workRepository.getWorkEntriesForMonth(year, i + 1)),
      );
      months = List.generate(12, (i) {
        return calculateMonthSummary(
          month: i + 1,
          entriesForMonth: entriesPerMonth[i],
          workdaysPerWeek: workdaysPerWeek,
          targetWeeklyHours: targetWeeklyHours,
        );
      });
    } catch (e, stackTrace) {
      logger.e('[YearlyReportViewModel] Fehler beim Laden des Jahres $year: $e',
          stackTrace: stackTrace);
      months = List.generate(12, (i) => MonthSummary.empty(i + 1));
    }

    state = state.copyWith(isLoading: false, months: months);

    // Überstunden nachträglich mit der serverseitig berechneten (korrekten)
    // Logik verfeinern — best effort, nicht blockierend.
    unawaited(_refineOvertimeFromApi(year));
  }

  Future<void> _refineOvertimeFromApi(int year) async {
    final api = ref.read(core_providers.apiClientProvider);
    final refined = List<MonthSummary?>.filled(12, null);

    await Future.wait(List.generate(12, (i) async {
      final month = i + 1;
      try {
        final json = await api.getMonthlyReport(year, month);
        final overtimeMs = (json['monthlyOvertimeMs'] as num?)?.toInt() ?? 0;
        refined[i] = state.months[i].copyWith(overtime: Duration(milliseconds: overtimeMs));
      } catch (e) {
        logger.d('[YearlyReportViewModel] API-Monatsbericht $year-$month nicht verfügbar: $e');
      }
    }));

    // Nur übernehmen, wenn wir noch immer im selben Jahr sind (kein Race
    // mit einem zwischenzeitlichen Jahreswechsel).
    if (state.year != year) return;

    final updatedMonths = List.generate(
      12,
      (i) => refined[i] ?? state.months[i],
    );
    state = state.copyWith(months: updatedMonths);
  }
}
