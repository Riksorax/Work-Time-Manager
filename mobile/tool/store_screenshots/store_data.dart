// Beispieldaten der Play-Store-Screenshots (#559).
//
// Eine erfundene Person mit 40-h-Woche (Mo–Fr, NRW) über 2025 und 2026 bis
// zum festen Stichtag [storeNow]. Alle Bilder lesen aus diesem einen
// Datensatz: das Dashboard und die lokalen Berichte über das
// In-Memory-Repository, die Backend-Antworten (Trend, Jahreswerte,
// Jahresvergleich, Urlaubsbilanz, Insights) über [StoreApi], das sie mit der
// kanonischen Berichtsrechnung der App (`report_calculator.dart`, Port des
// Backends) aus denselben Einträgen bildet. Keine echten Nutzerdaten.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/data/models/trend_report_model.dart';
import 'package:flutter_work_time/data/models/yearly_comparison_model.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/bundesland.dart';
import 'package:flutter_work_time/domain/entities/insights_report.dart';
import 'package:flutter_work_time/domain/entities/trend_report.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/yearly_comparison.dart';
import 'package:flutter_work_time/domain/utils/entry_day.dart';
import 'package:flutter_work_time/domain/utils/german_holidays.dart';
import 'package:flutter_work_time/domain/utils/insights_utils.dart';
import 'package:flutter_work_time/domain/utils/iso_week.dart';
import 'package:flutter_work_time/domain/utils/report_calculator.dart';

/// Feste Uhr aller Bilder: Mittwoch, 11.11.2026, 16:40 Uhr (laufender Tag
/// mit Timer kurz nach dem Tagessoll, die Vorwoche KW 45 ist vollständig).
final storeNow = DateTime(2026, 11, 11, 16, 40);
final storeToday = DateTime(storeNow.year, storeNow.month, storeNow.day);

/// Tag, den Tages- und Wochenbericht zeigen (Mittwoch der KW 45).
final storeReportDay = DateTime(2026, 11, 4);

const storeSettings = ReportSettings(
  weeklyTargetHours: 40,
  workdays: [1, 2, 3, 4, 5],
);

const storeBundesland = Bundesland.nordrheinWestfalen;
const storeVacationDaysPerYear = 30;

/// Texte im Datensatz, die ein Nutzer selbst eingibt (Orte, Pausennamen):
/// je Sprache, damit die englischen Bilder keine deutschen Eingaben zeigen.
class StoreTexts {
  const StoreTexts({
    required this.office,
    required this.client,
    required this.lunch,
    required this.coffee,
    required this.warehouse,
    required this.fair,
  });

  final String office;
  final String client;
  final String lunch;
  final String coffee;

  /// Weitere Orte (gelegentlich), erscheinen als Vorschläge im Blatt
  /// „Arbeitsorte“.
  final String warehouse;
  final String fair;
}

const storeTextsDe = StoreTexts(
  office: 'Büro',
  client: 'Kunde',
  lunch: 'Mittagspause',
  coffee: 'Kaffeepause',
  warehouse: 'Lager',
  fair: 'Messe',
);

const storeTextsEn = StoreTexts(
  office: 'Office',
  client: 'Client',
  lunch: 'Lunch',
  coffee: 'Coffee break',
  warehouse: 'Warehouse',
  fair: 'Trade fair',
);

StoreTexts storeTextsFor(String locale) =>
    locale == 'en' ? storeTextsEn : storeTextsDe;

String _pad(int n) => n.toString().padLeft(2, '0');

