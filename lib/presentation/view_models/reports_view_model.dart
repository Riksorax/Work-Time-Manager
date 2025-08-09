import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/work_repository.dart';
import '../state/monthly_report_state.dart';
import '../state/reports_state.dart';
import '../state/weekly_report_state.dart';

// Dummy-Implementierung, um den Provider zu vervollständigen, falls das echte Repository nicht verfügbar ist.
class DummyWorkRepository implements WorkRepository {
  const DummyWorkRepository();

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(
      int year, int month) async {
    return [];
  }

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {}

  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async {
    // Gemäß dem Interface eine leere, aber gültige Entität zurückgeben.
    return WorkEntryEntity(
      id: 'dummy',
      date: date,
      workStart: date,
      workEnd: date,
      breaks: [],
      manualOvertime: Duration.zero,
    );
  }
}

final reportsViewModelProvider =
    StateNotifierProvider<ReportsViewModel, ReportsState>((ref) {
  final workRepository = ref.watch(workRepositoryProvider);
  final settingsRepository = ref.watch(settingsRepositoryProvider);

  // Das ViewModel wird erst mit einem echten Repository erstellt, wenn die Abhängigkeiten bereit sind.
  // Bis dahin wird ein Dummy verwendet, um Abstürze zu vermeiden.
  return ReportsViewModel(
    workRepository,
    settingsRepository,
  );
});

class ReportsViewModel extends StateNotifier<ReportsState> {
  ReportsViewModel(this._workRepository, this._settingsRepository)
      : super(ReportsState.initial()) {
    init();
  }

  final WorkRepository _workRepository;
  final SettingsRepository _settingsRepository;

  // Cache für die Einträge des aktuell angezeigten Monats, um häufige DB-Aufrufe zu vermeiden
  List<WorkEntryEntity> _monthlyEntries = [];

  void init() async {
    final now = DateTime.now();
    // Setze den initialen Zustand, ohne zuerst zu laden
    state = state.copyWith(selectedDay: now, isLoading: true);
    // Löse dann das Laden aus, aber nur, wenn das Repository kein Dummy ist
    if (_workRepository is! DummyWorkRepository) {
      await _loadWorkEntriesForMonth(now.year, now.month);
    }
  }

  void selectDate(DateTime date) {
    final oldDate = state.selectedDay;
    state = state.copyWith(selectedDay: date);
    // Wenn sich Monat/Jahr unterscheiden oder vorher kein Datum ausgewählt war, müssen wir neue Daten laden
    if (oldDate == null || date.month != oldDate.month || date.year != oldDate.year) {
      _loadWorkEntriesForMonth(date.year, date.month);
    } else {
      // Wenn wir im selben Monat sind, berechne die Berichte für den neuen Tag neu
      state = state.copyWith(
        dailyReportState: _calculateDailyReport(date),
        weeklyReportState: _calculateWeeklyReport(date),
        // Der Monatsbericht ändert sich nicht, wenn sich nur der Tag ändert
      );
    }
  }

  void onMonthChanged(DateTime newMonth) {
    selectDate(newMonth);
  }

  Future<void> _loadWorkEntriesForMonth(int year, int month) async {
    state = state.copyWith(isLoading: true);
    try {
      final entries = await _workRepository.getWorkEntriesForMonth(year, month);
      _monthlyEntries = entries;
    } catch (e) {
      print('Fehler beim Laden der Arbeitseinträge: $e');
      _monthlyEntries = []; // Stelle sicher, dass die Liste bei einem Fehler leer ist
    } finally {
      // Dieser Block wird immer ausgeführt, egal ob ein Fehler aufgetreten ist oder nicht.
      state = state.copyWith(
        isLoading: false,
        dailyReportState: _calculateDailyReport(state.selectedDay!),
        weeklyReportState: _calculateWeeklyReport(state.selectedDay!),
        monthlyReportState: _calculateMonthlyReport(),
      );
    }
  }

  DailyReportState _calculateDailyReport(DateTime date) {
    final dayToReport = DateTime(date.year, date.month, date.day);
    final entriesForDay = _monthlyEntries
        .where((entry) =>
            entry.date.year == dayToReport.year &&
            entry.date.month == dayToReport.month &&
            entry.date.day == dayToReport.day)
        .toList();

    final workTime = entriesForDay.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalWorkTime);
    final breakTime = entriesForDay.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalBreakTime);
    final totalTime = workTime - breakTime;
    // Overtime calculation might need more specific logic based on your requirements
    final overtime = Duration.zero;

    return DailyReportState(
      entries: entriesForDay,
      workTime: workTime,
      breakTime: breakTime,
      totalTime: totalTime,
      overtime: overtime,
    );
  }

  WeeklyReportState _calculateWeeklyReport(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final entriesForWeek = _monthlyEntries
        .where((entry) =>
            !entry.date.isBefore(startOfWeek) && !entry.date.isAfter(endOfWeek))
        .toList();

    final totalWorkDuration = entriesForWeek.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.effectiveWorkDuration);

    return WeeklyReportState(
      workDays: entriesForWeek.length,
      totalWorkDuration: totalWorkDuration,
    );
  }

  MonthlyReportState _calculateMonthlyReport() {
    final totalWorkDuration = _monthlyEntries.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalWorkTime);
    final totalBreakDuration = _monthlyEntries.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalBreakTime);
    final totalNetWorkDuration = totalWorkDuration - totalBreakDuration;
    final workDays = _monthlyEntries.length;
    final averageWorkDuration =
        workDays > 0 ? totalNetWorkDuration ~/ workDays : Duration.zero;

    // Overtime calculation for the month, assuming target hours are weekly
    final targetWeeklyHours = _settingsRepository.getTargetWeeklyHours();
    final totalTargetHours = targetWeeklyHours * 4; // Simplification for 4 weeks
    final overtime = totalNetWorkDuration - Duration(hours: totalTargetHours);

    return MonthlyReportState(
      totalWorkDuration: totalWorkDuration,
      totalBreakDuration: totalBreakDuration,
      totalNetWorkDuration: totalNetWorkDuration,
      averageWorkDuration: averageWorkDuration,
      overtime: overtime,
      workDays: workDays,
    );
  }
}