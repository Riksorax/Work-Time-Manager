import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/services/break_calculator_service.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/work_repository.dart';
import '../state/monthly_report_state.dart';
import '../state/reports_state.dart';
import '../state/weekly_report_state.dart';
import '../view_models/dashboard_view_model.dart';

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
  final workRepository = ref.watch(core_providers.workRepositoryProvider);
  final settingsRepository = ref.watch(core_providers.settingsRepositoryProvider);

  // Das ViewModel wird erst mit einem echten Repository erstellt, wenn die Abhängigkeiten bereit sind.
  // Bis dahin wird ein Dummy verwendet, um Abstürze zu vermeiden.
  return ReportsViewModel(
    workRepository,
    settingsRepository,
    ref,
  );
});

class ReportsViewModel extends StateNotifier<ReportsState> {
  ReportsViewModel(this._workRepository, this._settingsRepository, this._ref)
      : super(ReportsState.initial()) {
    init();
  }

  final Ref _ref;

  final WorkRepository _workRepository;
  final SettingsRepository _settingsRepository;

  // Cache für die Einträge des aktuell angezeigten Monats, um häufige DB-Aufrufe zu vermeiden
  List<WorkEntryEntity> _monthlyEntries = [];

  Future<void> init() async {
    final now = DateTime.now();
    // Setze den initialen Zustand, ohne zuerst zu laden
    state = state.copyWith(selectedDay: now, isLoading: true);
    // Löse dann das Laden aus, aber nur, wenn das Repository kein Dummy ist
    if (_workRepository is! DummyWorkRepository) {
      await _loadWorkEntriesForMonth(now.year, now.month);
    } else {
      // Bei einem DummyRepository den Ladezustand zurücksetzen und leere Berichte anzeigen
      state = state.copyWith(
        isLoading: false,
        dailyReportState: _calculateDailyReport(now),
        weeklyReportState: _calculateWeeklyReport(now),
        monthlyReportState: _calculateMonthlyReport(),
      );
    }
  }

  void selectDate(DateTime date) {
    final oldDate = state.selectedDay;
    state = state.copyWith(selectedDay: date);
    // Wenn sich Monat/Jahr unterscheiden oder vorher kein Datum ausgewählt war, müssen wir neue Daten laden
    if (oldDate == null || date.month != oldDate.month || date.year != oldDate.year) {
      _loadWorkEntriesForMonth(date.year, date.month);
    } else {
      // Lade immer die aktuellen Daten, um sicherzustellen, dass die Reports die neuesten Änderungen enthalten
      _loadWorkEntriesForMonth(date.year, date.month);
    }
  }

  void onMonthChanged(DateTime newMonth) {
    state = state.copyWith(selectedMonth: newMonth);
    // Explizites Laden der aktuellen Daten für den neuen Monat
    _loadWorkEntriesForMonth(newMonth.year, newMonth.month);
    selectDate(newMonth);
  }

