import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';

import '../../support/dashboard_harness.dart';

// Gleitzeit bei beendetem Eintrag (#386): Settings-Aenderung darf mit workEnd
// statt mit der Uhr rechnen. Feste Daten, Mo 2026-10-05 (DST-frei in
// Berlin/UTC/Los Angeles/Auckland), nie DateTime.now().
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final noon = DateTime(2026, 10, 5, 12);
  final afternoon = DateTime(2026, 10, 5, 15);
  const threeHours = Duration(hours: 3);

  /// weeklyHours 30 bei Mo-Fr = 6 h Soll.
  void sixHoursTarget(Harness h) => h.settings.weeklyHours = 30;

  group('gestoppter Eintrag 08:00-11:00, Soll 6 h', () {
    void seedStopped(Harness h) {
      sixHoursTarget(h);
      h.seed(entryOf(mo,
          start: DateTime(2026, 10, 5, 8), end: DateTime(2026, 10, 5, 11)));
    }

    scenario('A: Neuberechnung nutzt workEnd, nicht die Uhr', noon, (h) {
      h.boot();
      expect(h.state.dailyOvertime, -threeHours);

      h.vm.recalculateOvertimeFromSettings();
      expect(h.state.dailyOvertime, -threeHours);
      expect(h.state.totalOvertime, -threeHours);

      h.clock.jumpTo(afternoon);
      h.vm.recalculateOvertimeFromSettings();
      expect(h.state.dailyOvertime, -threeHours);
      expect(h.state.totalOvertime, -threeHours);
    }, setUp: seedStopped);

    scenario('A2: geaendertes Soll wird uebernommen (kein Frueh-Return)', noon,
        (h) {
      h.boot();
      h.settings.weeklyHours = 40; // 8 h Soll
      h.clock.jumpTo(afternoon);
      h.vm.recalculateOvertimeFromSettings();
      expect(h.state.dailyOvertime, const Duration(hours: -5));
      expect(h.state.totalOvertime, const Duration(hours: -5));
    }, setUp: seedStopped);

    scenario('A3: Basis aus Vortag bleibt erhalten', noon, (h) {
      h.boot();
      h.clock.jumpTo(afternoon);
      h.vm.recalculateOvertimeFromSettings();
      expect(h.state.totalOvertime, const Duration(hours: 1) - threeHours);
    }, setUp: (h) {
      seedStopped(h);
      h.overtime.stored = const Duration(hours: 1);
      h.overtime.lastUpdate = DateTime(2026, 10, 2, 18);
    });

    scenario('A: Neuberechnung persistiert nichts', noon, (h) {
      h.boot();
      final overtimeSaves = h.overtime.savedOvertimes.length;
      final workSaves = h.work.saved.length;
      h.clock.jumpTo(afternoon);
      h.vm.recalculateOvertimeFromSettings();
      expect(h.overtime.savedOvertimes.length, overtimeSaves);
      expect(h.work.saved.length, workSaves);
    }, setUp: seedStopped);
  });

  scenario('A4: abgeschlossene Pause zaehlt, Uhr egal', noon, (h) {
    h.boot();
    expect(h.state.dailyOvertime, const Duration(minutes: 15));
    h.clock.jumpTo(DateTime(2026, 10, 5, 20));
    h.vm.recalculateOvertimeFromSettings();
    expect(h.state.dailyOvertime, const Duration(minutes: 15));
  }, setUp: (h) {
    h.seed(entryOf(mo,
        start: DateTime(2026, 10, 5, 8),
        end: DateTime(2026, 10, 5, 17),
        breaks: [
          BreakEntity(
              id: 'b',
              name: 'Pause 1',
              start: DateTime(2026, 10, 5, 12),
              end: DateTime(2026, 10, 5, 12, 45)),
        ]));
  });

  scenario('A5: offene Pause bei gestopptem Eintrag zaehlt 0 (wie _load)', noon,
      (h) {
    h.boot();
    final afterBoot = h.state.dailyOvertime;
    expect(afterBoot, const Duration(hours: 1));
    h.vm.recalculateOvertimeFromSettings();
    expect(h.state.dailyOvertime, afterBoot);
    final expectedEnd = h.state.expectedEndTime;

    h.clock.jumpTo(DateTime(2026, 10, 5, 20));
    h.vm.recalculateOvertimeFromSettings();
    expect(h.state.dailyOvertime, afterBoot);
    expect(h.state.expectedEndTime, expectedEnd);
  }, setUp: (h) {
    h.seed(entryOf(mo,
        start: DateTime(2026, 10, 5, 8),
        end: DateTime(2026, 10, 5, 17),
        breaks: [
          BreakEntity(
              id: 'b', name: 'Pause 1', start: DateTime(2026, 10, 5, 12)),
        ]));
  });

  scenario('B: laufender Eintrag rechnet weiter mit der Uhr', noon, (h) {
    h.boot();
    expect(h.state.dailyOvertime, const Duration(hours: -4));
    h.tick(const Duration(hours: 1));
    expect(h.state.dailyOvertime, const Duration(hours: -3));

    h.settings.weeklyHours = 30; // Soll 6 h, Ist laeuft weiter
    h.vm.recalculateOvertimeFromSettings();
    expect(h.state.dailyOvertime,
        const Duration(hours: 5) - const Duration(hours: 6));
  }, setUp: (h) {
    h.seed(entryOf(mo, start: DateTime(2026, 10, 5, 8)));
  });

  scenario(
      'D: Stop-Ablauf, spaetere Settings-Aenderung', DateTime(2026, 10, 5, 8),
      (h) {
    h.boot();
    h.tick(threeHours);
    h.act(h.vm.startOrStopTimer);
    expect(h.state.workEntry.workEnd, DateTime(2026, 10, 5, 11));
    expect(h.state.dailyOvertime, -threeHours);
    final overtimeSaves = h.overtime.savedOvertimes.length;
    final workSaves = h.work.saved.length;

    h.clock.jumpTo(afternoon);
    h.vm.recalculateOvertimeFromSettings();
    expect(h.state.dailyOvertime, -threeHours);
    expect(h.state.totalOvertime, -threeHours);
    expect(h.overtime.savedOvertimes.length, overtimeSaves);
    expect(h.overtime.savedOvertimes.last, -threeHours);
    expect(h.work.saved.length, workSaves);
  }, setUp: (h) {
    sixHoursTarget(h);
    h.seed(entryOf(mo, start: DateTime(2026, 10, 5, 8)));
  });
}