String storeDayKey(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

bool _inRange(DateTime d, (int, int, int) from, (int, int, int) to) {
  final a = DateTime(from.$1, from.$2, from.$3);
  final b = DateTime(to.$1, to.$2, to.$3);
  return !d.isBefore(a) && !d.isAfter(b);
}

/// Urlaub: 2025 alle 30 Tage, 2026 bis zum Stichtag 26 von 30.
bool _isVacation(DateTime d) =>
    _inRange(d, (2025, 3, 3), (2025, 3, 7)) ||
    _inRange(d, (2025, 4, 22), (2025, 4, 25)) ||
    _inRange(d, (2025, 7, 21), (2025, 8, 8)) ||
    _inRange(d, (2025, 12, 22), (2025, 12, 31)) ||
    _inRange(d, (2026, 2, 16), (2026, 2, 20)) ||
    _inRange(d, (2026, 4, 7), (2026, 4, 10)) ||
    _inRange(d, (2026, 5, 15), (2026, 5, 15)) ||
    _inRange(d, (2026, 6, 5), (2026, 6, 5)) ||
    _inRange(d, (2026, 8, 3), (2026, 8, 14)) ||
    _inRange(d, (2026, 10, 12), (2026, 10, 16));

/// Krank: 2025 fünf Tage, 2026 drei Tage.
bool _isSick(DateTime d) =>
    _inRange(d, (2025, 1, 20), (2025, 1, 22)) ||
    _inRange(d, (2025, 11, 17), (2025, 11, 18)) ||
    _inRange(d, (2026, 3, 10), (2026, 3, 11)) ||
    _inRange(d, (2026, 9, 22), (2026, 9, 22));

DateTime _at(DateTime d, int minutes) =>
    DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);

/// Arbeitstag nach festem Muster mit etwas Streuung (Zufall mit dem Datum als
/// Startwert, also bei jedem Lauf gleich): Di und Do Home-Office, Mo und Fr
/// im Büro (montags in geraden Wochen auch im Lager, am ersten Freitag im
/// Monat auf der Messe), mittwochs Büro und nachmittags beim Kunden. Freitags kürzer,
/// mittwochs länger, im Schnitt ein paar Minuten über dem Soll.
WorkEntryEntity _workDay(DateTime d, StoreTexts t) {
  final rnd = Random(d.year * 10000 + d.month * 100 + d.day);
  final wd = d.weekday;
  final start = 7 * 60 + 30 + rnd.nextInt(5) * 10 + (wd == 1 ? 10 : 0);
  const extra = {1: 10, 2: 5, 3: 20, 4: 0, 5: -15};
  // Wochen mit mehr oder weniger Arbeit (je Woche gleich, im Mittel 0).
  final monday = DateTime(d.year, d.month, d.day - (wd - 1));
  final weekRnd = Random(monday.year * 10000 + monday.month * 100 + monday.day);
  final weekShift = weekRnd.nextInt(5) * 15 - 30;
  final net = 8 * 60 + extra[wd]! + weekShift + rnd.nextInt(5) * 5 - 10;
  final lunchStart = 12 * 60 + rnd.nextInt(4) * 10;
  final lunch = wd == 3 ? 45 : 30;
  final coffee = wd == 1 || wd == 3;
  final breakTotal = lunch + (coffee ? 15 : 0);
  final end = start + net + breakTotal;
  final homeOffice = wd == 2 || wd == 4;
  return WorkEntryEntity(
    id: storeDayKey(d),
    date: d,
    workStart: _at(d, start),
    workEnd: _at(d, end),
    breaks: [
      BreakEntity(
        id: 'l${storeDayKey(d)}',
        name: t.lunch,
        start: _at(d, lunchStart),
        end: _at(d, lunchStart + lunch),
      ),
      if (coffee)
        BreakEntity(
          id: 'c${storeDayKey(d)}',
          name: t.coffee,
          start: _at(d, 15 * 60),
          end: _at(d, 15 * 60 + 15),
        ),
    ],
    isHomeOffice: homeOffice,
    workLocations: homeOffice
        ? const []
        : wd == 3
            ? [t.office, t.client]
            : wd == 1 && isoWeekNumber(d).isEven
                ? [t.office, t.warehouse]
                : wd == 5 && d.day <= 7
                    ? [t.office, t.fair]
                    : [t.office],
  );
}

