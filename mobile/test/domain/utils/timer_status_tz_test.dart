import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/timer_status.dart';

import '../../support/timezone_guard.dart';

/// Zonen-Regressionstest (#418): der Tagesschluessel des Snapshots ist in jeder
/// Zone der Kalendertag der Id, auch wenn `date` ein UTC-Mitternacht-Wert ist.
void main() {
  registerTimezoneCanary();

  test('Tagesschluessel bei UTC-Mitternacht-date und Id-Tag', () {
    final entry = WorkEntryEntity(
      id: '2026-10-05',
      date: DateTime.utc(2026, 10, 5),
      workStart: DateTime.utc(2026, 10, 5, 7),
    );
    final s = buildTimerSnapshot(entry: entry, net: Duration.zero);
    expect(s.dayKey, '2026-10-05');
    expect(s.workStartMs, DateTime.utc(2026, 10, 5, 7).millisecondsSinceEpoch);
  });

  test('Platzhalter-Id: Tag aus lokalen Feldern von date', () {
    final entry = WorkEntryEntity(
      id: 'platzhalter',
      date: DateTime(2026, 10, 5),
    );
    expect(buildTimerSnapshot(entry: entry, net: Duration.zero).dayKey,
        '2026-10-05');
  });
}
