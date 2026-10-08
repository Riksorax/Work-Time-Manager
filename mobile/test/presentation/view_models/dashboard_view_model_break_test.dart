import 'package:flutter_test/flutter_test.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Pausen-Toggle speichert genau einmal (#386). Feste Daten (Fr 2026-10-02,
// Sa 2026-10-03), Fake-Uhr, nie DateTime.now(). Auto-Save (30 Ticks a 1 s)
// bleibt unter der Schwelle, wo nicht ausdruecklich getestet.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final fr = DateTime(2026, 10, 2);
  final sa = DateTime(2026, 10, 3);
  final nine = DateTime(2026, 10, 5, 9);

  void seedRunning(Harness h) =>
      h.seed(entryOf(mo, start: DateTime(2026, 10, 5, 8)));

  scenario('G: Pause starten speichert genau einmal', nine, (h) {
    h.boot();
    expect(h.work.saved, isEmpty);

    h.act(h.vm.startOrStopBreak);

    expect(h.work.saved.length, 1);
    final breaks = h.state.workEntry.breaks;
    expect(breaks.length, 1);
    expect(breaks.single.start, nine);
    expect(breaks.single.end, isNull);
    expect(h.work.saved.single.breaks.single.start, nine);
  }, setUp: seedRunning);

  scenario('G2: Pause beenden speichert genau einmal zusaetzlich', nine, (h) {
    h.boot();
    h.act(h.vm.startOrStopBreak);
    expect(h.work.saved.length, 1);

    h.clock.jumpTo(DateTime(2026, 10, 5, 9, 30));
    h.act(h.vm.startOrStopBreak);

    expect(h.work.saved.length, 2);
    expect(h.state.workEntry.breaks.single.end, DateTime(2026, 10, 5, 9, 30));
    expect(h.work.saved.last.breaks.single.end, DateTime(2026, 10, 5, 9, 30));
  }, setUp: seedRunning);

  scenario(
      'H: Speicherfehler beim Toggle wird geschluckt, Auto-Save schreibt nach',
      nine, (h) {
    h.boot();
    h.work.failSaves = true;

    h.act(h.vm.startOrStopBreak);

    expect(h.state.workEntry.breaks.length, 1);
    expect(h.work.saved, isEmpty);

    h.work.failSaves = false;
    final grossBefore = h.state.grossWorkDuration;
    h.tick(const Duration(seconds: 30));

    expect(h.state.grossWorkDuration, isNot(grossBefore),
        reason: 'Timer laeuft');
    expect(h.work.saved.length, 1);
    expect(h.work.saved.single.breaks.length, 1);
    expect(h.work.saved.single.breaks.single.start, nine);
  }, setUp: seedRunning);

  scenario('I(a): laufender Fr-Eintrag ueber Mitternacht bleibt am Starttag',
      DateTime(2026, 10, 2, 23), (h) {
    h.boot();
    final readsBefore = h.work.getWorkEntryCalls;
    h.clock.jumpTo(DateTime(2026, 10, 3, 0, 30));

    h.act(h.vm.startOrStopBreak);

    expect(h.work.saved.length, 1);
    expect(h.work.log.last, 'save:${dayKey(fr)}');
    expect(h.work.saved.single.date, fr);
    expect(
        h.work.saved.single.breaks.single.start, DateTime(2026, 10, 3, 0, 30));
    expect(h.work.getWorkEntryCalls, readsBefore, reason: 'kein Reinit');
  }, setUp: (h) {
    h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 8)));
  });

  scenario(
      'I(b): gestoppter Vortag schaltet vor dem Schreiben auf den neuen Tag',
      DateTime(2026, 10, 2, 18), (h) {
    h.boot();
    final logStart = h.work.log.length;
    h.clock.jumpTo(DateTime(2026, 10, 3, 10));

    h.act(h.vm.startOrStopBreak);

    final log = h.work.log.sublist(logStart);
    expect(log, contains('read:${dayKey(sa)}'));
    expect(log, contains('save:${dayKey(sa)}'));
    expect(log.indexOf('read:${dayKey(sa)}'),
        lessThan(log.indexOf('save:${dayKey(sa)}')));
    expect(log, isNot(contains('save:${dayKey(fr)}')));
    expect(h.work.saved.where((e) => e.date == sa).length, 1);
  }, setUp: (h) {
    h.seed(entryOf(fr,
        start: DateTime(2026, 10, 2, 8), end: DateTime(2026, 10, 2, 17)));
  });
}
