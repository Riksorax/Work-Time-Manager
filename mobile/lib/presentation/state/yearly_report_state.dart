import 'package:equatable/equatable.dart';

import '../../domain/utils/yearly_report_utils.dart';

/// Zustand für den Jahresbericht (siehe #136): Monatsvergleich,
/// Gesamtüberstunden sowie Urlaubs-/Kranktage über ein Kalenderjahr.
class YearlyReportState extends Equatable {
  final bool isLoading;
  final int year;
  final List<MonthSummary> months; // Immer 12 Einträge, Monat 1-12

  const YearlyReportState({
    this.isLoading = false,
    required this.year,
    required this.months,
  });

  factory YearlyReportState.initial() => YearlyReportState(
        // isLoading startet auf true: der erste Frame würde sonst kurz
        // "keine Daten" zeigen, bevor der Ladevorgang (ausgelöst per
        // postFrameCallback) überhaupt gestartet ist.
        isLoading: true,
        year: DateTime.now().year,
        months: List.generate(12, (i) => MonthSummary.empty(i + 1)),
      );

  Duration get totalNetWorkDuration =>
      months.fold(Duration.zero, (sum, m) => sum + m.netWorkDuration);

  Duration get totalOvertime =>
      months.fold(Duration.zero, (sum, m) => sum + m.overtime);

  int get totalWorkDays => months.fold(0, (sum, m) => sum + m.workDays);

  int get totalVacationDays => months.fold(0, (sum, m) => sum + m.vacationDays);

  int get totalSickDays => months.fold(0, (sum, m) => sum + m.sickDays);

  int get totalHolidayDays => months.fold(0, (sum, m) => sum + m.holidayDays);

  YearlyReportState copyWith({
    bool? isLoading,
    int? year,
    List<MonthSummary>? months,
  }) {
    return YearlyReportState(
      isLoading: isLoading ?? this.isLoading,
      year: year ?? this.year,
      months: months ?? this.months,
    );
  }

  @override
  List<Object?> get props => [isLoading, year, months];
}
