/// Lokale Berichtsrechnung (Tag, Woche, Monat) im Gleichschritt mit dem
/// Backend (#535).
///
/// Port von `ReportCalculator` im Backend (`CalculateDailyStat`,
/// `CalculateWeeklyReport`, `CalculateMonthlyReport`, `SumPeriod`,
/// `DailyTargetMs`); das Web rechnet identisch
/// (`report-calculator.ts`). Abgesichert über die gemeinsamen Testfälle
/// `testdata/report-parity/cases.json`
/// (`test/domain/utils/report_calculator_parity_tz_test.dart`).
///
/// Regeln (kanonisch, siehe `server/CLAUDE.md`, „Rechenlogik“):
/// - Arbeit brutto (Start→Ende) und Pausen getrennt; Einträge ohne Ende
///   zählen brutto 0, ihre abgeschlossenen Pausen aber mit.
/// - Urlaub/Krank/Feiertag zählen mit dem Tagessoll als geleistet, als
///   Arbeitstag und immer als Soll, auch an einem freien Wochentag.
/// - Soll = Zahl der Soll-Tage × Tagessoll; Soll-Tage sind Tage mit
///   Arbeitseintrag mit Start an einem Vertrags-Wochentag und jeder Tag mit
///   Abwesenheit, jeder Tag höchstens einmal.
/// - Überstunden = netto − Soll + manuelle Überstunden.
/// - Monats-Gesamtüberstunden = gespeicherter Gleitzeit-Saldo.
///
/// Reine Dart-Funktionen ohne Uhr und ohne Zeitzonen-Abhängigkeit: Der Tag
/// eines Eintrags kommt aus [entryDay], Berichtstage sind lokale
/// Mitternacht des Kalendertags.
library;

import '../entities/work_entry_entity.dart';
import 'date_utils.dart';
import 'entry_day.dart';
import 'iso_week.dart';

/// Einstellungen, die die Berichtsrechnung braucht.
class ReportSettings {
  /// Wochenstunden laut Vertrag.
  final double weeklyTargetHours;

  /// Vertrags-Wochentage, ISO (1 = Mo … 7 = So, wie `DateTime.weekday`).
  final List<int> workdays;

  const ReportSettings({
    required this.weeklyTargetHours,
    required this.workdays,
  });
}

/// Tageswerte (Backend `DailyStatDto`).
class DailyStat {
  final Duration target;
  final Duration worked;
  final Duration overtime;

  const DailyStat({
    required this.target,
    required this.worked,
    required this.overtime,
  });
}

/// Ein Berichtstag (Backend `ReportDayDto`); [worked] ist **brutto**,
/// Abwesenheit mit dem Tagessoll.
class ReportDay {
  /// Lokale Mitternacht des Kalendertags.
  final DateTime date;
  final Duration worked;

  const ReportDay({required this.date, required this.worked});
}

/// Eine ISO-Woche im Monatsbericht (Backend `ReportWeekDto`); brutto.
class ReportWeek {
  final int weekNumber;
  final Duration totalWorked;

  const ReportWeek({required this.weekNumber, required this.totalWorked});
}

/// Wochenbericht (Backend `WeeklyReportDto`).
class WeeklyReport {
  final int weekNumber;

  /// Montag der Woche (lokale Mitternacht).
  final DateTime start;

  /// Sonntag der Woche (lokale Mitternacht).
  final DateTime end;

  /// Brutto (Start→Ende), Abwesenheit mit dem Tagessoll.
  final Duration totalWorked;
  final Duration totalBreaks;
  final int workDays;

  /// Netto ÷ Arbeitstage in Millisekunden, ungerundet wie im Backend.
  final double avgPerDayMs;
  final Duration overtime;
  final List<ReportDay> days;

  const WeeklyReport({
    required this.weekNumber,
    required this.start,
    required this.end,
    required this.totalWorked,
    required this.totalBreaks,
    required this.workDays,
    required this.avgPerDayMs,
    required this.overtime,
    required this.days,
  });
}

/// Monatsbericht (Backend `MonthlyReportDto`).
class MonthlyReport {
  /// Erster Tag des Monats (lokale Mitternacht).
  final DateTime month;

