import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/home_office_stats.dart';

import '../../support/timezone_guard.dart';

/// Zonen-Regressionstest (#418) für die Home-Office-Auswertung (#282): Der Tag
/// kommt aus `entryDay` (Id `yyyy-MM-dd`), nie aus der Zone des `date`-Werts.
/// Lokal: `TZ=America/Los_Angeles flutter test <datei>` (ebenso Pacific/Auckland).
void main() {
  registerTimezoneCanary();

  test('Eintrag mit Id yyyy-MM-dd zählt am Id-Tag, egal wie date liegt', () {
    final e = WorkEntryEntity(
      id: '2026-06-05',
      date: DateTime.utc(2026, 6, 5),
      workStart: DateTime.utc(2026, 6, 5, 8),
      isHomeOffice: true,
    );
    final s = calculateHomeOfficeStats([e]);
    expect(s.homeOfficeDates, [DateTime(2026, 6, 5)]);
  });

  test('zwei Einträge desselben Id-Tags in verschiedener date-Darstellung', () {
    final a = WorkEntryEntity(
      id: '2026-06-05',
      date: DateTime.utc(2026, 6, 5),
      workStart: DateTime.utc(2026, 6, 5, 8),
    );
    final b = WorkEntryEntity(
      id: '2026-06-05',
      date: DateTime(2026, 6, 5),
      workStart: DateTime(2026, 6, 5, 9),
      isHomeOffice: true,
    );
    final s = calculateHomeOfficeStats([a, b]);
    expect(s.totalDays, 1);
    expect(s.homeOfficeDays, 1);
  });
}
