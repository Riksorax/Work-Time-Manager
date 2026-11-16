import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:logger/logger.dart';

import '../../support/dashboard_harness.dart';
import '../../support/reported_logs.dart';

// Fehler beim Laden des Dashboards (#571): Erwartbare Fehler (kein
// angemeldeter Nutzer, Verbindungsabbruch) gehen nicht an Crashlytics, echte
// Fehler weiterhin. Der Zustand (nicht geladen, Aktionen gesperrt) ist in
// beiden Fällen derselbe. Feste Daten: Mo 2026-10-05, 09:00.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final events = <LogEvent>[];
  captureLogs(events);

  final start = DateTime(2026, 10, 5, 9);

  final expected = <String, Object>{
    'NotSignedInException': const NotSignedInException('getWorkEntry'),
    ...transientNetworkErrors,
  };

  for (final MapEntry(key: name, value: error) in expected.entries) {
    scenario('$name: nicht gemeldet, Laden beendet, Aktionen gesperrt', start,
        (h) {
      h.boot();

      expect(reported(events, '[Dashboard]'), isEmpty);
      expect(h.state.isLoading, isFalse);
      expect(h.vm.isTimerRunning, isFalse);
      h.act(h.vm.startOrStopTimer);
      expect(h.work.saved, isEmpty);
    }, setUp: (h) {
      h.work
        ..failReads = true
        ..readError = error;
    });
  }

  scenario('anderer Fehler: weiterhin als Fehler gemeldet', start, (h) {
    h.boot();

    final logs = reported(events, '[Dashboard] Laden fehlgeschlagen');
    expect(logs.map((e) => e.level), [Level.error]);
    expect(h.state.isLoading, isFalse);
  }, setUp: (h) {
    h.work
      ..failReads = true
      ..readError = StateError('kaputt');
  });
}