  /// Brutto (Start→Ende), Abwesenheit mit dem Tagessoll.
  final Duration totalWorked;
  final Duration totalBreaks;
  final int workDays;

  /// Netto ÷ Arbeitstage in Millisekunden, ungerundet wie im Backend.
  final double avgPerDayMs;

  /// Netto ÷ Zahl der ISO-Wochen mit mindestens einem Berichtstag.
  final double avgPerWeekMs;

  /// Überstunden des Monats (netto − Soll + manuell).
  final Duration monthlyOvertime;

  /// Gespeicherter Gleitzeit-Saldo; enthält den laufenden Monat schon.
  final Duration totalOvertime;

  /// Nach Wochennummer aufsteigend (wie das Backend; im Januar steht eine
  /// KW 53 des Vorjahres deshalb hinter KW 1).
  final List<ReportWeek> weeks;
  final List<ReportDay> days;

  const MonthlyReport({
    required this.month,
    required this.totalWorked,
    required this.totalBreaks,
    required this.workDays,
    required this.avgPerDayMs,
    required this.avgPerWeekMs,
    required this.monthlyOvertime,
    required this.totalOvertime,
    required this.weeks,
    required this.days,
  });
}

/// Tagessoll = Wochenstunden ÷ Zahl der Arbeitstage, auf die volle Minute
/// gerundet (.5 von der Null weg, wie `DailyTargetMs` im Backend). Ohne
/// Arbeitstage 0. Gleiche Rechenreihenfolge wie das Backend, damit die
/// Gleitkomma-Zwischenwerte übereinstimmen.
Duration reportDailyTarget(ReportSettings settings) {
  if (settings.workdays.isEmpty) return Duration.zero;
  final minutes =
      settings.weeklyTargetHours * 3600000 / settings.workdays.length / 60000;
  // `double.round()` rundet .5 von der Null weg (= MidpointRounding.AwayFromZero).
  return Duration(minutes: minutes.round());
}

/// Tageswerte für [date] aus den Einträgen [entries] (Backend
/// `CalculateDailyStat`). Soll = Tagessoll an Vertrags-Wochentagen oder bei
/// einem Abwesenheits-Eintrag, sonst 0.
DailyStat calculateDailyStat(
  List<WorkEntryEntity> entries,
  DateTime date,
  ReportSettings settings,
) {
  final day = DateTime(date.year, date.month, date.day);
  final daily = reportDailyTarget(settings);
  final dayEntries = entries.where((e) => entryDay(e) == day).toList();
  final target = settings.workdays.contains(day.weekday) ||
          dayEntries.any((e) => e.type != WorkEntryType.work)
      ? daily
      : Duration.zero;

  var worked = Duration.zero;
  var manual = Duration.zero;
  for (final entry in dayEntries) {
    worked += entry.type != WorkEntryType.work ? target : _netWork(entry);
    manual += entry.manualOvertime ?? Duration.zero;
  }
  return DailyStat(
    target: target,
    worked: worked,
    overtime: worked - target + manual,
  );
}

/// Wochenbericht der ISO-Woche von [date] (Backend `CalculateWeeklyReport`).
/// Filtert [entries] selbst auf die Woche (Montag bis Sonntag).
WeeklyReport calculateWeeklyReport(
  List<WorkEntryEntity> entries,
  DateTime date,
  ReportSettings settings,
) {
  final day = DateTime(date.year, date.month, date.day);
  final start = addCalendarDays(day, -(day.weekday - 1));
  final end = addCalendarDays(start, 6);
  final t = _sumPeriod(
    entries.where((e) {
      final d = entryDay(e);
      return !d.isBefore(start) && !d.isAfter(end);
    }),
    settings,
  );
  final workDays = t.workDays.length;
  return WeeklyReport(
    weekNumber: isoWeekNumber(day),
    start: start,
    end: end,
    totalWorked: t.grossWorked,
    totalBreaks: t.breaks,
    workDays: workDays,
    avgPerDayMs: workDays > 0 ? t.netWorked.inMilliseconds / workDays : 0,
    overtime: t.overtime,
    days: t.sortedDays,
  );
}

