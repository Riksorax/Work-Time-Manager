import 'package:equatable/equatable.dart';

import '../../domain/entities/yearly_comparison.dart';
import '../../domain/utils/yearly_report_utils.dart';

/// Jahressummen, wie sie das Backend liefert (#530, `current` von
/// `GET /api/reports/yearly-comparison/{year}` ohne Stichtag). Die Monatswerte
/// des Backends enthalten keine Urlaubs-/Kranktage je Monat; die Summen
/// stehen deshalb hier und nicht als Summe der [MonthSummary]-Liste.
class YearlyTotals extends Equatable {
  final Duration netWorkDuration;
  final Duration overtime;
  final int workDays;
  final int vacationDays;
  final int sickDays;
  final int holidayDays;

  const YearlyTotals({
    required this.netWorkDuration,
    required this.overtime,
    required this.workDays,
    required this.vacationDays,
    required this.sickDays,
    required this.holidayDays,
  });

  @override
  List<Object?> get props => [
        netWorkDuration,
        overtime,
        workDays,
        vacationDays,
        sickDays,
        holidayDays
      ];
}

/// Zustand für den Jahresbericht (siehe #136): Monatsvergleich,
/// Gesamtüberstunden sowie Urlaubs-/Kranktage über ein Kalenderjahr.
///
/// Angemeldet kommen Summen und Monatswerte vom Backend ([fromSummary], #530),
/// als Gast aus der lokalen Rechnung (Summen = Summe der [months]).
class YearlyReportState extends Equatable {
  final bool isLoading;

  /// Angemeldet: die Jahreswerte konnten nicht vom Backend geladen werden
  /// (kein lokaler Ersatz, „Erneut versuchen“ in der Ansicht).
  final bool hasError;
  final int year;
  final List<MonthSummary> months; // Immer 12 Einträge, Monat 1-12

  /// Summen des Backends; `null` = Summe der [months] (Gast).
  final YearlyTotals? totals;

  const YearlyReportState({
    this.isLoading = false,
    this.hasError = false,
    required this.year,
    required this.months,
    this.totals,
  });

  factory YearlyReportState.initial(int year) => YearlyReportState(
        // isLoading startet auf true: der erste Frame würde sonst kurz
        // "keine Daten" zeigen, bevor der Ladevorgang (ausgelöst per
        // postFrameCallback) überhaupt gestartet ist.
        isLoading: true,
        year: year,
        months: emptyMonths(),
      );

  /// Jahreswerte aus der Antwort des Backends (#530). Die Monate tragen nur,
  /// was das Backend je Monat liefert (netto, Überstunden, Arbeitstage);
  /// Urlaubs-, Krankheits- und Feiertage gibt es nur als Jahressumme.
  factory YearlyReportState.fromSummary(int year, YearlySummary s) =>
      YearlyReportState(
        year: year,
        months: [
          for (final m in s.months)
            MonthSummary(
              month: m.month,
              netWorkDuration: m.worked,
              overtime: m.overtime,
              workDays: m.workDays,
              vacationDays: 0,
              sickDays: 0,
              holidayDays: 0,
            ),
        ],
        totals: YearlyTotals(
          netWorkDuration: s.totalWorked,
          overtime: s.overtime,
          workDays: s.workDays,
          vacationDays: s.vacationDays,
          sickDays: s.sickDays,
          holidayDays: s.holidayDays,
        ),
      );

  static List<MonthSummary> emptyMonths() =>
      List.generate(12, (i) => MonthSummary.empty(i + 1));

  Duration get totalNetWorkDuration =>
      totals?.netWorkDuration ??
      months.fold(Duration.zero, (sum, m) => sum + m.netWorkDuration);

  Duration get totalOvertime =>
      totals?.overtime ??
      months.fold(Duration.zero, (sum, m) => sum + m.overtime);

  int get totalWorkDays =>
      totals?.workDays ?? months.fold(0, (sum, m) => sum + m.workDays);

  int get totalVacationDays =>
      totals?.vacationDays ?? months.fold(0, (sum, m) => sum + m.vacationDays);

  int get totalSickDays =>
      totals?.sickDays ?? months.fold(0, (sum, m) => sum + m.sickDays);

  int get totalHolidayDays =>
      totals?.holidayDays ?? months.fold(0, (sum, m) => sum + m.holidayDays);

  YearlyReportState copyWith({
    bool? isLoading,
    int? year,
    List<MonthSummary>? months,
  }) {
    return YearlyReportState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError,
      year: year ?? this.year,
      months: months ?? this.months,
      totals: totals,
    );
  }

  @override
  List<Object?> get props => [isLoading, hasError, year, months, totals];
}
