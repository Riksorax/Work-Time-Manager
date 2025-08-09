import 'package:equatable/equatable.dart';
import '../../domain/entities/work_entry_entity.dart';
import 'monthly_report_state.dart';
import 'weekly_report_state.dart';

enum ReportType { daily, weekly, monthly }

class ReportsState extends Equatable {
  final bool isLoading;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Map<DateTime, List<WorkEntryEntity>> workEntries;
  final ReportType reportType;

  // Report data
  final DailyReportState dailyReportState;
  final WeeklyReportState weeklyReportState;
  final MonthlyReportState monthlyReportState;

  const ReportsState({
    this.isLoading = false,
    required this.focusedDay,
    this.selectedDay,
    required this.workEntries,
    this.reportType = ReportType.daily,
    this.dailyReportState = DailyReportState.initial,
    this.weeklyReportState = WeeklyReportState.initial,
    this.monthlyReportState = MonthlyReportState.initial,
  });

  factory ReportsState.initial() {
    final now = DateTime.now();
    return ReportsState(
      isLoading: true,
      focusedDay: now,
      selectedDay: now,
      workEntries: const {},
    );
  }

  ReportsState copyWith({
    bool? isLoading,
    DateTime? focusedDay,
    DateTime? selectedDay,
    Map<DateTime, List<WorkEntryEntity>>? workEntries,
    ReportType? reportType,
    DailyReportState? dailyReportState,
    WeeklyReportState? weeklyReportState,
    MonthlyReportState? monthlyReportState,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      focusedDay: focusedDay ?? this.focusedDay,
      selectedDay: selectedDay ?? this.selectedDay,
      workEntries: workEntries ?? this.workEntries,
      reportType: reportType ?? this.reportType,
      dailyReportState: dailyReportState ?? this.dailyReportState,
      weeklyReportState: weeklyReportState ?? this.weeklyReportState,
      monthlyReportState: monthlyReportState ?? this.monthlyReportState,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        focusedDay,
        selectedDay,
        workEntries,
        reportType,
        dailyReportState,
        weeklyReportState,
        monthlyReportState,
      ];
}

class DailyReportState extends Equatable {
  final List<WorkEntryEntity> entries;
  final Duration workTime;
  final Duration breakTime;
  final Duration totalTime;
  final Duration overtime;

  const DailyReportState({
    required this.entries,
    required this.workTime,
    required this.breakTime,
    required this.totalTime,
    required this.overtime,
  });

  static const DailyReportState initial = DailyReportState(
    entries: [],
    workTime: Duration.zero,
    breakTime: Duration.zero,
    totalTime: Duration.zero,
    overtime: Duration.zero,
  );

  @override
  List<Object?> get props => [entries, workTime, breakTime, totalTime, overtime];
}
