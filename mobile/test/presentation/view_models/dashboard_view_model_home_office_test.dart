import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Home-Office-Flag im Dashboard (#277). Feste Daten: Mo 2026-10-05, Fake-Uhr.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final nine = DateTime(2026, 10, 5, 9);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

  scenario('setHomeOffice(true) mit laufendem Timer speichert mit Flag', nine,
      (h) {
    h.boot();
    final grossBefore = h.state.grossWorkDuration;

    h.act(() => h.vm.setHomeOffice(true));

    expect(h.state.workEntry.isHomeOffice, isTrue);
    expect(h.work.saved.length, 1);
    expect(h.work.saved.single.isHomeOffice, isTrue);
    expect(h.work.saved.single.workStart, at(8));
    expect(h.work.saved.single.workEnd, isNull);
    // Timer, Start und Pausen bleiben unveraendert.
    expect(h.state.workEntry.workStart, at(8));
    expect(h.state.workEntry.breaks, isEmpty);
    h.tick(const Duration(seconds: 5));
    expect(h.state.grossWorkDuration, isNot(grossBefore),
        reason: 'Timer laeuft weiter');
  }, setUp: (h) => h.seed(entryOf(mo, start: at(8))));

  scenario('setHomeOffice(false) setzt zurueck und speichert', nine, (h) {
    h.boot();
    expect(h.state.workEntry.isHomeOffice, isTrue);

    h.act(() => h.vm.setHomeOffice(false));

    expect(h.state.workEntry.isHomeOffice, isFalse);
    expect(h.work.saved.single.isHomeOffice, isFalse);
  }, setUp: (h) => h.seed(entryOf(mo, start: at(8), isHomeOffice: true)));

  scenario(
      'ohne workStart: nur State, kein Speichern, Start schreibt Flag', nine,
      (h) {
    h.boot();

    h.act(() => h.vm.setHomeOffice(true));

    expect(h.state.workEntry.isHomeOffice, isTrue);
    expect(h.work.saved, isEmpty);

    h.act(h.vm.startOrStopTimer);

    expect(h.work.saved.length, 1);
    expect(h.work.saved.single.workStart, nine);
    expect(h.work.saved.single.isHomeOffice, isTrue);
  });

  scenario('beendeter Eintrag: Flag aendern bleibt gespeichert, Zeiten gleich',
      DateTime(2026, 10, 5, 18), (h) {
    h.boot();

    h.act(() => h.vm.setHomeOffice(true));

    expect(h.work.saved.single.isHomeOffice, isTrue);
    expect(h.work.saved.single.workStart, at(8));
    expect(h.work.saved.single.workEnd, at(16));
  }, setUp: (h) => h.seed(entryOf(mo, start: at(8), end: at(16))));

  group('Handkopien behalten das Flag', () {
    scenario('startNewSession', DateTime(2026, 10, 5, 18), (h) {
      h.boot();
      h.act(h.vm.startNewSession);
      expect(h.work.saved.single.isHomeOffice, isTrue);
      expect(h.state.workEntry.isHomeOffice, isTrue);
    },
        setUp: (h) =>
            h.seed(entryOf(mo, start: at(8), end: at(16), isHomeOffice: true)));

    scenario('startNewSessionKeepBreaks', DateTime(2026, 10, 5, 18), (h) {
      h.boot();
      h.act(h.vm.startNewSessionKeepBreaks);
      expect(h.work.saved.single.isHomeOffice, isTrue);
    },
        setUp: (h) =>
            h.seed(entryOf(mo, start: at(8), end: at(16), isHomeOffice: true)));

    scenario('clearEndTime', DateTime(2026, 10, 5, 18), (h) {
      h.boot();
      h.act(h.vm.clearEndTime);
      expect(h.work.saved.single.isHomeOffice, isTrue);
      expect(h.work.saved.single.workEnd, isNull);
    },
        setUp: (h) =>
            h.seed(entryOf(mo, start: at(8), end: at(16), isHomeOffice: true)));
  });

  scenario('Start-/Endzeit, Stop und Pause behalten das Flag', nine, (h) {
    h.boot();
    h.act(() => h.vm.setManualStartTime(const TimeOfDay(hour: 7, minute: 30)));
    h.act(h.vm.startOrStopBreak);
    h.act(h.vm.startOrStopBreak);
    h.act(h.vm.startOrStopTimer);
    expect(h.work.saved, isNotEmpty);
    expect(h.work.saved.every((e) => e.isHomeOffice), isTrue);
    expect(h.state.workEntry.isHomeOffice, isTrue);
  }, setUp: (h) => h.seed(entryOf(mo, start: at(8), isHomeOffice: true)));

  scenario(
      'Speichern geht an das Profil des Aktionsbeginns (Profil B)',
      nine,
      (h) {
        h.boot();
        h.switchProfile('b');

        h.act(() => h.vm.setHomeOffice(true));

        expect(h.workB.saved.single.isHomeOffice, isTrue);
        expect(h.work.saved, isEmpty);
      },
      profiles: true,
      setUp: (h) {
        h.seed(entryOf(mo, start: at(8)));
        h.workB.store[dayKey(mo)] = entryOf(mo, start: at(8, 30));
      });

  scenario('waehrend isSaving wird verworfen wie bei _runAction', nine, (h) {
    h.boot();
    h.work.holdSaves = true;
    h.act(() => h.vm.setHomeOffice(true));
    expect(h.state.isSaving, isTrue);

    h.act(() => h.vm.setHomeOffice(false));
    expect(h.work.pendingSaves.length, 1, reason: 'zweiter Aufruf verworfen');

    h.work.holdSaves = false;
    h.work.pendingSaves.single.complete();
    h.async.flushMicrotasks();
    expect(h.state.isSaving, isFalse);
    expect(h.state.workEntry.isHomeOffice, isTrue);
  }, setUp: (h) => h.seed(entryOf(mo, start: at(8))));
}
