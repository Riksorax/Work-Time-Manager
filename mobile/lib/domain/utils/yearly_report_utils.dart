import 'dart:math';

import '../entities/work_entry_entity.dart';

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
/// über [workdaysPerWeek] hinaus erhöhen das Soll nicht. Eigenständige
/// Implementierung statt Wiederverwendung der privaten ViewModel-Methode,
/// um bestehendes, produktiv genutztes Verhalten nicht anzufassen.
MonthSummary calculateMonthSummary({
  required int month,
  required List<WorkEntryEntity> entriesForMonth,
  required int workdaysPerWeek,
  required double targetWeeklyHours,
}) {
  final totalNetWorkDuration = entriesForMonth.fold<Duration>(
      Duration.zero, (prev, e) => prev + e.effectiveWorkDuration);

  final uniqueWorkDays = entriesForMonth
      .where((e) => e.workStart != null)
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet()
      .length;

  final targetDailyHours =
      workdaysPerWeek > 0 ? targetWeeklyHours / workdaysPerWeek : 0.0;

  final Map<int, Set<DateTime>> weekToWorkDays = {};
  for (final entry in entriesForMonth) {
    if (entry.workStart != null) {
      final weekNum = _isoWeekNumber(entry.date);
      final dayOnly = DateTime(entry.date.year, entry.date.month, entry.date.day);
      weekToWorkDays.putIfAbsent(weekNum, () => {}).add(dayOnly);
    }
  }
  var effectiveWorkDays = 0;
  for (final days in weekToWorkDays.values) {
    effectiveWorkDays += min(days.length, workdaysPerWeek);
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

int _isoWeekNumber(DateTime date) {
  final firstWeek = DateTime(date.year, 1, 4);
  final dayOfWeek = firstWeek.weekday;
  final firstDayOfFirstWeek = firstWeek.subtract(Duration(days: dayOfWeek - 1));
  final diff = date.difference(firstDayOfFirstWeek).inDays;
  return (diff / 7).floor() + 1;
}
