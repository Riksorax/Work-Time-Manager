import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/services/break_calculator_service.dart';
import '../../domain/utils/overtime_utils.dart';
import '../state/monthly_report_state.dart';
import '../state/reports_state.dart';
import '../state/weekly_report_state.dart';

final reportsViewModelProvider =
    NotifierProvider<ReportsViewModel, ReportsState>(ReportsViewModel.new);

class ReportsViewModel extends Notifier<ReportsState> {
  List<WorkEntryEntity> _monthlyEntries = [];

  @override
  ReportsState build() {
    // Watch repositories to trigger rebuild on auth change
    ref.watch(core_providers.workRepositoryProvider);
    ref.watch(core_providers.settingsRepositoryProvider);

    // Initial load logic
    Future.microtask(() => init());
    
    return ReportsState.initial();
  }

  Future<void> init() async {
    final now = DateTime.now();
    // Setze den initialen Zustand, inklusive selectedMonth
    state = state.copyWith(
        selectedDay: now,
        selectedMonth: DateTime(now.year, now.month),
        isLoading: true);

    await _loadWorkEntriesForMonth(now.year, now.month);
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
      final workRepository = ref.read(core_providers.workRepositoryProvider);
      await workRepository.saveWorkEntry(entry);
      
      final selectedDate = state.selectedDay ?? DateTime.now();
      await _loadWorkEntriesForMonth(selectedDate.year, selectedDate.month);
    } catch (e, stackTrace) {
      logger.e('Fehler beim Speichern des Arbeitseintrags: $e', stackTrace: stackTrace);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> deleteWorkEntry(String entryId) async {
    state = state.copyWith(isLoading: true);
    try {
      final workRepository = ref.read(core_providers.workRepositoryProvider);
      await workRepository.deleteWorkEntry(entryId);
      
      // Nach dem Löschen die Einträge für den aktuellen Monat neu laden
      final selectedDate = state.selectedDay ?? DateTime.now();
      await _loadWorkEntriesForMonth(selectedDate.year, selectedDate.month);
    } catch (e, stackTrace) {
      logger.e('Fehler beim Löschen des Arbeitseintrags: $e', stackTrace: stackTrace);
      state = state.copyWith(isLoading: false);
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

  /// Lädt Daten für den aktuellen Monat ohne selectedDay zu ändern
  /// Wird beim initialen Laden verwendet, um den aktuellen Tag beizubehalten
  void loadCurrentMonthData() {
    final now = DateTime.now();
    final normalizedMonth = DateTime(now.year, now.month, 1);

    // Aktualisiere nur selectedMonth, behalte selectedDay (sollte bereits auf heute gesetzt sein)
    state = state.copyWith(selectedMonth: normalizedMonth);
    _loadWorkEntriesForMonth(now.year, now.month);
  }

  Future<void> _loadWorkEntriesForMonth(int year, int month) async {
    state = state.copyWith(isLoading: true);
    try {
      final workRepository = ref.read(core_providers.workRepositoryProvider);
      final entries = await workRepository.getWorkEntriesForMonth(year, month);
      _monthlyEntries = entries;
    } catch (e, stackTrace) {
      // Prüfe, ob es sich um einen Permission-Fehler handelt
      final errorMessage = e.toString();
      if (errorMessage.contains('permission-denied')) {
        logger.w('[ReportsViewModel] Firebase Permission-Fehler erkannt - User wahrscheinlich nicht eingeloggt. Verwende leere Daten.');
      } else {
        logger.e('Fehler beim Laden der Arbeitseinträge: $e', stackTrace: stackTrace);
      }
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
    // Keine Pausenberechnung für Urlaub, Krank oder Feiertag —
    // diese Eintragstypen erfüllen das Soll automatisch ohne Pausenabzug.
    if (entry.type != WorkEntryType.work) {
      return entry;
    }
    if (entry.workStart != null && entry.workEnd != null) {
      return BreakCalculatorService.calculateAndApplyBreaks(entry);
    }
    return entry;
  }

  /// Berechnet das effektive Tages-Soll für ein bestimmtes Datum.
  /// Gibt Duration.zero zurück, wenn der Tag ein Zusatztag ist
  /// (mehr Arbeitstage in der Woche als konfiguriert).
  Duration getEffectiveDailyTargetForDate(DateTime date) {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
    final workdaysPerWeek = settingsRepository.getWorkdaysPerWeek();
    if (workdaysPerWeek <= 0) return Duration.zero;
    final regularDailyTarget = Duration(
      microseconds: (settingsRepository.getTargetWeeklyHours() /
              workdaysPerWeek *
              Duration.microsecondsPerHour)
          .round(),
    );

    final weekEntries = getWeekEntriesForDate(date, _monthlyEntries);
    return getEffectiveDailyTarget(
      date: date,
      weekEntries: weekEntries,
      workdaysPerWeek: workdaysPerWeek,
      regularDailyTarget: regularDailyTarget,
    );
  }

  WeeklyReportState _calculateWeeklyReport(DateTime date) {
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
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

    // Unique Arbeitstage zählen (nicht Einträge, da mehrere Einträge pro Tag möglich)
    final uniqueWorkDays = entriesForWeek
        .where((e) => e.workStart != null)
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .length;
    final averageWorkDuration = uniqueWorkDays > 0
        ? Duration(seconds: totalNetWorkDuration.inSeconds ~/ uniqueWorkDays)
        : Duration.zero;

    final workdaysPerWeek = settingsRepository.getWorkdaysPerWeek();
    final targetDailyHoursInDouble = workdaysPerWeek > 0
        ? settingsRepository.getTargetWeeklyHours() / workdaysPerWeek
        : 0.0;
    // Wochen-Soll begrenzen: max. workdaysPerWeek Tage zählen,
    // damit Zusatztage das Soll nicht erhöhen
    final effectiveWorkDays = min(uniqueWorkDays, workdaysPerWeek);
    final targetWeeklyHoursForActualWorkdaysInMicroseconds =
        (targetDailyHoursInDouble * effectiveWorkDays * Duration.microsecondsPerHour)
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
    final settingsRepository = ref.read(core_providers.settingsRepositoryProvider);
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

    final workdaysPerWeek = settingsRepository.getWorkdaysPerWeek();
    final targetDailyHours = workdaysPerWeek > 0
        ? settingsRepository.getTargetWeeklyHours() / workdaysPerWeek
        : 0.0;

    // Arbeitstage pro Woche gruppieren und jeweils auf workdaysPerWeek deckeln,
    // damit Zusatztage das Monats-Soll nicht erhöhen
    final Map<int, Set<DateTime>> weekToWorkDays = {};
    for (var entry in _monthlyEntries) {
      if (entry.workStart != null) {
        final weekNum = _getWeekNumber(entry.date);
        final dayOnly = DateTime(entry.date.year, entry.date.month, entry.date.day);
        weekToWorkDays.putIfAbsent(weekNum, () => {}).add(dayOnly);
      }
    }
    int effectiveTotalWorkDays = 0;
    for (var weekDays in weekToWorkDays.values) {
      effectiveTotalWorkDays += min(weekDays.length, workdaysPerWeek);
    }

    final totalTargetHoursForActualWorkDays =
        Duration(microseconds: (targetDailyHours * effectiveTotalWorkDays * Duration.microsecondsPerHour).toInt());
    final overtime = totalNetWorkDuration - totalTargetHoursForActualWorkDays;

    final manualOvertimes = _monthlyEntries.fold<Duration>(
        Duration.zero,
        (prev, entry) => prev + (entry.manualOvertime ?? Duration.zero));
    final calculatedMonthlyOvertime = overtime + manualOvertimes;

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
      totalOvertime: calculatedMonthlyOvertime,
      workDays: workDays, // Anzahl der tatsächlichen Arbeitstage
      dailyWork: dailyWork, // Für Kalendermarkierungen und Tagesübersicht in Monatsansicht
      weeklyWork: weeklyWork,
      avgWorkDurationPerWeek: avgWorkDurationPerWeek,
    );
  }

  // Multi-Select Methods (Range Selection via Drag)
  void toggleMultiSelectMode() {
    state = state.copyWith(multiSelectMode: !state.multiSelectMode);
    if (!state.multiSelectMode) {
      clearDateSelection();
    }
  }

  void addDateToSelection(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final newSelectedDates = Set<DateTime>.from(state.selectedDates);
    newSelectedDates.add(dateOnly);
    state = state.copyWith(selectedDates: newSelectedDates);
  }

  void removeDateFromSelection(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final newSelectedDates = Set<DateTime>.from(state.selectedDates);
    newSelectedDates.remove(dateOnly);
    state = state.copyWith(selectedDates: newSelectedDates);
  }

  void toggleDateSelection(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    if (state.selectedDates.contains(dateOnly)) {
      removeDateFromSelection(dateOnly);
    } else {
      addDateToSelection(dateOnly);
    }
  }

  void clearDateSelection() {
    state = state.copyWith(selectedDates: const {});
  }

  Future<void> saveBatchWorkEntries(
    List<DateTime> dates,
    WorkEntryType type,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  ) async {
    state = state.copyWith(isLoading: true);
    try {
      final workRepository = ref.read(core_providers.workRepositoryProvider);

      for (final date in dates) {
        final entry = WorkEntryEntity(
          id: DateFormat('yyyy-MM-dd').format(date),
          date: date,
          type: type,
          isManuallyEntered: true,
          workStart: startTime != null
              ? DateTime(date.year, date.month, date.day, startTime.hour, startTime.minute)
              : null,
          workEnd: endTime != null
              ? DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute)
              : null,
        );
        await workRepository.saveWorkEntry(entry);
      }

      // Clear selection, reset multi-select mode and reload data
      final selectedDate = state.selectedDay ?? DateTime.now();
      clearDateSelection();
      state = state.copyWith(multiSelectMode: false);
      await _loadWorkEntriesForMonth(selectedDate.year, selectedDate.month);
    } catch (e, stackTrace) {
      logger.e('Fehler beim Speichern von Batch-Einträgen: $e', stackTrace: stackTrace);
      state = state.copyWith(isLoading: false);
    }
  }
}