/// Der laufende Tag [storeToday]: Start 7:52, Mittagspause 12:10–12:40,
/// Timer läuft (kein Ende). Vormittags Home-Office, danach Büro und Kunde.
WorkEntryEntity storeTodayEntry(StoreTexts t) => WorkEntryEntity(
      id: storeDayKey(storeToday),
      date: storeToday,
      workStart: _at(storeToday, 7 * 60 + 52),
      breaks: [
        BreakEntity(
          id: 'l-today',
          name: t.lunch,
          start: _at(storeToday, 12 * 60 + 10),
          end: _at(storeToday, 12 * 60 + 40),
        ),
      ],
      isHomeOffice: true,
      workLocations: [t.office, t.client],
    );

/// Alle Einträge vom 01.01.2025 bis zum Vortag von [storeToday], dazu der
/// laufende Tag. Schlüssel `yyyy-MM-dd`.
Map<String, WorkEntryEntity> buildStoreEntries(StoreTexts t) {
  final holidays = {
    for (final y in [2025, 2026])
      for (final h in getGermanHolidays(y, storeBundesland)) storeDayKey(h),
  };
  final result = <String, WorkEntryEntity>{};
  for (var d = DateTime(2025, 1, 1);
      d.isBefore(storeToday);
      d = DateTime(d.year, d.month, d.day + 1)) {
    if (d.weekday > 5) continue;
    final key = storeDayKey(d);
    final WorkEntryType? absence = holidays.contains(key)
        ? WorkEntryType.holiday
        : _isVacation(d)
            ? WorkEntryType.vacation
            : _isSick(d)
                ? WorkEntryType.sick
                : null;
    result[key] = absence != null
        ? WorkEntryEntity(id: key, date: d, type: absence)
        : _workDay(d, t);
  }
  final today = storeTodayEntry(t);
  result[today.id] = today;
  return result;
}

/// Abgeschlossene Einträge (ohne den laufenden Tag), Grundlage der
/// Backend-Antworten: der Server rechnet den offenen Eintrag nicht mit.
List<WorkEntryEntity> _closed(Map<String, WorkEntryEntity> entries) => [
      for (final e in entries.values)
        if (entryDay(e).isBefore(storeToday)) e,
    ];

/// Gleitzeit-Saldo am Morgen von [storeToday]: Summe der Tages-Überstunden
/// 2026 (der Saldo 2025 wurde zum Jahreswechsel ausgezahlt).
Duration storeOvertimeBalance(Map<String, WorkEntryEntity> entries) {
  var sum = Duration.zero;
  final closed = _closed(entries).where((e) => entryDay(e).year == 2026);
  final days = {for (final e in closed) entryDay(e)};
  for (final d in days) {
    sum += calculateDailyStat(closed.toList(), d, storeSettings).overtime;
  }
  return sum;
}

String _utcMidnight(DateTime d) =>
    '${d.year}-${_pad(d.month)}-${_pad(d.day)}T00:00:00+00:00';

String _weekKey(DateTime d) => '${isoWeekYear(d)}-W${_pad(isoWeekNumber(d))}';

/// Backend-Antworten aus dem Datensatz. Nicht abgebildete Methoden werfen
/// (`Fake`): Tages-, Wochen- und Monatsbericht kommen dann aus der lokalen
/// kanonischen Rechnung der App (gleiche Werte wie das Backend).
class StoreApi extends Fake implements ApiClient {
  StoreApi(this.entries);

  final Map<String, WorkEntryEntity> entries;

  late final List<WorkEntryEntity> _done = _closed(entries);

  Duration get balance => storeOvertimeBalance(entries);

  List<WorkEntryEntity> _month(int year, int month) => [
        for (final e in _done)
          if (entryDay(e).year == year && entryDay(e).month == month) e,
      ];

  // ── Trend (#531, #532) ─────────────────────────────────────────────────

