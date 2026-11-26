import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_work_time/data/repositories/hybrid_analytics_repository.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';

import '../../support/analytics_fixture.dart';
import '../../support/api_backed_work_repository.dart';
import '../../support/timezone_guard.dart';

/// #537, Teil 3: Die App zeigt angemeldet die Backend-Werte, als Gast die
/// lokale Rechnung. Dieser Test schickt die **erwarteten Backend-Antworten**
/// der gemeinsamen Testfälle (`testdata/home-office-parity`,
/// `testdata/insights-parity`) durch die echte Lesegrenze des `ApiClient`
/// (angemeldeter Weg des [HybridAnalyticsRepository]) und vergleicht sie mit
/// dem Gast-Weg über dieselben Einträge. Gleich = die Anzeige ändert sich
/// durch den Umzug ins Backend um keine Zahl.
///
/// Die Heatmap hängt von der Zone ab und wird nur verglichen, wenn `TZ` des
/// Prozesses gleich `timeZone` des Falls ist (wie `insights_parity_tz_test`).
void main() {
  registerTimezoneCanary();
  final processZone = Platform.environment['TZ'];

  List<Map<String, dynamic>> load(String dir) =>
      ((jsonDecode(File('../testdata/$dir/cases.json').readAsStringSync())
              as Map<String, dynamic>)['cases'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

  ApiBackedWork seeded(Map<String, dynamic> c) {
    final work = ApiBackedWork();
    final raw = (c['entries'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (var i = 0; i < raw.length; i++) {
      work.backend.entries['${raw[i]['id']}#$i'] = raw[i];
    }
    return work;
  }

  group('Home-Office', () {
    for (final c in load('home-office-parity')) {
      test(c['name'] as String, () async {
        final year = c['year'] as int;
        final work = seeded(c);
        work.backend.reports['/api/reports/home-office/$year'] =
            http.Response(jsonEncode(c['expected']), 200);
        final signedIn = HybridAnalyticsRepository(api: work.api);
        final guest = HybridAnalyticsRepository(
            api: null,
            workRepository: work.repository,
            settingsRepository: _Settings(40, const [1, 2, 3, 4, 5]));

        final remote = await signedIn.homeOfficeYear(year);
        final local = await guest.homeOfficeYear(year);
        expect(remote, local);
        for (var m = 1; m <= 12; m++) {
          final r = await signedIn.homeOfficeMonth(year, m);
          final l = await guest.homeOfficeMonth(year, m);
          expect(r.counts, l.counts, reason: 'Monat $m');
          expect(r.dates, l.dates, reason: 'Monat $m');
        }
      });
    }
  });

  group('Insights', () {
    for (final c in load('insights-parity')) {
      test(c['name'] as String, () async {
        final ref = c['referenceDate'] as String;
        final today = DateTime(int.parse(ref.substring(0, 4)),
            int.parse(ref.substring(5, 7)), int.parse(ref.substring(8)));
        final zone = c['timeZone'] as String;
        final s = c['settings'] as Map<String, dynamic>;
        final work = seeded(c);
        work.backend.reports[
                '/api/reports/insights/${today.year}/${today.month}/${today.day}'] =
            http.Response(jsonEncode(c['expected']), 200);
        final signedIn = HybridAnalyticsRepository(
            api: work.api, timeZone: FixedTimeZone(zone));
        final guest = HybridAnalyticsRepository(
          api: null,
          workRepository: work.repository,
          settingsRepository: _Settings(
              (s['weeklyTargetHours'] as num).toDouble(),
              (s['workdays'] as List<dynamic>).cast<int>()),
        );

        final remote = await signedIn.insights(today);
        final local = await guest.insights(today);
        final tzQuery = work.backend.requests
            .where((u) => u.path.contains('/reports/insights/'))
            .single
            .queryParameters['tz'];
        expect(tzQuery, zone);

        expect(remote.from, local.from);
        expect(remote.to, local.to);
        expect(remote.dailyTarget, local.dailyTarget);
        expect(remote.warningThresholdDays, local.warningThresholdDays);
        expect(remote.burnoutStatus.currentStreak,
            local.burnoutStatus.currentStreak);
        expect(remote.burnoutStatus.longestStreak,
            local.burnoutStatus.longestStreak);
        expect(remote.burnoutStatus.isWarning, local.burnoutStatus.isWarning);
        expect([
          for (final w in remote.weekdayAverages)
            (
              w.weekday,
              w.averageWorkDuration.inMilliseconds,
              w.deviationFromOverallAverage.inMilliseconds,
              w.sampleCount
            )
        ], [
          for (final w in local.weekdayAverages)
            (
              w.weekday,
              w.averageWorkDuration.inMilliseconds,
              w.deviationFromOverallAverage.inMilliseconds,
              w.sampleCount
            )
        ]);
        if (processZone == zone) {
          expect([
            for (final b in remote.heatmap)
              (b.startHour, b.averageOvertime.inMilliseconds, b.sampleCount)
          ], [
            for (final b in local.heatmap)
              (b.startHour, b.averageOvertime.inMilliseconds, b.sampleCount)
          ]);
        }
      });
    }
  });
}

class _Settings extends Fake implements SettingsRepository {
  _Settings(this._hours, this._workdays);
  final double _hours;
  final List<int> _workdays;

  @override
  double getTargetWeeklyHours() => _hours;

  @override
  List<int> getWorkdays() => _workdays;
}
