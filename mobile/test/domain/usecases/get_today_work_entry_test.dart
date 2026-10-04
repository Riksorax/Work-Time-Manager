import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/usecases/get_today_work_entry.dart';

import '../../support/fake_repositories.dart';

void main() {
  late FakeWorkRepository repo;

  setUp(() => repo = FakeWorkRepository());

  Future<void> expectDay(DateTime clock, String expectedKey) async {
    final uc = GetTodayWorkEntry(repo, clock: () => clock);
    final entry = await uc();
    expect(repo.log.last, 'read:$expectedKey');
    expect(entry.id, expectedKey);
    expect(entry, isA<WorkEntryEntity>());
  }

  test('Uhr 2026-10-02 23:59 liefert den Freitag', () async {
    await expectDay(DateTime(2026, 10, 2, 23, 59), '2026-10-02');
  });

  test('Uhr 2026-10-03 00:00:01 liefert den Samstag', () async {
    await expectDay(DateTime(2026, 10, 3, 0, 0, 1), '2026-10-03');
  });

  test('Uhr wird unveraendert durchgereicht (DST-Tage, lokale Schluessel)',
      () async {
    final days = [
      DateTime(2026, 3, 29, 0, 30),
      DateTime(2026, 10, 25, 0, 30),
      DateTime(2026, 3, 8, 12),
      DateTime(2026, 11, 1, 12),
      DateTime(2026, 4, 5, 12),
      DateTime(2026, 9, 27, 12),
    ];
    for (final d in days) {
      await expectDay(d, dayKey(d));
    }
  });
}
