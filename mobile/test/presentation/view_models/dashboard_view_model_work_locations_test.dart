import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Arbeitsorte im Dashboard (#526). Feste Daten: Mo 2026-10-05, Fake-Uhr.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final nine = DateTime(2026, 10, 5, 9);
  final evening = DateTime(2026, 10, 5, 18);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);
  const two = ['Büro Köln', 'Kunde A'];

  WorkEntryEntity withLocations(WorkEntryEntity e, [List<String> locs = two]) =>
      e.copyWith(workLocations: locs);

  scenario('setWorkLocations mit laufendem Timer speichert, Timer läuft weiter',
      nine, (h) {
    h.boot();
    final grossBefore = h.state.grossWorkDuration;

    h.act(() => h.vm.setWorkLocations(two));

    expect(h.state.workEntry.workLocations, two);
    expect(h.work.saved.single.workLocations, two);
    expect(h.work.saved.single.workStart, at(8));
    expect(h.work.saved.single.workEnd, isNull);
    expect(h.work.saved.single.isHomeOffice, isTrue,
        reason: 'andere Felder bleiben');
    h.tick(const Duration(seconds: 5));
    expect(h.state.grossWorkDuration, isNot(grossBefore));
    expect(h.state.workEntry.workEnd, isNull);
  }, setUp: (h) => h.seed(entryOf(mo, start: at(8), isHomeOffice: true)));

  scenario('Liste wird wie im Backend bereinigt', nine, (h) {
    h.boot();
    h.act(() => h.vm.setWorkLocations(
        ['  Büro ', 'büro', '', 'Kunde', 'a', 'b', 'c', 'd']));
    expect(h.work.saved.single.workLocations, ['Büro', 'Kunde', 'a', 'b', 'c']);
  }, setUp: (h) => h.seed(entryOf(mo, start: at(8))));

  scenario('[] entfernt die Orte (wird gespeichert)', nine, (h) {
    h.boot();
    expect(h.state.workEntry.workLocations, two);
    h.act(() => h.vm.setWorkLocations(const []));
    expect(h.state.workEntry.workLocations, isEmpty);
    expect(h.work.saved.single.workLocations, isEmpty);
    expect(h.work.saved.single.workLocations, isNotNull);
  }, setUp: (h) => h.seed(withLocations(entryOf(mo, start: at(8)))));

  scenario('ohne workStart: nur State, Start schreibt die Orte mit', nine, (h) {
    h.boot();
    h.act(() => h.vm.setWorkLocations(two));
    expect(h.state.workEntry.workLocations, two);
    expect(h.work.saved, isEmpty);

    h.act(h.vm.startOrStopTimer);
    expect(h.work.saved.single.workStart, nine);
    expect(h.work.saved.single.workLocations, two);
  });

  scenario('beendeter Eintrag: Orte ändern, Zeiten bleiben', evening, (h) {
    h.boot();
    h.act(() => h.vm.setWorkLocations(two));
    expect(h.work.saved.first.workLocations, two);
    expect(h.work.saved.first.workStart, at(8));
    expect(h.work.saved.first.workEnd, at(16));
  }, setUp: (h) => h.seed(entryOf(mo, start: at(8), end: at(16))));

  group('Handkopien behalten die Orte', () {
    scenario('startNewSession', evening, (h) {
      h.boot();
      h.act(h.vm.startNewSession);
      expect(h.work.saved.single.workLocations, two);
      expect(h.state.workEntry.workLocations, two);
    },
        setUp: (h) =>
            h.seed(withLocations(entryOf(mo, start: at(8), end: at(16)))));

    scenario('startNewSessionKeepBreaks', evening, (h) {
      h.boot();
      h.act(h.vm.startNewSessionKeepBreaks);
      expect(h.work.saved.single.workLocations, two);
    },
        setUp: (h) =>
            h.seed(withLocations(entryOf(mo, start: at(8), end: at(16)))));

    scenario('clearEndTime', evening, (h) {
      h.boot();
      h.act(h.vm.clearEndTime);
      expect(h.work.saved.single.workLocations, two);
      expect(h.work.saved.single.workEnd, isNull);
    },
        setUp: (h) =>
            h.seed(withLocations(entryOf(mo, start: at(8), end: at(16)))));
  });

  group('Weitere Schreibpfade behalten die Orte', () {
    scenario('Stop', nine, (h) {
      h.boot();
      h.act(h.vm.startOrStopTimer);
      expect(h.work.saved.last.workEnd, isNotNull);
      expect(h.work.saved.last.workLocations, two);
      expect(h.state.workEntry.workLocations, two);
    }, setUp: (h) => h.seed(withLocations(entryOf(mo, start: at(8)))));

    scenario('Pause starten und beenden', nine, (h) {
      h.boot();
      h.act(h.vm.startOrStopBreak);
      h.act(h.vm.startOrStopBreak);
      expect(h.work.saved, hasLength(2));
      expect(h.work.saved.every((e) => e.workLocations?.length == 2), isTrue);
    }, setUp: (h) => h.seed(withLocations(entryOf(mo, start: at(8)))));

    scenario('manuelle Start- und Endzeit', evening, (h) {
      h.boot();
      h.act(
          () => h.vm.setManualStartTime(const TimeOfDay(hour: 7, minute: 30)));
      h.act(() => h.vm.setManualEndTime(const TimeOfDay(hour: 17, minute: 0)));
      expect(h.work.saved, hasLength(2));
      expect(h.work.saved.every((e) => e.workLocations?.length == 2), isTrue);
    },
        setUp: (h) =>
            h.seed(withLocations(entryOf(mo, start: at(8), end: at(16)))));

    scenario('Pause löschen und bearbeiten', nine, (h) {
      h.boot();
      final b = h.state.workEntry.breaks.single;
      h.act(() => h.vm.updateBreak(b.copyWith(end: at(8, 45))));
      h.act(() => h.vm.deleteBreak(b.id));
      expect(h.work.saved, hasLength(2));
      expect(h.work.saved.every((e) => e.workLocations?.length == 2), isTrue);
    },
        setUp: (h) => h.seed(withLocations(entryOf(mo, start: at(8), breaks: [
              BreakEntity(id: 'b1', name: 'P', start: at(8, 15), end: at(8, 30))
            ]))));

    scenario('Autosave', nine, (h) {
      h.boot();
      h.tick(const Duration(seconds: 31));
      expect(h.work.saved, isNotEmpty);
      expect(h.work.saved.last.workLocations, two);
    }, setUp: (h) => h.seed(withLocations(entryOf(mo, start: at(8)))));
  });

  scenario(
      'Speichern geht an das Profil des Aktionsbeginns (Profil B)',
      nine,
      (h) {
        h.boot();
        h.switchProfile('b');
        h.act(() => h.vm.setWorkLocations(two));
        expect(h.workB.saved.single.workLocations, two);
        expect(h.work.saved, isEmpty);
      },
      profiles: true,
      setUp: (h) {
        h.seed(entryOf(mo, start: at(8)));
        h.workB.store[dayKey(mo)] = entryOf(mo, start: at(8, 30));
      });

  scenario('während isSaving wird verworfen', nine, (h) {
    h.boot();
    h.work.holdSaves = true;
    h.act(() => h.vm.setWorkLocations(two));
    expect(h.state.isSaving, isTrue);
    h.act(() => h.vm.setWorkLocations(const ['Anders']));
    expect(h.work.pendingSaves.length, 1, reason: 'zweiter Aufruf verworfen');
    h.work.holdSaves = false;
    h.work.pendingSaves.single.complete();
    h.async.flushMicrotasks();
    expect(h.state.workEntry.workLocations, two);
  }, setUp: (h) => h.seed(entryOf(mo, start: at(8))));
}
