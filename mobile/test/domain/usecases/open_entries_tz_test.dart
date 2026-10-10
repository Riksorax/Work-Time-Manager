import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/usecases/get_open_past_work_entries.dart';
import 'package:flutter_work_time/domain/utils/leave_balance_utils.dart';
import 'package:flutter_work_time/domain/utils/open_entry_report_utils.dart';

import '../../support/api_backed_work_repository.dart';
import '../../support/timezone_guard.dart';

/// Regression #418 fuer offene Eintraege (#385/#404) und die Jahresgrenze des
/// Urlaubs: Die Eintraege kommen als UTC-Mitternacht durch den echten
/// `ApiClient`-Mapper. Uhr: Mo 2026-10-05 12:00 lokal (fest).
///
/// Lokal: `TZ=America/Los_Angeles flutter test <datei>`.
void main() {
  registerTimezoneCanary();

  final now = DateTime(2026, 10, 5, 12);
  String utc(DateTime local) => local.toUtc().toIso8601String();

  late ApiBackedWork world;

  setUp(() => world = ApiBackedWork());

  test('heutiger laufender Eintrag (05.10.) ist kein offener Vortag', () async {
    world.backend.seed('2026-10-05', workStart: utc(DateTime(2026, 10, 5, 8)));
    final open =
        await GetOpenPastWorkEntries(world.repository, clock: () => now)();
    expect(open, isEmpty);

    final today = await world.repository.getWorkEntry(DateTime(2026, 10, 5));
    expect(isOpenBeforeToday(today, now), isFalse);
    expect(reportNetDuration(today, now: now), const Duration(hours: 4));
  });

  test('offener Eintrag vom 02.10. wird genau einmal gefunden', () async {
    world.backend
      ..seed('2026-10-02', workStart: utc(DateTime(2026, 10, 2, 8)))
      ..seed('2026-10-05', workStart: utc(DateTime(2026, 10, 5, 8)));
    final open =
        await GetOpenPastWorkEntries(world.repository, clock: () => now)();
    expect(open, hasLength(1));
    expect(open.single.date, DateTime(2026, 10, 2));
    expect(open.single.id, '2026-10-02');
    expect(isOpenBeforeToday(open.single, now), isTrue);
    expect(reportNetDuration(open.single, now: now), Duration.zero);
  });

  test('Urlaub am 01.01.2026 zaehlt fuer 2026 (Jahresgrenze)', () async {
    world.backend.seed('2026-01-01', type: 'vacation');
    final entries = await world.repository.getWorkEntriesForMonth(2026, 1);
    final balance = calculateLeaveBalance(entries, 2026, 30);
    expect(balance.taken, 1);
    expect(balance.remaining, 29);
  });
}
