import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';

import '../../support/dashboard_harness.dart';

/// Block B (#418), Dashboard: Der Tag des angezeigten Eintrags kommt aus der Id.
/// Fixtures sind **inkonsistent** (Id und `date` meinen verschiedene Tage, wie
/// sie eine fehlerhafte Lesegrenze liefern wuerde), zonenunabhaengig.
/// Schreibpfade bleiben bewusst auf `date` (Identitaetskopien): hier wird nicht
/// behauptet, in welchen Slot ein inkonsistenter Eintrag gespeichert wird.
///
/// Uhr: Mo 05.10.2026 12:00 (bzw. Sa 03.10.2026 09:00 beim Fortsetzen).
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  // Heutiger Eintrag laut Id (Montag), `date` am Sonntag.
  WorkEntryEntity mondayEntry({DateTime? start, DateTime? end}) =>
      WorkEntryEntity(
        id: '2026-10-05',
        date: DateTime(2026, 10, 4),
        workStart: start,
        workEnd: end,
      );

  void seedMonday(Harness h, {DateTime? start, DateTime? end}) {
    h.work.store['2026-10-05'] = mondayEntry(start: start, end: end);
  }

  group('Heute und Soll am Tag der Id', () {
    scenario('laufender heutiger Eintrag: Soll Montag 8 h, kein Zusatztag',
        DateTime(2026, 10, 5, 12), (h) {
      h.boot();
      expect(h.state.isLoading, isFalse);
      expect(h.state.workEntry.id, '2026-10-05');
      expect(h.state.isExtraDay, isFalse);
      expect(h.state.dailyOvertime, const Duration(hours: 3) - eightHours);

      h.tick();
      expect(h.state.dailyOvertime, h.state.elapsedTime - eightHours);
    }, setUp: (h) {
      seedMonday(h, start: DateTime(2026, 10, 5, 9));
    });

    // Ladepfad: ohne Start/Ende rechnet nichts den Zusatztag nach, `_load`
    // bestimmt `isExtraDay` allein aus dem Tag des Eintrags.
    scenario('leerer heutiger Eintrag: Montag ist kein Zusatztag',
        DateTime(2026, 10, 5, 12), (h) {
      h.boot();
      expect(h.state.workEntry.id, '2026-10-05');
      expect(h.state.isExtraDay, isFalse);
    }, setUp: seedMonday);

    scenario('beendeter heutiger Eintrag: Soll Montag, Aktionen sind erlaubt',
        DateTime(2026, 10, 5, 12), (h) {
      h.boot();
      var ok = false;
      h.act(() async => ok =
          await h.vm.setManualEndTime(const TimeOfDay(hour: 17, minute: 0)));
      // `_ensureCurrentDay` erkennt den Eintrag als heute (kein Abbruch).
      expect(ok, isTrue);
      expect(h.work.saved, isNotEmpty);
      expect(h.work.saved.last.workEnd, DateTime(2026, 10, 5, 17));
      expect(h.state.isExtraDay, isFalse);
      // Netto-Arbeitszeit (nach Auto-Pausen) gegen 8 h Soll am Montag.
      expect(h.state.actualWorkDuration, isNotNull);
      expect(h.state.dailyOvertime, h.state.actualWorkDuration! - eightHours);
    }, setUp: (h) {
      seedMonday(h,
          start: DateTime(2026, 10, 5, 8), end: DateTime(2026, 10, 5, 12));
    });

    scenario('Retro-Close-Reload: heutiger laufender Eintrag wird neu geladen',
        DateTime(2026, 10, 5, 12), (h) {
      h.boot();
      final reads = h.work.getWorkEntryCalls;
      h.act(h.vm.reloadAfterRetroClose);
      // Ein heutiger Eintrag (Tag laut Id) ist kein "laufender Vortag": der
      // normale Reinit liest ihn neu.
      expect(h.work.getWorkEntryCalls, reads + 1);
    }, setUp: (h) {
      seedMonday(h, start: DateTime(2026, 10, 5, 9));
    });
  });

  group('Manuelle Zeiten liegen am Tag der Id', () {
    scenario('Startzeit auf leerem Eintrag: 05.10. 09:15, nicht 04.10.',
        DateTime(2026, 10, 5, 12), (h) {
      h.boot();
      h.act(
          () => h.vm.setManualStartTime(const TimeOfDay(hour: 9, minute: 15)));
      expect(h.work.saved.last.workStart, DateTime(2026, 10, 5, 9, 15));
    }, setUp: (h) {
      seedMonday(h);
    });

    scenario('Endzeit auf Eintrag ohne Start: 05.10. 17:00, nicht 04.10.',
        DateTime(2026, 10, 5, 12), (h) {
      h.boot();
      h.act(() => h.vm.setManualEndTime(const TimeOfDay(hour: 17, minute: 0)));
      expect(h.work.saved.last.workEnd, DateTime(2026, 10, 5, 17));
    }, setUp: (h) {
      seedMonday(h);
    });
  });

  group('Fortsetzen pinnt den Tag der Id', () {
    // Freitag 02.10. 22:00 gestartet, date inkonsistent (So 04.10. = Soll 0).
    // Uhr: Sa 03.10. 09:00 (11 h alt, fortsetzbar).
    scenario('pinnt den Freitag, Soll und isExtraDay stammen vom Freitag',
        DateTime(2026, 10, 3, 9), (h) {
      h.boot();
      final entry = WorkEntryEntity(
        id: '2026-10-02',
        date: DateTime(2026, 10, 4),
        workStart: DateTime(2026, 10, 2, 22),
      );
      var pinned = false;
      h.act(() async => pinned = await h.vm.resumePastEntry(entry));
      expect(pinned, isTrue);
      expect(h.state.workEntry.id, '2026-10-02');
      expect(h.state.isExtraDay, isFalse, reason: 'Freitag hat 8 h Soll');
    }, setUp: (h) {
      h.work.store['2026-10-02'] = WorkEntryEntity(
        id: '2026-10-02',
        date: DateTime(2026, 10, 4),
        workStart: DateTime(2026, 10, 2, 22),
      );
    });
  });
}
