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

  @override
  Future<void> deleteWorkEntry(String entryId) async {
    // Im Dummy-Repository passiert nichts
  }
}

final reportsViewModelProvider =
    StateNotifierProvider<ReportsViewModel, ReportsState>((ref) {
  final workRepository = ref.watch(core_providers.workRepositoryProvider);
  final settingsRepository = ref.watch(core_providers.settingsRepositoryProvider);

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

  List<WorkEntryEntity> _monthlyEntries = [];

  Future<void> init() async {
    final now = DateTime.now();
    // Setze den initialen Zustand, inklusive selectedMonth
    state = state.copyWith(
        selectedDay: now,
        selectedMonth: DateTime(now.year, now.month),
        isLoading: true);

    if (_workRepository is! DummyWorkRepository) {
      await _loadWorkEntriesForMonth(now.year, now.month);
    } else {
      // Bei einem DummyRepository leere Einträge verwenden und Reports berechnen
      _monthlyEntries = [];
      _updateCalculatedReports();
    }
  }

  void _updateCalculatedReports() {
    final currentSelectedDay = state.selectedDay ?? DateTime.now();
    state = state.copyWith(
      isLoading: false,
      dailyReportState: _calculateDailyReport(currentSelectedDay),
      weeklyReportState: _calculateWeeklyReport(currentSelectedDay),
      monthlyReportState: _calculateMonthlyReport(),
    );
  }
  
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {
    state = state.copyWith(isLoading: true);
    try {
      await _workRepository.saveWorkEntry(entry);
      final selectedDate = state.selectedDay ?? DateTime.now();
      await _loadWorkEntriesForMonth(selectedDate.year, selectedDate.month);
    } catch (e, stackTrace) {
      print('Fehler beim Speichern des Arbeitseintrags: $e');
      print('Stacktrace: $stackTrace');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> deleteWorkEntry(String entryId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _workRepository.deleteWorkEntry(entryId);
      // Nach dem Löschen die Einträge für den aktuellen Monat neu laden
      final selectedDate = state.selectedDay ?? DateTime.now();
      await _loadWorkEntriesForMonth(selectedDate.year, selectedDate.month);
    } catch (e, stackTrace) {
      print('Fehler beim Löschen des Arbeitseintrags: $e');
      print('Stacktrace: $stackTrace');
      // Setze den Ladezustand zurück und aktualisiere Berichte, auch wenn ein Fehler auftritt
      // _loadWorkEntriesForMonth wird _updateCalculatedReports im finally aufrufen,
      // aber falls hier ein Fehler vorher auftritt:
      state = state.copyWith(isLoading: false);
      // Es könnte sinnvoll sein, _updateCalculatedReports() hier aufzurufen, um sicherzustellen,
      // dass der State konsistent ist, falls _loadWorkEntriesForMonth nicht erreicht wird.
      // Da _loadWorkEntriesForMonth jedoch im Erfolgsfall aufgerufen wird und dessen finally
      // _updateCalculatedReports ausführt, sollte der Ladezustand korrekt gehandhabt werden.
      // Für den Fall, dass deleteWorkEntry selbst fehlschlägt, ist isLoading: false hier wichtig.
    }
  }

  void selectDate(DateTime date) {
    final oldSelectedDay = state.selectedDay;
    state = state.copyWith(selectedDay: date); // Update selectedDay sofort

    if (oldSelectedDay == null ||
        date.month != oldSelectedDay.month ||
        date.year != oldSelectedDay.year) {
      // Monat oder Jahr hat sich geändert, oder es war vorher kein Datum ausgewählt.
      // selectedMonth ebenfalls aktualisieren für Konsistenz.
      state = state.copyWith(selectedMonth: DateTime(date.year, date.month));
      _loadWorkEntriesForMonth(date.year, date.month);
    } else {
      // Nur der Tag hat sich innerhalb desselben Monats geändert.
      // Berichte mit den bereits geladenen Daten und neuem selectedDay neu berechnen.
      _updateCalculatedReports();
    }
  }

  void onMonthChanged(DateTime newMonth) {
    // Normalisiere den Monat auf den ersten Tag, um Konsistenz zu gewährleisten.
    final normalizedMonth = DateTime(newMonth.year, newMonth.month, 1);
    
    // Setze den ausgewählten Tag auf den ersten des neuen Monats.
    state = state.copyWith(
        selectedMonth: normalizedMonth, 
        selectedDay: normalizedMonth);
    _loadWorkEntriesForMonth(newMonth.year, newMonth.month);
  }

  Future<void> _loadWorkEntriesForMonth(int year, int month) async {
    state = state.copyWith(isLoading: true);
    try {
      final entries = await _workRepository.getWorkEntriesForMonth(year, month);
      _monthlyEntries = entries;
    } catch (e, stackTrace) {
      print('Fehler beim Laden der Arbeitseinträge: $e');
      print('Stacktrace: $stackTrace');
      _monthlyEntries = []; // Stelle sicher, dass die Liste bei einem Fehler leer ist
    } finally {
      // Dieser Block wird immer ausgeführt.
      // _updateCalculatedReports setzt isLoading auf false und aktualisiert alle Report-States.
      _updateCalculatedReports();
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
    final overtime = Duration.zero;

    return DailyReportState(
      entries: entriesForDay,
      workTime: workTime,
      breakTime: breakTime,
      totalTime: totalTime,
      overtime: overtime,
    );
  }

  int _getWeekNumber(DateTime date) {
    final firstWeek = DateTime(date.year, 1, 4);
    final dayOfWeek = firstWeek.weekday;
    final firstDayOfFirstWeek =
        firstWeek.subtract(Duration(days: dayOfWeek - 1));
    final diff = date.difference(firstDayOfFirstWeek).inDays;
    return (diff / 7).floor() + 1;
  }

  WorkEntryEntity applyBreakCalculation(WorkEntryEntity entry) {
    if (entry.workStart != null && entry.workEnd != null) {
      return BreakCalculatorService.calculateAndApplyBreaks(entry);
    }
    return entry;
  }

  WeeklyReportState _calculateWeeklyReport(DateTime date) {
    // Normalize date to midnight to avoid time-of-day issues in week calculation
    final reportDate = DateTime(date.year, date.month, date.day);
    final startOfWeek = reportDate.subtract(Duration(days: reportDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final entriesForWeek = _monthlyEntries.where((entry) {
      // Normalize entry date to midnight for correct comparison.
      final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      // Check if the entry date is within the week range (inclusive).
      return !entryDate.isBefore(startOfWeek) && !entryDate.isAfter(endOfWeek);
    }).toList();

    final totalWorkDuration = entriesForWeek.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.effectiveWorkDuration);
    final totalBreakDuration = entriesForWeek.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalBreakTime);
    final totalNetWorkDuration = totalWorkDuration - totalBreakDuration;

    final workDays = entriesForWeek.length; // Korrekt: Anzahl der Einträge als Arbeitstage
    final averageWorkDuration = workDays > 0
        ? Duration(seconds: totalNetWorkDuration.inSeconds ~/ workDays)
        : Duration.zero;

    final targetDailyHoursInDouble =
        _settingsRepository.getTargetWeeklyHours() / 5;
    // Korrekte Berechnung der Soll-Wochenstunden basierend auf tatsächlichen Arbeitstagen in der Woche
    final targetWeeklyHoursForActualWorkdaysInMicroseconds =
        (targetDailyHoursInDouble * workDays * Duration.microsecondsPerHour)
            .toInt();
    final targetWeeklyHours =
        Duration(microseconds: targetWeeklyHoursForActualWorkdaysInMicroseconds);
    final overtime = totalNetWorkDuration - targetWeeklyHours;

    final manualOvertimes = entriesForWeek.fold<Duration>(
        Duration.zero,
        (prev, entry) => prev + (entry.manualOvertime ?? Duration.zero));
    final totalWeeklyOvertime = overtime + manualOvertimes;

    Map<DateTime, Duration> dailyWork = {};
    for (var entry in entriesForWeek) {
      // Stelle sicher, dass nur Einträge mit gültiger Dauer berücksichtigt werden
      if (entry.workStart != null && entry.workEnd != null && entry.effectiveWorkDuration > Duration.zero) {
        dailyWork[entry.date] = (dailyWork[entry.date] ?? Duration.zero) + entry.effectiveWorkDuration;
      }
    }
    
    return WeeklyReportState(
      workDays: dailyWork.keys.length, // Besser: Anzahl der Tage mit Arbeit
      totalWorkDuration: totalWorkDuration,
      totalBreakDuration: totalBreakDuration,
      totalNetWorkDuration: totalNetWorkDuration,
      averageWorkDuration: averageWorkDuration,
      overtime: totalWeeklyOvertime,
      dailyWork: dailyWork,
    );
  }

  MonthlyReportState _calculateMonthlyReport() {
    // _monthlyEntries enthält bereits alle Einträge für den ausgewählten Monat
    final totalWorkDuration = _monthlyEntries.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalWorkTime);
    final totalBreakDuration = _monthlyEntries.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalBreakTime);
    final totalNetWorkDuration = totalWorkDuration - totalBreakDuration;

    // Eindeutige Arbeitstage im Monat zählen
    final uniqueWorkDaysSet =
        _monthlyEntries.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).toSet();
    final workDays = uniqueWorkDaysSet.length;

    final averageWorkDuration =
        workDays > 0 ? Duration(microseconds: totalNetWorkDuration.inMicroseconds ~/ workDays) : Duration.zero;

    final targetDailyHours = _settingsRepository.getTargetWeeklyHours() / 5;
    final totalTargetHoursForActualWorkDays =
        Duration(microseconds: (targetDailyHours * workDays * Duration.microsecondsPerHour).toInt());
    final overtime = totalNetWorkDuration - totalTargetHoursForActualWorkDays;

    final manualOvertimes = _monthlyEntries.fold<Duration>(
        Duration.zero,
        (prev, entry) => prev + (entry.manualOvertime ?? Duration.zero));
    final calculatedMonthlyOvertime = overtime + manualOvertimes;

    final dashboardState = _ref.read(dashboardViewModelProvider);
    final totalOvertimeOverall = dashboardState.totalBalance ?? calculatedMonthlyOvertime; // Fallback, falls kein Gesamtstand da

    final Map<DateTime, Duration> dailyWork = {};
    final Map<int, Duration> weeklyWork = {};

    for (var entry in _monthlyEntries) {
      if (entry.workStart != null && entry.workEnd != null && entry.effectiveWorkDuration > Duration.zero) {
        final dayOnly = DateTime(entry.date.year, entry.date.month, entry.date.day);
        dailyWork[dayOnly] = (dailyWork[dayOnly] ?? Duration.zero) + entry.effectiveWorkDuration;

        final weekNumber = _getWeekNumber(entry.date);
        weeklyWork[weekNumber] =
            (weeklyWork[weekNumber] ?? Duration.zero) + entry.effectiveWorkDuration;
      }
    }
    
    // Durchschnittliche Arbeitszeit pro Woche
    final numberOfWeeksWithWork = weeklyWork.keys.length;
    final totalWorkDurationInMonth = weeklyWork.values.fold(Duration.zero, (prev, current) => prev + current);
    final avgWorkDurationPerWeek = numberOfWeeksWithWork > 0 
        ? Duration(microseconds: totalWorkDurationInMonth.inMicroseconds ~/ numberOfWeeksWithWork) 
        : Duration.zero;


    return MonthlyReportState(
      totalWorkDuration: totalWorkDuration,
      totalBreakDuration: totalBreakDuration,
      totalNetWorkDuration: totalNetWorkDuration,
      averageWorkDuration: averageWorkDuration, // Ø pro Tag
      overtime: calculatedMonthlyOvertime, 
      totalOvertime: totalOvertimeOverall,
      workDays: workDays, // Anzahl der tatsächlichen Arbeitstage
      dailyWork: dailyWork, // Für Kalendermarkierungen und Tagesübersicht in Monatsansicht
      weeklyWork: weeklyWork,
      avgWorkDurationPerWeek: avgWorkDurationPerWeek,
    );
  }
}