  Future<void> _loadWorkEntriesForMonth(int year, int month) async {
    state = state.copyWith(isLoading: true);
    try {
      // Lade die aktuellen Daten neu vom Repository
      final entries = await _workRepository.getWorkEntriesForMonth(year, month);
      _monthlyEntries = entries;
    } catch (e, stackTrace) {
      print('Fehler beim Laden der Arbeitseinträge: $e');
      print('Stacktrace: $stackTrace');
      _monthlyEntries = []; // Stelle sicher, dass die Liste bei einem Fehler leer ist
    } finally {
      // Dieser Block wird immer ausgeführt, egal ob ein Fehler aufgetreten ist oder nicht.
      final selectedDay = state.selectedDay ?? DateTime.now();
      state = state.copyWith(
        isLoading: false,
        dailyReportState: _calculateDailyReport(selectedDay),
        weeklyReportState: _calculateWeeklyReport(selectedDay),
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

  // Hilfsmethode zur Berechnung der Kalenderwoche
  int _getWeekNumber(DateTime date) {
    // Der 4. Januar ist immer in der ersten Woche
    final firstWeek = DateTime(date.year, 1, 4);
    // Berechne den Wochentag des 4. Januar (1 = Montag, 7 = Sonntag)
    final dayOfWeek = firstWeek.weekday;
    // Berechne den ersten Tag der ersten Woche
    final firstDayOfFirstWeek = firstWeek.subtract(Duration(days: dayOfWeek - 1));
    // Differenz in Tagen berechnen
    final diff = date.difference(firstDayOfFirstWeek).inDays;
    // Kalenderwoche berechnen (diff / 7 + 1)
    return (diff / 7).floor() + 1;
  }

  /// Wendet die automatische Pausenberechnung auf einen Arbeitseintrag an
  WorkEntryEntity applyBreakCalculation(WorkEntryEntity entry) {
    // Wenn Start- und Endzeit vorhanden sind, berechne automatische Pausen
    if (entry.workStart != null && entry.workEnd != null) {
      return BreakCalculatorService.calculateAndApplyBreaks(entry);
    }
    return entry;
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
    final totalBreakDuration = entriesForWeek.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalBreakTime);
    final totalNetWorkDuration = totalWorkDuration - totalBreakDuration;

    // Berechne die durchschnittliche Arbeitszeit pro Tag
    final workDays = entriesForWeek.length;
    final averageWorkDuration = workDays > 0 
        ? Duration(seconds: totalNetWorkDuration.inSeconds ~/ workDays) 
        : Duration.zero;

    // Berechne die Überstunden für die Woche
    final targetDailyHours = Duration(hours: 8); // Aus den Einstellungen holen
    final targetWeeklyHours = Duration(hours: 8 * workDays);
    final overtime = totalNetWorkDuration - targetWeeklyHours;

    // Berücksichtige auch manuelle Überstunden
    final manualOvertimes = entriesForWeek.fold<Duration>(
        Duration.zero, (prev, entry) => prev + (entry.manualOvertime ?? Duration.zero));
    final totalWeeklyOvertime = overtime + manualOvertimes;

    // Tägliche Arbeitszeiten sammeln
    Map<DateTime, Duration> dailyWork = {};
    for (var entry in entriesForWeek) {
      if (entry.workStart != null && entry.workEnd != null) {
        dailyWork[entry.date] = entry.effectiveWorkDuration;
      }
    }

    return WeeklyReportState(
      workDays: workDays,
      totalWorkDuration: totalWorkDuration,
      totalBreakDuration: totalBreakDuration,
      totalNetWorkDuration: totalNetWorkDuration,
      averageWorkDuration: averageWorkDuration,
      overtime: totalWeeklyOvertime, // Jetzt werden die berechneten Überstunden zurückgegeben
      dailyWork: dailyWork,
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

    // Genauere Überstundenberechnung für den Monat basierend auf Arbeitstagen
    final targetDailyHours = _settingsRepository.getTargetWeeklyHours() / 5; // Typischerweise 5 Arbeitstage pro Woche
    final totalTargetHours = (targetDailyHours * workDays).toInt(); // Berücksichtigt tatsächliche Arbeitstage
    final overtime = totalNetWorkDuration - Duration(hours: totalTargetHours);

    // Berücksichtige auch manuelle Überstunden
    final manualOvertimes = _monthlyEntries.fold<Duration>(
        Duration.zero, (prev, entry) => prev + (entry.manualOvertime ?? Duration.zero));
    final calculatedMonthlyOvertime = overtime + manualOvertimes;

    // Hole die gesamten Überstunden (inkl. manuelle Anpassungen) vom Dashboard
    final dashboardState = _ref.read(dashboardViewModelProvider);
    final totalOvertime = dashboardState.totalBalance ?? overtime;

    // Tägliche und wöchentliche Arbeitszeiten berechnen
    final Map<DateTime, Duration> dailyWork = {};
    final Map<int, Duration> weeklyWork = {};

    for (var entry in _monthlyEntries) {
      if (entry.workStart != null && entry.workEnd != null) {
        // Tägliche Arbeitszeit speichern
        dailyWork[entry.date] = entry.effectiveWorkDuration;

        // Kalenderwoche berechnen
        final weekNumber = _getWeekNumber(entry.date);
        weeklyWork[weekNumber] = (weeklyWork[weekNumber] ?? Duration.zero) + entry.effectiveWorkDuration;
      }
    }

    return MonthlyReportState(
      totalWorkDuration: totalWorkDuration,
      totalBreakDuration: totalBreakDuration,
      totalNetWorkDuration: totalNetWorkDuration,
      averageWorkDuration: averageWorkDuration,
      overtime: calculatedMonthlyOvertime, // Verbesserte Überstundenberechnung
      totalOvertime: totalOvertime, // Gesamtüberstunden vom Dashboard
      workDays: workDays,
      dailyWork: dailyWork,
      weeklyWork: weeklyWork,
    );
  }
}