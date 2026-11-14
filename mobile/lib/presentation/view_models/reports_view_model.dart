import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:intl/intl.dart';
import 'package:flutter_work_time/core/utils/time_precision.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/providers/today_provider.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/services/break_calculator_service.dart';
import '../../domain/utils/entry_day.dart';
import '../../domain/utils/overtime_utils.dart';
import '../../domain/utils/report_calculator.dart';
import '../state/monthly_report_state.dart';
import '../state/reports_state.dart';
import '../state/weekly_report_state.dart';
import 'leave_balance_view_model.dart' show leaveBalanceViewModelProvider;

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

    // Tageswechsel (#387): bewusst listen statt watch - ein watch würde den
    // Notifier neu bauen (State, gewählter Tag und Monatsdaten gingen verloren).
    ref.listen<DateTime>(todayProvider, _onDayChange);

    return ReportsState.initial(ref.read(todayProvider));
  }

  Future<void> init() async {
    final now = ref.read(todayProvider);
    // Setze den initialen Zustand, inklusive selectedMonth
    state = state.copyWith(
        selectedDay: now,
        focusedDay: now,
        selectedMonth: DateTime(now.year, now.month),
        isLoading: true);

    await _loadWorkEntriesForMonth(now.year, now.month);
  }

  /// Zieht die Auswahl bei einem Tageswechsel nach, aber nur, wenn sie auf dem
  /// bisherigen "heute" stand (Pendant zu Web #383). Ein manuell gewählter Tag
  /// und die Mehrfachauswahl bleiben unangetastet.
  void _onDayChange(DateTime? previous, DateTime next) {
    if (previous == null) return;
    final selected = state.selectedDay;
    if (selected == null || !DateUtils.isSameDay(selected, previous)) return;

    final monthChanged =
        selected.year != next.year || selected.month != next.month;
    state = state.copyWith(selectedDay: next, focusedDay: next);
    if (monthChanged) {
      state = state.copyWith(selectedMonth: DateTime(next.year, next.month));
      unawaited(_loadWorkEntriesForMonth(next.year, next.month));
    } else {
      _updateCalculatedReports();
    }
  }

  void _updateCalculatedReports() {
    final day = state.selectedDay ?? ref.read<DateTime>(todayProvider);
    // Lokale Berechnung als Sofortanzeige und Fallback (offline / nicht eingeloggt).
    state = state.copyWith(
      isLoading: false,
      dailyReportState: _calculateDailyReport(day),
      weeklyReportState: _calculateWeeklyReport(day),
      monthlyReportState: _calculateMonthlyReport(),
      homeOfficeDays: _calculateHomeOfficeDays(),
    );
    // Eingeloggt: server-berechnete Werte (zentrale, korrigierte Logik) laden und
    // die lokalen überschreiben. Schlägt der Abruf fehl (401/offline), bleibt der
    // lokale Fallback bestehen.
    unawaited(_loadReportsFromApi(day));
  }

  /// Tage der geladenen Monatseinträge mit Typ Arbeit und Home-Office-Flag
  /// (#277). Tag über [entryDay] (#418), nicht über `entry.date`.
  Set<DateTime> _calculateHomeOfficeDays() => {
        for (final e in _monthlyEntries)
          if (e.type == WorkEntryType.work && e.isHomeOffice) entryDay(e),
      };

  Future<void> _loadReportsFromApi(DateTime day) async {
    try {
      final api = ref.read(core_providers.apiClientProvider);
      // Aktives Arbeitszeit-Profil mitgeben (siehe #239) — sonst liefert das
      // Backend immer die Werte des Standard-Profils zurück und überschreibt
      // damit die zuvor lokal für das aktive Profil berechneten Werte (#291).
      final profileId = ref.read(core_providers.activeWorkProfileIdProvider);
      final monthRef = state.selectedMonth ?? DateTime(day.year, day.month);
      final results = await Future.wait([
        api.getDailyReport(day.year, day.month, day.day, profileId: profileId),
        api.getWeeklyReport(day.year, day.month, day.day, profileId: profileId),
        api.getMonthlyReport(monthRef.year, monthRef.month,
            profileId: profileId),
      ]);
      if (!ref.mounted) return;
      state = state.copyWith(
        dailyReportState: _dailyWithApiOvertime(day, results[0]),
        weeklyReportState: _weeklyFromApi(results[1]),
        monthlyReportState: _monthlyFromApi(results[2]),
      );
    } catch (e) {
      logger.w(
          '[ReportsViewModel] API-Reports nicht geladen, lokaler Fallback: $e');
    }
  }

  Duration _msDur(dynamic v) =>
      Duration(milliseconds: (v as num?)?.toInt() ?? 0);

  /// Berichtstage des Backends (`days[].date`) sind immer UTC-Mitternacht des
  /// Kalendertags; `.toLocal()` ergäbe westlich von UTC den Vortag (#418).
  DateTime _dayKey(String iso) =>
      calendarDateFromUtcMidnight(DateTime.parse(iso));

  /// Tages-Rohsummen lokal, Überstunden aus dem Backend.
  DailyReportState _dailyWithApiOvertime(
      DateTime day, Map<String, dynamic> json) {
    final local = _calculateDailyReport(day);
    return DailyReportState(
      entries: local.entries,
      workTime: local.workTime,
      breakTime: local.breakTime,
      totalTime: local.totalTime,
      overtime: _msDur(json['overtimeMs']),
    );
  }

  WeeklyReportState _weeklyFromApi(Map<String, dynamic> json) {
    final gross = _msDur(json['totalWorkedMs']);
    final breaks = _msDur(json['totalBreaksMs']);
    return WeeklyReportState(
      totalWorkDuration: gross,
      totalBreakDuration: breaks,
      totalNetWorkDuration: gross - breaks,
      averageWorkDuration: _msDur(json['avgPerDayMs']),
      overtime: _msDur(json['overtimeMs']),
      workDays: (json['workDays'] as num?)?.toInt() ?? 0,
      dailyWork: {
        for (final d in (json['days'] as List<dynamic>? ?? []))
          _dayKey(d['date'] as String): _msDur(d['workedMs']),
      },
    );
  }

  MonthlyReportState _monthlyFromApi(Map<String, dynamic> json) {
    final gross = _msDur(json['totalWorkedMs']);
    final breaks = _msDur(json['totalBreaksMs']);
    return MonthlyReportState(
      totalWorkDuration: gross,
      totalBreakDuration: breaks,
      totalNetWorkDuration: gross - breaks,
      averageWorkDuration: _msDur(json['avgPerDayMs']),
      overtime: _msDur(json['monthlyOvertimeMs']),
      totalOvertime: _msDur(json['totalOvertimeMs']),
      workDays: (json['workDays'] as num?)?.toInt() ?? 0,
      avgWorkDurationPerWeek: _msDur(json['avgPerWeekMs']),
      weeklyWork: {
        for (final w in (json['weeks'] as List<dynamic>? ?? []))
          (w['weekNumber'] as num).toInt(): _msDur(w['totalWorkedMs']),
      },
      dailyWork: {
        for (final d in (json['days'] as List<dynamic>? ?? []))
          _dayKey(d['date'] as String): _msDur(d['workedMs']),
      },
    );
  }

  Future<void> saveWorkEntry(WorkEntryEntity entry) async {
    state = state.copyWith(isLoading: true);
    try {
      final workRepository = ref.read(core_providers.workRepositoryProvider);
      await workRepository.saveWorkEntry(entry);
      ref.invalidate(leaveBalanceViewModelProvider);

      final selectedDate =
          state.selectedDay ?? ref.read<DateTime>(todayProvider);
      await _loadWorkEntriesForMonth(selectedDate.year, selectedDate.month);
    } catch (e, stackTrace) {
      logger.e('Fehler beim Speichern des Arbeitseintrags: $e',
          stackTrace: stackTrace);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> deleteWorkEntry(String entryId) async {
    state = state.copyWith(isLoading: true);
    try {
      final workRepository = ref.read(core_providers.workRepositoryProvider);
      await workRepository.deleteWorkEntry(entryId);
      ref.invalidate(leaveBalanceViewModelProvider);

      // Nach dem Löschen die Einträge für den aktuellen Monat neu laden
      final selectedDate =
          state.selectedDay ?? ref.read<DateTime>(todayProvider);
      await _loadWorkEntriesForMonth(selectedDate.year, selectedDate.month);
    } catch (e, stackTrace) {
      logger.e('Fehler beim Löschen des Arbeitseintrags: $e',
          stackTrace: stackTrace);
      state = state.copyWith(isLoading: false);
    }
  }

  void selectDate(DateTime selected) {
    // Auf lokale Mitternacht normalisieren (#362).
    final date = DateTime(selected.year, selected.month, selected.day);
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
        selectedMonth: normalizedMonth, selectedDay: normalizedMonth);
    _loadWorkEntriesForMonth(newMonth.year, newMonth.month);
  }

  /// Lädt Daten für den aktuellen Monat ohne selectedDay zu ändern
  /// Wird beim initialen Laden verwendet, um den aktuellen Tag beizubehalten
  void loadCurrentMonthData() {
    final now = ref.read(todayProvider);
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
        logger.w(
            '[ReportsViewModel] Firebase Permission-Fehler erkannt - User wahrscheinlich nicht eingeloggt. Verwende leere Daten.');
      } else if (isExpectedLoadFailure(e)) {
        // Verbindungsabbruch/Offline ist kein App-Fehler (#506): nur info,
        // da ab warning an Crashlytics gemeldet wird.
        logger.i(
            '[ReportsViewModel] Netzwerkfehler beim Laden der Arbeitseinträge: $e');
      } else {
        logger.e('Fehler beim Laden der Arbeitseinträge: $e',
            stackTrace: stackTrace);
      }
      _monthlyEntries =
          []; // Stelle sicher, dass die Liste bei einem Fehler leer ist
    } finally {
      // Dieser Block wird immer ausgeführt.
      // _updateCalculatedReports setzt isLoading auf false und aktualisiert alle Report-States.
      // Nach Dispose (z. B. Logout während des Ladens) nichts mehr schreiben.
      if (ref.mounted) _updateCalculatedReports();
    }
  }

  /// Einstellungen der lokalen Berichtsrechnung (#535).
  ReportSettings _reportSettings() {
    final settingsRepository =
        ref.read(core_providers.settingsRepositoryProvider);
    return ReportSettings(
      weeklyTargetHours: settingsRepository.getTargetWeeklyHours(),
      workdays: settingsRepository.getWorkdays(),
    );
  }

  /// Gespeicherter Gleitzeit-Saldo (synchron aus dem Cache des
  /// `OvertimeRepository`; im Gast-Modus der lokal gespeicherte Saldo) für die
  /// Monats-Gesamtüberstunden (#535). Ist das Repository nicht verfügbar,
  /// gilt 0; eingeloggt überschreibt ohnehin der Wert der API.
  Duration _storedOvertime() {
    try {
      return ref.read(core_providers.overtimeRepositoryProvider).getOvertime();
    } catch (e) {
      logger.w('[ReportsViewModel] Gleitzeit-Saldo nicht lesbar, 0: $e');
      return Duration.zero;
    }
  }

  DailyReportState _calculateDailyReport(DateTime date) {
    final dayToReport = DateTime(date.year, date.month, date.day);
    final entriesForDay = _monthlyEntries
        .where((entry) => entryDay(entry) == dayToReport)
        .toList();

    final workTime = entriesForDay.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalWorkTime);
    final breakTime = entriesForDay.fold<Duration>(
        Duration.zero, (prev, e) => prev + e.totalBreakTime);
    final totalTime = workTime - breakTime;
    // Überstunden wie das Backend: geleistet − Soll + manuell (#535).
    final stat =
        calculateDailyStat(_monthlyEntries, dayToReport, _reportSettings());

    return DailyReportState(
      entries: entriesForDay,
      workTime: workTime,
      breakTime: breakTime,
      totalTime: totalTime,
      overtime: stat.overtime,
    );
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
    final settingsRepository =
        ref.read(core_providers.settingsRepositoryProvider);
    final workdays = settingsRepository.getWorkdays();
    if (workdays.isEmpty) return Duration.zero;
    final regularDailyTarget = roundDurationToMinute(Duration(
      microseconds: (settingsRepository.getTargetWeeklyHours() /
              workdays.length *
              Duration.microsecondsPerHour)
          .round(),
    ));

    return getEffectiveDailyTarget(
      date: date,
      workdays: workdays,
      regularDailyTarget: regularDailyTarget,
    );
  }

  /// Lokaler Wochenbericht über die kanonische Rechnung (#535); Abbildung
  /// wie [_weeklyFromApi] (brutto, Tageswerte brutto).
  ///
  /// Grundlage sind nur die geladenen Monatseinträge: Eine Woche über den
  /// Monatswechsel enthält lokal nur die Tage des geladenen Monats.
  WeeklyReportState _calculateWeeklyReport(DateTime date) {
    final r = calculateWeeklyReport(_monthlyEntries, date, _reportSettings());
    return WeeklyReportState(
      totalWorkDuration: r.totalWorked,
      totalBreakDuration: r.totalBreaks,
      totalNetWorkDuration: r.totalWorked - r.totalBreaks,
      averageWorkDuration: _msDur(r.avgPerDayMs),
      overtime: r.overtime,
      workDays: r.workDays,
      dailyWork: {for (final d in r.days) d.date: d.worked},
    );
  }

  /// Lokaler Monatsbericht über die kanonische Rechnung (#535); Abbildung
  /// wie [_monthlyFromApi]. Gesamtüberstunden = gespeicherter Saldo.
  MonthlyReportState _calculateMonthlyReport() {
    final day = state.selectedDay ?? ref.read<DateTime>(todayProvider);
    final monthRef = state.selectedMonth ?? DateTime(day.year, day.month);
    final r = calculateMonthlyReport(
        _monthlyEntries, monthRef, _reportSettings(), _storedOvertime());
    return MonthlyReportState(
      totalWorkDuration: r.totalWorked,
      totalBreakDuration: r.totalBreaks,
      totalNetWorkDuration: r.totalWorked - r.totalBreaks,
      averageWorkDuration: _msDur(r.avgPerDayMs),
      overtime: r.monthlyOvertime,
      totalOvertime: r.totalOvertime,
      workDays: r.workDays,
      avgWorkDurationPerWeek: _msDur(r.avgPerWeekMs),
      weeklyWork: {for (final w in r.weeks) w.weekNumber: w.totalWorked},
      dailyWork: {for (final d in r.days) d.date: d.worked},
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
              ? DateTime(date.year, date.month, date.day, startTime.hour,
                  startTime.minute)
              : null,
          workEnd: endTime != null
              ? DateTime(
                  date.year, date.month, date.day, endTime.hour, endTime.minute)
              : null,
        );
        await workRepository.saveWorkEntry(entry);
      }

      ref.invalidate(leaveBalanceViewModelProvider);

      // Clear selection, reset multi-select mode and reload data
      final selectedDate =
          state.selectedDay ?? ref.read<DateTime>(todayProvider);
      clearDateSelection();
      state = state.copyWith(multiSelectMode: false);
      await _loadWorkEntriesForMonth(selectedDate.year, selectedDate.month);
    } catch (e, stackTrace) {
      logger.e('Fehler beim Speichern von Batch-Einträgen: $e',
          stackTrace: stackTrace);
      // Teilweise gespeicherte Einträge können den Resturlaub ändern.
      ref.invalidate(leaveBalanceViewModelProvider);
      state = state.copyWith(isLoading: false);
    }
  }
}