  @override
  Future<TrendReport> getTrendReport(
      DateTime date, TrendGranularity granularity,
      {String? profileId}) async {
    final ref = DateTime(date.year, date.month, date.day);
    final buckets = <Map<String, dynamic>>[];
    var cumulative = 0;
    for (var i = 0; i < 12; i++) {
      final back = 11 - i;
      final DateTime start;
      final DateTime end;
      final String key;
      final int netMs;
      final int overtimeMs;
      final bool hasData;
      if (granularity == TrendGranularity.week) {
        start = DateTime(
            ref.year, ref.month, ref.day - (ref.weekday - 1) - 7 * back);
        end = DateTime(start.year, start.month, start.day + 6);
        key = _weekKey(start);
        final w = calculateWeeklyReport(_done, start, storeSettings);
        netMs = (w.totalWorked - w.totalBreaks).inMilliseconds;
        overtimeMs = w.overtime.inMilliseconds;
        hasData = w.days.isNotEmpty;
      } else {
        start = DateTime(ref.year, ref.month - back, 1);
        end = DateTime(ref.year, ref.month - back + 1, 0);
        key = '${start.year}-${_pad(start.month)}';
        final list = _month(start.year, start.month);
        final m =
            calculateMonthlyReport(list, start, storeSettings, Duration.zero);
        netMs = (m.totalWorked - m.totalBreaks).inMilliseconds;
        overtimeMs = m.monthlyOvertime.inMilliseconds;
        hasData = list.isNotEmpty;
      }
      cumulative += overtimeMs;
      buckets.add({
        'key': key,
        'start': _utcMidnight(start),
        'end': _utcMidnight(end),
        'workedMs': netMs,
        'targetMs': netMs - overtimeMs,
        'overtimeMs': overtimeMs,
        'cumulativeOvertimeMs': cumulative,
        'hasData': hasData,
      });
    }

    // Wochen-Trend: letzte abgeschlossene Woche gegen das Mittel der vier
    // Wochen davor (Regel wie im Backend).
    final thisMonday =
        DateTime(ref.year, ref.month, ref.day - (ref.weekday - 1));
    WeeklyReport week(int back) => calculateWeeklyReport(
        _done,
        DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7 * back),
        storeSettings);
    int net(WeeklyReport w) => (w.totalWorked - w.totalBreaks).inMilliseconds;
    final last = week(1);
    final compared = [for (var b = 2; b <= 5; b++) week(b)]
        .where((w) => w.days.isNotEmpty)
        .toList();
    final average =
        (compared.map(net).reduce((a, b) => a + b) / compared.length).round();

    // Prognose zum Jahresende: Saldo plus mittlere Wochen-Überstunden der
    // letzten acht abgeschlossenen Wochen mal Restwochen.
    final recent = [for (var b = 1; b <= 8; b++) week(b)];
    final avgOvertime =
        (recent.map((w) => w.overtime.inMilliseconds).reduce((a, b) => a + b) /
                recent.length)
            .round();
    final yearEnd = DateTime(ref.year, 12, 31);
    final remainingWeeks =
        DateTime.utc(yearEnd.year, yearEnd.month, yearEnd.day)
                .difference(DateTime.utc(ref.year, ref.month, ref.day))
                .inDays /
            7;
    final current = balance.inMilliseconds;

