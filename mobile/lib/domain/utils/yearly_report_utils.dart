import '../entities/work_entry_entity.dart';
import 'entry_day.dart';
import 'iso_week.dart';
import 'report_calculator.dart';

/// Monatswerte des Jahresberichts über die kanonische Berichtsrechnung (#530;
/// lokaler Ersatz bei Ladefehler und Gast-Modus): dieselben Felder wie die
/// `months` von `GET /api/reports/yearly-comparison/{year}`, also
/// [calculateMonthlyReport] je Monat (netto = Arbeitszeit − Pausen,
/// Abwesenheit mit Tagessoll als gearbeitet und Soll, Überstunden des Monats
/// inkl. manueller, Arbeitstage). Urlaubs-, Krankheits- und Feiertage zählen
/// wie im Backend je Eintrag einen Tag (auch am Wochenende).
///
/// [entriesForMonth] sind die Einträge des Monats [month] von [year]; es wird
/// nicht gefiltert (wie [calculateMonthlyReport]).
MonthSummary calculateCanonicalMonthSummary({
  required int year,
  required int month,
  required List<WorkEntryEntity> entriesForMonth,
  required ReportSettings settings,
}) {
  final r = calculateMonthlyReport(
      entriesForMonth, DateTime(year, month), settings, Duration.zero);
  int count(WorkEntryType type) =>
      entriesForMonth.where((e) => e.type == type).length;
  return MonthSummary(
    month: month,
    netWorkDuration: r.totalWorked - r.totalBreaks,
    overtime: r.monthlyOvertime,
    workDays: r.workDays,
    vacationDays: count(WorkEntryType.vacation),
    sickDays: count(WorkEntryType.sick),
    holidayDays: count(WorkEntryType.holiday),
  );
}

/// Aggregierte Kennzahlen für einen einzelnen Monat innerhalb des
/// Jahresberichts (siehe #136).
class MonthSummary {
  final int month; // 1-12
  final Duration netWorkDuration;
  final Duration overtime;
  final int workDays;
  final int vacationDays;
  final int sickDays;
  final int holidayDays;

  const MonthSummary({
    required this.month,
    required this.netWorkDuration,
    required this.overtime,
    required this.workDays,
    required this.vacationDays,
    required this.sickDays,
    required this.holidayDays,
  });

  MonthSummary copyWith({Duration? overtime}) {
    return MonthSummary(
      month: month,
      netWorkDuration: netWorkDuration,
      overtime: overtime ?? this.overtime,
      workDays: workDays,
      vacationDays: vacationDays,
      sickDays: sickDays,
      holidayDays: holidayDays,
    );
  }

  static MonthSummary empty(int month) => MonthSummary(
        month: month,
        netWorkDuration: Duration.zero,
        overtime: Duration.zero,
        workDays: 0,
        vacationDays: 0,
        sickDays: 0,
        holidayDays: 0,
      );
}

/// Berechnet die Kennzahlen eines Monats für den Jahresbericht aus dessen
/// Arbeitseinträgen.
///
/// Spiegelt bewusst dieselbe Wochen-Deckelung wie der bestehende
/// Monatsbericht (`ReportsViewModel._calculateMonthlyReport`) — Zusatztage
/// an Wochentagen außerhalb von [workdays] erhöhen das Soll nicht (#217).
/// Eigenständige Implementierung statt Wiederverwendung der privaten
/// ViewModel-Methode, um bestehendes, produktiv genutztes Verhalten nicht
/// anzufassen.
MonthSummary calculateMonthSummary({
  required int month,
  required List<WorkEntryEntity> entriesForMonth,
  required List<int> workdays,
  required double targetWeeklyHours,
}) {
  final totalNetWorkDuration = entriesForMonth.fold<Duration>(
      Duration.zero, (prev, e) => prev + e.effectiveWorkDuration);

  final uniqueWorkDays = entriesForMonth
      .where((e) => e.workStart != null)
      .map(entryDay)
      .toSet()
      .length;

  final targetDailyHours =
      workdays.isNotEmpty ? targetWeeklyHours / workdays.length : 0.0;

  final Map<int, Set<DateTime>> weekToWorkDays = {};
  for (final entry in entriesForMonth) {
    if (entry.workStart != null) {
      final dayOnly = entryDay(entry);
      final weekNum = isoWeekNumber(dayOnly);
      weekToWorkDays.putIfAbsent(weekNum, () => {}).add(dayOnly);
    }
  }
  var effectiveWorkDays = 0;
  for (final days in weekToWorkDays.values) {
    effectiveWorkDays += days.where((d) => workdays.contains(d.weekday)).length;
  }

  final targetDuration = Duration(
    microseconds:
        (targetDailyHours * effectiveWorkDays * Duration.microsecondsPerHour)
            .round(),
  );

  final manualOvertime = entriesForMonth.fold<Duration>(
      Duration.zero, (prev, e) => prev + (e.manualOvertime ?? Duration.zero));

  var vacationDays = 0;
  var sickDays = 0;
  var holidayDays = 0;
  for (final entry in entriesForMonth) {
    switch (entry.type) {
      case WorkEntryType.vacation:
        vacationDays++;
        break;
      case WorkEntryType.sick:
        sickDays++;
        break;
      case WorkEntryType.holiday:
        holidayDays++;
        break;
      case WorkEntryType.work:
        break;
    }
  }

  return MonthSummary(
    month: month,
    netWorkDuration: totalNetWorkDuration,
    overtime: totalNetWorkDuration - targetDuration + manualOvertime,
    workDays: uniqueWorkDays,
    vacationDays: vacationDays,
    sickDays: sickDays,
    holidayDays: holidayDays,
  );
}
