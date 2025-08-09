import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/work_repository.dart';
import '../state/monthly_report_state.dart';
import '../state/reports_state.dart';
import '../state/weekly_report_state.dart';

final reportsViewModelProvider =
    StateNotifierProvider<ReportsViewModel, ReportsState>((ref) {
  try {
    final workRepository = ref.watch(workRepositoryProvider);
    final settingsRepository = ref.watch(settingsRepositoryProvider);
    return ReportsViewModel(workRepository, settingsRepository)..init();
  } catch (e) {
    // Wenn das workRepositoryProvider eine Exception wirft (weil kein User da ist),
    // fangen wir sie hier ab und geben ein ViewModel mit einem DummyRepository zurück.
    final settingsRepository = ref.watch(settingsRepositoryProvider);
    return ReportsViewModel(const DummyWorkRepository(), settingsRepository);
  }
});

class ReportsViewModel extends StateNotifier<ReportsState> {
  final WorkRepository _workRepository;
  final SettingsRepository _settingsRepository;

  ReportsViewModel(this._workRepository, this._settingsRepository)
      : super(ReportsState.initial());

  Future<void> init() async {
    if (_workRepository is DummyWorkRepository) return;
    await _loadWorkEntriesForMonth(state.focusedDay);
  }

  Future<void> _loadWorkEntriesForMonth(DateTime month) async {
    state = state.copyWith(isLoading: true);
    final entries =
        await _workRepository.getWorkEntriesForMonth(month.year, month.month);
    final Map<DateTime, List<WorkEntryEntity>> entriesByDay = {};
    for (var entry in entries) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (entriesByDay[day] == null) {
        entriesByDay[day] = [];
      }
      entriesByDay[day]!.add(entry);
    }
    state = state.copyWith(
        workEntries: entriesByDay, focusedDay: month, isLoading: false);
    await _calculateReports(state.selectedDay ?? month);
  }

  Future<void> selectDate(DateTime day) async {
    state = state.copyWith(selectedDay: day, focusedDay: day);
    await _calculateReports(day);
  }

  Future<void> onMonthChanged(DateTime newMonth) async {
    await _loadWorkEntriesForMonth(newMonth);
  }

  void setReportType(ReportType type) {
    state = state.copyWith(reportType: type);
  }

  Future<void> _calculateReports(DateTime selectedDay) async {
    final weeklyTargetHours = _settingsRepository.getTargetWeeklyHours();
    // Assuming 5 workdays a week if not specified
    const workdaysPerWeek = 5;
    final double targetHoursPerDay =
        weeklyTargetHours > 0 ? weeklyTargetHours / workdaysPerWeek : 8.0;
    final Duration dailyTargetDuration = Duration(
        microseconds:
            (targetHoursPerDay * Duration.microsecondsPerHour).round());

    final dayWithoutTime =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final entriesForDay = state.workEntries[dayWithoutTime] ?? [];
    final dailyReport =
        _calculateDailyReport(entriesForDay, dailyTargetDuration);

    final weeklyReport =
        _calculateWeeklyReport(selectedDay, dailyTargetDuration);
    final monthlyReport = _calculateMonthlyReport(dailyTargetDuration);

    state = state.copyWith(
      dailyReportState: dailyReport,
      weeklyReportState: weeklyReport,
      monthlyReportState: monthlyReport,
    );
  }

  DailyReportState _calculateDailyReport(
      List<WorkEntryEntity> entries, Duration dailyTargetDuration) {
    if (entries.isEmpty) {
      return DailyReportState.initial;
    }

    Duration workTime = Duration.zero;
    Duration breakTime = Duration.zero;

    for (var entry in entries) {
      workTime += entry.totalWorkTime;
      breakTime += entry.totalBreakTime;
    }

    final overtime = workTime - dailyTargetDuration;

    return DailyReportState(
      entries: entries,
      workTime: workTime,
      breakTime: breakTime,
      totalTime: workTime + breakTime,
      overtime: overtime,
    );
  }

  WeeklyReportState _calculateWeeklyReport(
      DateTime selectedDay, Duration dailyTargetDuration) {
    final startOfWeek =
        selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    Duration totalWork = Duration.zero;
    Duration totalBreak = Duration.zero;
    Set<DateTime> daysWithWork = {};

    state.workEntries.forEach((day, entries) {
      if (day.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          day.isBefore(endOfWeek.add(const Duration(days: 1)))) {
        for (var entry in entries) {
          totalWork += entry.totalWorkTime;
          totalBreak += entry.totalBreakTime;
        }
        daysWithWork.add(day);
      }
    });

    final workDays = daysWithWork.length;
    final overtime = totalWork -
        Duration(microseconds: workDays * dailyTargetDuration.inMicroseconds);

    return WeeklyReportState(
      totalWorkDuration: totalWork,
      totalBreakDuration: totalBreak,
      totalNetWorkDuration: totalWork,
      averageWorkDuration: workDays > 0 ? totalWork ~/ workDays : Duration.zero,
      overtime: overtime,
      workDays: workDays,
    );
  }

  MonthlyReportState _calculateMonthlyReport(Duration dailyTargetDuration) {
    Duration totalWork = Duration.zero;
    Duration totalBreak = Duration.zero;
    Set<DateTime> daysWithWork = {};

    state.workEntries.forEach((day, entries) {
      for (var entry in entries) {
        totalWork += entry.totalWorkTime;
        totalBreak += entry.totalBreakTime;
      }
      daysWithWork.add(day);
    });

    final workDays = daysWithWork.length;
    final overtime = totalWork -
        Duration(microseconds: workDays * dailyTargetDuration.inMicroseconds);

    return MonthlyReportState(
      totalWorkDuration: totalWork,
      totalBreakDuration: totalBreak,
      totalNetWorkDuration: totalWork,
      averageWorkDuration: workDays > 0 ? totalWork ~/ workDays : Duration.zero,
      overtime: overtime,
      workDays: workDays,
    );
  }
}

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
    // Return a valid, but empty entity as per the interface contract.
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
