import 'package:flutter_test/flutter_test.dart';

import '../../support/dashboard_harness.dart';

// Fr 2026-10-02, Sa 2026-10-03 (Soll 0, Zusatztag).
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final fr = DateTime(2026, 10, 2);
  final sa = DateTime(2026, 10, 3);
  const retroDelta = Duration(minutes: -30);

  group('reloadAfterRetroClose (#385)', () {
    scenario(
        'heute laufender Timer: läuft weiter, Basis = neuer Saldo, Stop '
        'speichert neuer Saldo + Tagesanteil',
        DateTime(2026, 10, 3, 9), (h) {
      h.boot();
      expect(h.state.initialOvertime, Duration.zero);
      expect(h.state.workEntry.workEnd, isNull);

      // CloseOpenWorkEntry hat den Saldo des Vortags fortgeschrieben.
      h.overtime.stored = retroDelta;
      h.act(h.vm.reloadAfterRetroClose);

      expect(h.state.workEntry.workStart, DateTime(2026, 10, 3, 8));
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.state.initialOvertime, retroDelta);
      expect(h.async.periodicTimerCount, 1, reason: 'Timer läuft weiter');

      h.tick(const Duration(minutes: 1));
      h.act(h.vm.startOrStopTimer);
      // Stop 09:01: 61 min Netto, Soll 0 (Sa) -> -30 + 61 = 31 min.
      expect(h.overtime.savedOvertimes.last, const Duration(minutes: 31));
      // Stop-Pfad bleibt beim Default: das Backend darf lastUpdated setzen (#406).
      expect(h.overtime.savedKeepLastUpdated.last, isFalse);
    }, setUp: (h) {
      h.seed(entryOf(sa, start: DateTime(2026, 10, 3, 8)));
    });

    scenario(
        'heute bereits abgeschlossen und gespeichert: kein Doppelzählen, '
        'lastUpdated unverändert',
        DateTime(2026, 10, 3, 13), (h) {
      h.boot();
      expect(h.state.initialOvertime, Duration.zero);
      expect(h.state.totalOvertime, const Duration(hours: 4));

      h.overtime.stored = const Duration(hours: 4) + retroDelta;
      h.act(h.vm.reloadAfterRetroClose);

      expect(h.state.dailyOvertime, const Duration(hours: 4));
      expect(h.state.initialOvertime, retroDelta);
      expect(h.state.totalOvertime, const Duration(hours: 4) + retroDelta);
      expect(h.overtime.lastUpdate, DateTime(2026, 10, 3, 12, 30));
    }, setUp: (h) {
      h.seed(entryOf(sa,
          start: DateTime(2026, 10, 3, 8), end: DateTime(2026, 10, 3, 12)));
      h.overtime.stored = const Duration(hours: 4);
      h.overtime.lastUpdate = DateTime(2026, 10, 3, 12, 30);
    });

    scenario(
        'lastUpdated == heute bei laufendem Timer: Reload nutzt den Saldo '
        'als Basis (dayChange-Pfad), zieht heute nicht ab',
        DateTime(2026, 10, 3, 9), (h) {
      h.boot();
      h.overtime.stored = retroDelta;
      h.act(h.vm.reloadAfterRetroClose);
      expect(h.state.initialOvertime, retroDelta);
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.overtime.lastUpdate, DateTime(2026, 10, 3, 7, 30));
    }, setUp: (h) {
      h.seed(entryOf(sa, start: DateTime(2026, 10, 3, 8)));
      h.overtime.lastUpdate = DateTime(2026, 10, 3, 7, 30);
    });

    scenario('leerer heutiger Eintrag: leerer Tag, Saldo = neuer Wert',
        DateTime(2026, 10, 3, 9), (h) {
      h.boot();
      h.overtime.stored = retroDelta;
      h.act(h.vm.reloadAfterRetroClose);
      expect(h.state.workEntry.workStart, isNull);
      expect(h.state.initialOvertime, retroDelta);
      expect(h.state.totalOvertime, retroDelta);
    });

    scenario(
        'Dashboard führt einen Vortag über Mitternacht aus: bleibt am '
        'Eintrag, nur die Saldo-Basis wird aktualisiert',
        DateTime(2026, 10, 2, 23), (h) {
      h.boot();
      h.clock.jumpTo(DateTime(2026, 10, 3, 1));
      h.tick();
      expect(h.state.workEntry.date, fr);

      h.overtime.stored = retroDelta;
      h.act(h.vm.reloadAfterRetroClose);

      expect(h.state.workEntry.date, fr, reason: 'läuft weiter am Starttag');
      expect(h.state.workEntry.workEnd, isNull);
      expect(h.state.initialOvertime, retroDelta);
      expect(h.async.periodicTimerCount, 1);
    }, setUp: (h) {
      h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22)));
    });
  });
}
