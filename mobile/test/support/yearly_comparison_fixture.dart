import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/data/models/yearly_comparison_model.dart';
import 'package:flutter_work_time/domain/entities/yearly_comparison.dart';
import 'package:flutter_work_time/presentation/state/yearly_comparison_state.dart';
import 'package:flutter_work_time/presentation/view_models/yearly_comparison_view_model.dart';

/// Antworten von `GET /api/reports/yearly-comparison/{year}?until=MM-dd`
/// (#530) im Format des Backend-DTOs (`YearlyComparisonDto`). Dieselben
/// Jahreswerte wie `web/e2e/yearly-comparison-data.ts`, damit Web und Mobile
/// vergleichbar sind. Reine Testdaten; die echte Rechnung testet das Backend
/// (die Differenzen stehen nur hier, damit die Daten in sich stimmig sind).

const int _hour = 3600000;
const int _minute = 60000;

typedef _Year = ({
  int worked,
  int overtime,
  int work,
  int vac,
  int sick,
  int hol
});

/// Verteilt die Jahreswerte gleichmäßig auf die Monate 1 bis [activeMonths]
/// (Rest im letzten aktiven Monat); spätere Monate sind 0 (nach dem Stichtag).
List<Map<String, dynamic>> _months(_Year? s, int activeMonths) {
  if (s == null) {
    return [
      for (var m = 1; m <= 12; m++)
        {'month': m, 'workedMs': 0, 'overtimeMs': 0, 'workDays': 0},
    ];
  }
  int share(int total, int m) {
    final base = total ~/ activeMonths;
    return m < activeMonths ? base : total - base * (activeMonths - 1);
  }

  return [
    for (var m = 1; m <= 12; m++)
      m > activeMonths
          ? {'month': m, 'workedMs': 0, 'overtimeMs': 0, 'workDays': 0}
          : {
              'month': m,
              'workedMs': share(s.worked, m),
              'overtimeMs': share(s.overtime, m),
              'workDays': share(s.work, m),
            },
  ];
}

Map<String, dynamic> _summary(int year, _Year? s, int activeMonths) => {
      'year': year,
      'hasData': s != null,
      'totalWorkedMs': s?.worked ?? 0,
      'totalBreaksMs': s != null ? 95 * _hour : 0,
      'overtimeMs': s?.overtime ?? 0,
      'workDays': s?.work ?? 0,
      'vacationDays': s?.vac ?? 0,
      'sickDays': s?.sick ?? 0,
      'holidayDays': s?.hol ?? 0,
      'months': _months(s, activeMonths),
    };

/// Antwort für [year]. [until] `MM-dd` = laufendes Jahr (beide Jahre
/// abgeschnitten), [previousEmpty] = Vorjahr ohne Einträge (`delta: null`),
/// [currentEmpty] = gewähltes Jahr ohne Einträge, [noPercent] =
/// `workedPercent: null`.
Map<String, dynamic> yearlyComparisonJson(
  int year, {
  String? until,
  bool previousEmpty = false,
  bool currentEmpty = false,
  bool noPercent = false,
}) {
  final partial = until != null;
  final activeMonths = partial ? int.parse(until.substring(0, 2)) : 12;
  final _Year? cur = currentEmpty
      ? null
      : partial
          ? (
              worked: 1498 * _hour + 30 * _minute,
              overtime: 18 * _hour + 45 * _minute,
              work: 189,
              vac: 24,
              sick: 3,
              hol: 9
            )
          : (
              worked: 1712 * _hour + 15 * _minute,
              overtime: 22 * _hour + 30 * _minute,
              work: 214,
              vac: 30,
              sick: 6,
              hol: 10
            );
  final _Year? prev = previousEmpty
      ? null
      : partial
          ? (
              worked: 1421 * _hour,
              overtime: -(4 * _hour + 15 * _minute),
              work: 183,
              vac: 27,
              sick: 7,
              hol: 9
            )
          : (
              worked: 1650 * _hour,
              overtime: 6 * _hour,
              work: 208,
              vac: 30,
              sick: 9,
              hol: 10
            );
  final delta = cur != null && prev != null
      ? {
          'workedMs': cur.worked - prev.worked,
          'workedPercent': noPercent
              ? null
              : ((cur.worked - prev.worked) / prev.worked * 1000).round() / 10,
          'overtimeMs': cur.overtime - prev.overtime,
          'workDays': cur.work - prev.work,
          'vacationDays': cur.vac - prev.vac,
          'sickDays': cur.sick - prev.sick,
          'holidayDays': cur.hol - prev.hol,
        }
      : null;
  return {
    'until': until,
    'current': _summary(year, cur, activeMonths),
    'previous': _summary(year - 1, prev, activeMonths),
    'delta': delta,
  };
}

typedef YearlyComparisonCall = ({int year, DateTime? until, String? profileId});

/// `ApiClient` nur für den Jahresvergleich: zeichnet die Aufrufe auf und
/// antwortet über [handler] (JSON wie das Backend, gelesen über die echte
/// Lesegrenze `yearlyComparisonFromJson`). Ein `Completer` im Handler hält die
/// Antwort an. [onOther] beantwortet die übrigen Methoden (Standard: Fehler).
class FakeYearlyComparisonApi extends Fake implements ApiClient {
  FakeYearlyComparisonApi(this.handler);

  Future<Map<String, dynamic>> Function(YearlyComparisonCall call) handler;

  final calls = <YearlyComparisonCall>[];

  /// Aufrufe des Jahres-Tabs (ganzes Jahr, ohne Stichtag).
  Iterable<YearlyComparisonCall> get totalsCalls =>
      calls.where((c) => c.until == null);

  @override
  Future<YearlyComparison> getYearlyComparison(int year,
      {DateTime? until, String? profileId}) async {
    final call = (year: year, until: until, profileId: profileId);
    calls.add(call);
    final json = await handler(call);
    return yearlyComparisonFromJson(json, requestedYear: year);
  }

  /// Urlaubsbilanz des Jahres-Tabs (`YearlyLeaveRows`), feste Werte.
  @override
  Future<Map<String, dynamic>> getYearlyLeave(int year,
          {String? profileId}) async =>
      {
        'year': year,
        'vacationDaysPerYear': 30,
        'vacationDaysTaken': 24,
        'vacationDaysRemaining': 6,
        'sickDays': 3,
      };
}

/// Stichtag-Text wie im Request (`MM-dd`) für die Fixture.
String untilKey(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Antwort wie das Backend für einen Aufruf (Stichtag aus dem Aufruf).
Map<String, dynamic> yearlyComparisonJsonFor(YearlyComparisonCall c) =>
    yearlyComparisonJson(c.year,
        until: c.until == null ? null : untilKey(c.until!));

/// Vergleichskarte ohne Laden (#530): für Tests, die den Jahres-Tab pumpen,
/// aber die Karte nicht prüfen. Fester Zustand, `ensureLoaded`/`reload` tun
/// nichts.
class FakeYearlyComparisonViewModel extends YearlyComparisonViewModel {
  FakeYearlyComparisonViewModel(
      [this._state = const YearlyComparisonState(
          year: 2026, status: YearlyComparisonStatus.loading)]);

  final YearlyComparisonState _state;

  @override
  YearlyComparisonState build() => _state;

  @override
  void ensureLoaded() {}

  @override
  Future<void> reload() async {}
}