/// Monatsbericht (Backend `CalculateMonthlyReport`). [entries] sind die
/// Einträge des Monats von [monthRef] (filtert nicht), [storedOvertime] ist
/// der gespeicherte Gleitzeit-Saldo.
MonthlyReport calculateMonthlyReport(
  List<WorkEntryEntity> entries,
  DateTime monthRef,
  ReportSettings settings,
  Duration storedOvertime,
) {
  final t = _sumPeriod(entries, settings);
  final days = t.sortedDays;

  // Jeder Tag gehört zu genau einer ISO-KW; Summen je KW aus der Tages-Map.
  final weekTotals = <int, Duration>{};
  for (final d in days) {
    final week = isoWeekNumber(d.date);
    weekTotals[week] = (weekTotals[week] ?? Duration.zero) + d.worked;
  }
  final weekNumbers = weekTotals.keys.toList()..sort();
  final numWeeks = weekNumbers.length;
  final workDays = t.workDays.length;
  final netMs = t.netWorked.inMilliseconds;

  return MonthlyReport(
    month: DateTime(monthRef.year, monthRef.month),
    totalWorked: t.grossWorked,
    totalBreaks: t.breaks,
    workDays: workDays,
    avgPerDayMs: workDays > 0 ? netMs / workDays : 0,
    avgPerWeekMs: numWeeks > 0 ? netMs / numWeeks : 0,
    monthlyOvertime: t.overtime,
    totalOvertime: storedOvertime,
    weeks: [
      for (final w in weekNumbers)
        ReportWeek(weekNumber: w, totalWorked: weekTotals[w]!),
    ],
    days: days,
  );
}

/// Summen eines Zeitraums (Backend `PeriodTotals`).
class _PeriodTotals {
  final Duration grossWorked;
  final Duration breaks;
  final Duration manual;
  final Duration target;
  final Set<DateTime> workDays;
  final Map<DateTime, Duration> dayMap;

  const _PeriodTotals({
    required this.grossWorked,
    required this.breaks,
    required this.manual,
    required this.target,
    required this.workDays,
    required this.dayMap,
  });

  Duration get netWorked => grossWorked - breaks;

  Duration get overtime => netWorked - target + manual;

  List<ReportDay> get sortedDays {
    final keys = dayMap.keys.toList()..sort();
    return [for (final k in keys) ReportDay(date: k, worked: dayMap[k]!)];
  }
}

/// Rechenkern der Berichte (Backend `SumPeriod`); filtert nicht.
_PeriodTotals _sumPeriod(
  Iterable<WorkEntryEntity> entries,
  ReportSettings settings,
) {
  final daily = reportDailyTarget(settings);
  var gross = Duration.zero;
  var breaks = Duration.zero;
  var manual = Duration.zero;
  final workDays = <DateTime>{};
  final absenceDays = <DateTime>{};
  final dayMap = <DateTime, Duration>{};

  for (final entry in entries) {
    final key = entryDay(entry);
    Duration worked;
    if (entry.type != WorkEntryType.work) {
      worked = daily;
      workDays.add(key);
      absenceDays.add(key);
    } else {
      breaks += entry.totalBreakTime;
      worked = entry.totalWorkTime;
      if (entry.workStart != null) workDays.add(key);
    }
    gross += worked;
    manual += entry.manualOvertime ?? Duration.zero;
    dayMap[key] = (dayMap[key] ?? Duration.zero) + worked;
  }

  final targetDays = workDays
      .where((d) =>
          absenceDays.contains(d) || settings.workdays.contains(d.weekday))
      .length;
  return _PeriodTotals(
    grossWorked: gross,
    breaks: breaks,
    manual: manual,
    target: daily * targetDays,
    workDays: workDays,
    dayMap: dayMap,
  );
}

/// Netto eines Arbeitseintrags, nie negativ; ohne Start oder Ende 0
/// (Backend `NetWorkMs`).
Duration _netWork(WorkEntryEntity entry) {
  if (entry.type != WorkEntryType.work ||
      entry.workStart == null ||
      entry.workEnd == null) {
    return Duration.zero;
  }
  final net = entry.totalWorkTime - entry.totalBreakTime;
  return net > Duration.zero ? net : Duration.zero;
}