    return trendReportFromJson({
      'granularity': granularity.apiValue,
      'buckets': buckets,
      'weeklyTrend': {
        'lastWeekKey': _weekKey(last.start),
        'lastWeekWorkedMs': net(last),
        'averageWorkedMs': average,
        'deltaMs': net(last) - average,
        'comparedWeeks': compared.length,
      },
      'forecast': {
        'targetDate': '${ref.year}-12-31',
        'currentBalanceMs': current,
        'averageWeeklyOvertimeMs': avgOvertime,
        'weeksUsed': recent.length,
        'remainingWeeks': remainingWeeks,
        'projectedBalanceMs': current + (avgOvertime * remainingWeeks).round(),
      },
    }, requested: granularity);
  }

  // ── Jahreswerte und Jahresvergleich (#530) ─────────────────────────────

  Map<String, dynamic> _summary(int year, DateTime? until) {
    var worked = 0, breaks = 0, overtime = 0, workDays = 0;
    var vacation = 0, sick = 0, holiday = 0;
    final months = <Map<String, dynamic>>[];
    for (var m = 1; m <= 12; m++) {
      final list = [
        for (final e in _month(year, m))
          if (until == null ||
              !DateTime(year, entryDay(e).month, entryDay(e).day)
                  .isAfter(DateTime(year, until.month, until.day)))
            e,
      ];
      final r = calculateMonthlyReport(
          list, DateTime(year, m), storeSettings, Duration.zero);
      final net = (r.totalWorked - r.totalBreaks).inMilliseconds;
      worked += net;
      breaks += r.totalBreaks.inMilliseconds;
      overtime += r.monthlyOvertime.inMilliseconds;
      workDays += r.workDays;
      vacation += list.where((e) => e.type == WorkEntryType.vacation).length;
      sick += list.where((e) => e.type == WorkEntryType.sick).length;
      holiday += list.where((e) => e.type == WorkEntryType.holiday).length;
      months.add({
        'month': m,
        'workedMs': net,
        'overtimeMs': r.monthlyOvertime.inMilliseconds,
        'workDays': r.workDays,
      });
    }
    return {
      'year': year,
      'hasData': workDays > 0,
      'totalWorkedMs': worked,
      'totalBreaksMs': breaks,
      'overtimeMs': overtime,
      'workDays': workDays,
      'vacationDays': vacation,
      'sickDays': sick,
      'holidayDays': holiday,
      'months': months,
    };
  }

  @override
  Future<YearlyComparison> getYearlyComparison(int year,
      {DateTime? until, String? profileId}) async {
    final cur = _summary(year, until);
    final prev = _summary(year - 1, until);
    int d(String k) => (cur[k] as int) - (prev[k] as int);
    final prevWorked = prev['totalWorkedMs'] as int;
    return yearlyComparisonFromJson({
      'until': until == null ? null : '${_pad(until.month)}-${_pad(until.day)}',
      'current': cur,
      'previous': prev,
      'delta': prev['hasData'] == true
          ? {
              'workedMs': d('totalWorkedMs'),
              'workedPercent': prevWorked == 0
                  ? null
                  : (d('totalWorkedMs') / prevWorked * 1000).round() / 10,
              'overtimeMs': d('overtimeMs'),
              'workDays': d('workDays'),
              'vacationDays': d('vacationDays'),
              'sickDays': d('sickDays'),
              'holidayDays': d('holidayDays'),
            }
          : null,
    }, requestedYear: year);
  }

  // ── Urlaubsbilanz (#535) ───────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getYearlyLeave(int year,
      {String? profileId}) async {
    final inYear = _done.where((e) => entryDay(e).year == year);
    final taken = inYear.where((e) => e.type == WorkEntryType.vacation).length;
    return {
      'year': year,
      'vacationDaysPerYear': storeVacationDaysPerYear,
      'vacationDaysTaken': taken,
      'vacationDaysRemaining': storeVacationDaysPerYear - taken,
      'sickDays': inYear.where((e) => e.type == WorkEntryType.sick).length,
    };
  }

  // ── Insights (#537) ────────────────────────────────────────────────────

  /// Wie das Backend: dieselben Regeln wie die lokale Rechnung der App
  /// (`calculateInsightsReport`, belegt über `insights_parity_tz_test`).
  @override
  Future<InsightsReport> getInsightsReport(DateTime date, String timeZone,
      {String? profileId}) async {
    final window = insightsWindow(date);
    return calculateInsightsReport(
      entries: [
        for (final e in _done)
          if (!entryDay(e).isBefore(window.from) &&
              !entryDay(e).isAfter(window.to))
            e,
      ],
      today: date,
      workdays: storeSettings.workdays,
      targetWeeklyHours: storeSettings.weeklyTargetHours,
    );
  }
}
