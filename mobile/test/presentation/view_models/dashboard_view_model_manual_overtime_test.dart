import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Manuelle Überstunden des Tages im Dashboard-Saldo (#538). Regel wie Web
// (`dashboard.service.ts`) und Backend (`ReportCalculator.CalculateDailyStat`):
// Tages-Überstunden = Netto − Tagessoll + manuelle Überstunden.
//
// Feste Daten: Mo 2026-10-05 und Di 2026-10-06 (Soll 8 h, DST-frei in
// Berlin/UTC/Los Angeles/Auckland), Vortag Fr 2026-10-02. Nie DateTime.now().
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final di = DateTime(2026, 10, 6);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);
  const manual = Duration(minutes: 30);
  const oneHour = Duration(hours: 1);

  /// Saldo bis Freitag: +1 h, zuletzt Freitag geschrieben.
  void baseFromFriday(Harness h) {
    h.overtime.stored = oneHour;
    h.overtime.lastUpdate = DateTime(2026, 10, 2, 18);
  }

  /// Simuliert einen App-Neustart am selben Tag: das ViewModel wird neu
  /// gebaut und lädt Eintrag und Saldo aus den (unveränderten) Repos.
  void restart(Harness h) {
    h.container.invalidate(dashboardViewModelProvider);
    h.async.elapse(Duration.zero);
    h.async.flushMicrotasks();
  }

  group('Stop mit manuellen Überstunden', () {
    // Lauf 08:00-17:00, Auto-Pause 45 min => Netto 8:15, Soll 8 h.
    // Tagesanteil = 8:15 - 8:00 + 0:30 = +0:45; Saldo = 1:00 + 0:45 = 1:45.
    const daily = Duration(minutes: 45);

    scenario('M1: Saldo = Basis + Netto - Soll + manuell', at(17), (h) {
      h.boot();
      h.act(h.vm.startOrStopTimer);
      expect(h.state.workEntry.workEnd, at(17));
      expect(h.state.actualWorkDuration, const Duration(hours: 8, minutes: 15));
      expect(h.state.dailyOvertime, daily);
      expect(h.state.totalOvertime, oneHour + daily);
      expect(h.overtime.savedOvertimes, [oneHour + daily]);
      expect(h.overtime.stored, const Duration(hours: 1, minutes: 45));
      expect(h.overtime.lastUpdate, at(17));
    }, setUp: (h) {
      baseFromFriday(h);
      h.seed(entryOf(mo, start: at(8)).copyWith(manualOvertime: manual));
    });

    scenario(
        'M2: Speichern -> Neustart -> Speichern ergibt denselben Saldo '
        '(manuell genau einmal)',
        at(17), (h) {
      h.boot();
      h.act(h.vm.startOrStopTimer);
      expect(h.overtime.stored, oneHour + daily);

      restart(h);
      expect(h.state.isLoading, isFalse);
      expect(h.state.workEntry.manualOvertime, manual);
      expect(h.state.initialOvertime, oneHour);
      expect(h.state.dailyOvertime, daily);
      expect(h.state.totalOvertime, oneHour + daily);

      // Erneutes Speichern mit unveränderten Zeiten: Saldo bleibt.
      h.act(() => h.vm.setManualEndTime(const TimeOfDay(hour: 17, minute: 0)));
      expect(h.overtime.savedOvertimes.last, oneHour + daily);
      h.act(() => h.vm.setManualEndTime(const TimeOfDay(hour: 17, minute: 0)));
      expect(h.overtime.savedOvertimes.last, oneHour + daily);

      // Zweiter Neustart: weiterhin dieselbe Basis.
      restart(h);
      expect(h.state.initialOvertime, oneHour);
      expect(h.state.totalOvertime, oneHour + daily);

      // Eine Stunde mehr: Netto 9:15 => +1:45, Saldo 2:45.
      h.act(() => h.vm.setManualEndTime(const TimeOfDay(hour: 18, minute: 0)));
      expect(h.state.dailyOvertime, const Duration(hours: 1, minutes: 45));
      expect(h.overtime.stored, const Duration(hours: 2, minutes: 45));
    }, setUp: (h) {
      baseFromFriday(h);
      h.seed(entryOf(mo, start: at(8)).copyWith(manualOvertime: manual));
    });

    scenario('M3: Gegenprobe ohne manuelle Überstunden (unverändert)', at(17),
        (h) {
      h.boot();
      h.act(h.vm.startOrStopTimer);
      const plain = Duration(minutes: 15);
      expect(h.state.dailyOvertime, plain);
      expect(h.overtime.stored, oneHour + plain);

      restart(h);
      expect(h.state.initialOvertime, oneHour);
      expect(h.state.totalOvertime, oneHour + plain);
      h.act(() => h.vm.setManualEndTime(const TimeOfDay(hour: 17, minute: 0)));
      expect(h.overtime.stored, oneHour + plain);
    }, setUp: (h) {
      baseFromFriday(h);
      h.seed(entryOf(mo, start: at(8)));
    });

    scenario(
        'M4: Tageswechsel nach dem Stop: Basis = Saldo, manuell des Vortags '
        'nicht erneut',
        at(17), (h) {
      h.boot();
      h.act(h.vm.startOrStopTimer);
      expect(h.overtime.stored, oneHour + daily);
      final saves = h.overtime.savedOvertimes.length;

      // Über Mitternacht auf Dienstag (Eintrag dort: nur manuell 0:15).
      h.tick(const Duration(hours: 7, seconds: 1));
      expect(h.state.workEntry.id, dayKey(di));
      expect(h.state.initialOvertime, oneHour + daily);
      expect(h.state.totalOvertime, oneHour + daily);
      expect(h.overtime.savedOvertimes.length, saves);

      // Dienstag 08:00-16:30, Auto-Pause 30 min => Netto 8:00, Soll 8 h.
      // Tagesanteil = 0 + 0:15 (manuell Dienstag).
      h.act(() => h.vm.setManualStartTime(const TimeOfDay(hour: 8, minute: 0)));
      h.act(() => h.vm.setManualEndTime(const TimeOfDay(hour: 16, minute: 30)));
      expect(h.state.workEntry.id, dayKey(di));
      expect(h.state.dailyOvertime, const Duration(minutes: 15));
      expect(h.overtime.stored, oneHour + daily + const Duration(minutes: 15));
    }, setUp: (h) {
      baseFromFriday(h);
      h.seed(entryOf(mo, start: at(8)).copyWith(manualOvertime: manual));
      h.seed(entryOf(di).copyWith(manualOvertime: const Duration(minutes: 15)));
    });

    scenario(
        'M5: stiller Reload (dayChange-Pfad) bei schon gespeichertem Tag '
        'zieht denselben Tagesanteil ab',
        DateTime(2026, 10, 5, 18), (h) {
      h.boot();
      expect(h.state.initialOvertime, oneHour);
      expect(h.state.totalOvertime, oneHour + daily);

      h.act(h.vm.reloadAfterRetroClose);
      expect(h.state.initialOvertime, oneHour);
      expect(h.state.dailyOvertime, daily);
      expect(h.state.totalOvertime, oneHour + daily);
      expect(h.overtime.savedOvertimes, isEmpty);
    }, setUp: (h) {
      // Auf einem anderen Gerät (z. B. Web) abgeschlossen und gespeichert.
      h.overtime.stored = oneHour + daily;
      h.overtime.lastUpdate = at(17);
      h.seed(entryOf(mo, start: at(8), end: at(17))
          .copyWith(manualOvertime: manual, breaks: [
        // 45 min wie die Auto-Pause des Stops => Netto 8:15.
        BreakEntity(id: 'b', name: 'Pause', start: at(12), end: at(12, 45)),
      ]));
    });
  });

  group('laufender Eintrag', () {
    scenario('M6: Anzeige rechnet manuell ein, Feierabend wie Web', at(12),
        (h) {
      h.boot();
      // Netto 4 h, Soll 8 h, manuell +0:30.
      expect(h.state.dailyOvertime, const Duration(hours: -3, minutes: -30));
      expect(h.state.totalOvertime,
          oneHour + const Duration(hours: -3, minutes: -30));
      // Feierabend für Tagessoll ±0: wie Web ohne manuelle Überstunden
      // (08:00 + 8 h + 30 min Pause).
      expect(h.state.expectedEndTime, at(16, 30));
      // Feierabend für Gesamtsaldo ±0: Soll - Basis - manuell = 6:30
      // (+30 min Pause) => 15:00 (ohne manuell wäre es 15:30).
      expect(h.state.expectedEndTotalZero, at(15));

      h.tick(const Duration(hours: 1));
      expect(h.state.dailyOvertime, const Duration(hours: -2, minutes: -30));
    }, setUp: (h) {
      baseFromFriday(h);
      h.seed(entryOf(mo, start: at(8)).copyWith(manualOvertime: manual));
    });

    scenario(
        'M7: Neustart mit laufendem Eintrag, Saldo heute geschrieben', at(12),
        (h) {
      h.boot();
      // Gespeichert (heute 12:00) = Basis 1 h + (4 h - 8 h + 0:30).
      expect(h.state.initialOvertime, oneHour);
      expect(h.state.totalOvertime,
          oneHour + const Duration(hours: -3, minutes: -30));
    }, setUp: (h) {
      h.overtime.stored = oneHour + const Duration(hours: -3, minutes: -30);
      h.overtime.lastUpdate = at(12);
      h.seed(entryOf(mo, start: at(8)).copyWith(manualOvertime: manual));
    });
  });
}
