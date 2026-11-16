import 'package:equatable/equatable.dart';
import '../../domain/entities/overtime_freshness.dart';
import '../../domain/entities/work_entry_entity.dart';
import 'monthly_report_state.dart';
import 'weekly_report_state.dart';

enum ReportType { daily, weekly, monthly }

/// Die Einträge des Monats ließen sich nicht laden (#573). Angemeldet kommen
/// sie nur über die API; ohne Netz gibt es keine Einträge und damit auch keine
/// lokal berechneten Werte.
enum ReportsLoadFailure {
  none,

  /// Erwartbarer Netzwerkfehler (`isTransientNetworkError`): „Keine Verbindung“.
  offline,

  /// Anderer Fehler: allgemeine Meldung.
  failed,
}

class ReportsState extends Equatable {
  final bool isLoading;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final DateTime? selectedMonth;
  final Map<DateTime, List<WorkEntryEntity>> workEntries;

  /// Kalendertage (lokale Mitternacht) des gewählten Monats mit Typ Arbeit und
  /// Home-Office-Flag (#277), für die Kalendermarkierung.
  final Set<DateTime> homeOfficeDays;

  /// Arbeitsorte je Tag der geladenen Monatseinträge (#526, nur Typ Arbeit,
  /// Tag über `entryDay`); nur für die Anzeige im PDF.
  final Map<DateTime, List<String>> workLocationDays;
  final ReportType reportType;

  // Report data
  final DailyReportState dailyReportState;
  final WeeklyReportState weeklyReportState;
  final MonthlyReportState monthlyReportState;
  // Multi-Select Fields
  final Set<DateTime> selectedDates;
  final bool multiSelectMode;

  /// Ladefehler der Monatseinträge (#573); die Oberfläche zeigt dann einen
  /// Hinweis mit „Erneut versuchen“ statt Nullwerten.
  final ReportsLoadFailure loadFailure;

  /// Herkunft der Monats-Gesamtüberstunden (#573): `cached`/`unknown`, solange
  /// sie lokal aus dem gemerkten Saldo stammen; `current` nach der API-Antwort.
  final OvertimeFreshness overtimeFreshness;

  const ReportsState({
    this.isLoading = false,
    required this.focusedDay,
    this.selectedDay,
    this.selectedMonth,
    required this.workEntries,
    this.homeOfficeDays = const {},
    this.workLocationDays = const {},
    this.reportType = ReportType.daily,
    this.dailyReportState = DailyReportState.initial,
    this.weeklyReportState = WeeklyReportState.initial,
    this.monthlyReportState = MonthlyReportState.initial,
    this.selectedDates = const {},
    this.multiSelectMode = false,
    this.loadFailure = ReportsLoadFailure.none,
    this.overtimeFreshness = OvertimeFreshness.current,
  });

  /// Startzustand für den lokalen Tag [today] (aus `todayProvider`, #387).
  /// Auf lokale Mitternacht normalisiert, ohne Uhrzeitanteil.
  factory ReportsState.initial(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return ReportsState(
      isLoading: true,
      focusedDay: day,
      selectedDay: day,
      selectedMonth: DateTime(day.year, day.month),
      workEntries: const {},
    );
  }

  ReportsState copyWith({
    bool? isLoading,
    DateTime? focusedDay,
    DateTime? selectedDay,
    DateTime? selectedMonth,
    Map<DateTime, List<WorkEntryEntity>>? workEntries,
    Set<DateTime>? homeOfficeDays,
    Map<DateTime, List<String>>? workLocationDays,
    ReportType? reportType,
    DailyReportState? dailyReportState,
    WeeklyReportState? weeklyReportState,
    MonthlyReportState? monthlyReportState,
    Set<DateTime>? selectedDates,
    bool? multiSelectMode,
    ReportsLoadFailure? loadFailure,
    OvertimeFreshness? overtimeFreshness,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      focusedDay: focusedDay ?? this.focusedDay,
      selectedDay: selectedDay ?? this.selectedDay,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      workEntries: workEntries ?? this.workEntries,
      homeOfficeDays: homeOfficeDays ?? this.homeOfficeDays,
      workLocationDays: workLocationDays ?? this.workLocationDays,
      reportType: reportType ?? this.reportType,
      dailyReportState: dailyReportState ?? this.dailyReportState,
      weeklyReportState: weeklyReportState ?? this.weeklyReportState,
      monthlyReportState: monthlyReportState ?? this.monthlyReportState,
      selectedDates: selectedDates ?? this.selectedDates,
      multiSelectMode: multiSelectMode ?? this.multiSelectMode,
      loadFailure: loadFailure ?? this.loadFailure,
      overtimeFreshness: overtimeFreshness ?? this.overtimeFreshness,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        focusedDay,
        selectedDay,
        selectedMonth,
        workEntries,
        homeOfficeDays,
        workLocationDays,
        reportType,
        dailyReportState,
        weeklyReportState,
        monthlyReportState,
        selectedDates,
        multiSelectMode,
        loadFailure,
        overtimeFreshness,
      ];
}

/// Tagesbericht. [target], [worked] und [overtime] sind die Tageswerte des
/// Backends (`DailyStatDto`) bzw. lokal von `calculateDailyStat` (#535):
/// Soll, geleistet (netto, Abwesenheit mit dem Tagessoll) und
/// geleistet − Soll + manuelle Überstunden. Ein heute laufender Eintrag zählt
/// darin mit 0; die Oberfläche zeigt ihn live (#404).
///
/// [workTime], [breakTime] und [totalTime] sind die Rohsummen der Einträge
/// (brutto, Pausen, brutto − Pausen).
class DailyReportState extends Equatable {
  final List<WorkEntryEntity> entries;
  final Duration workTime;
  final Duration breakTime;
  final Duration totalTime;
  final Duration target;
  final Duration worked;
  final Duration overtime;

  const DailyReportState({
    required this.entries,
    required this.workTime,
    required this.breakTime,
    required this.totalTime,
    this.target = Duration.zero,
    this.worked = Duration.zero,
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
  List<Object?> get props =>
      [entries, workTime, breakTime, totalTime, target, worked, overtime];
}
