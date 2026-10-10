import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/domain/usecases/close_open_work_entry.dart';
import 'package:flutter_work_time/domain/usecases/get_open_past_work_entries.dart';

import '../../support/fake_repositories.dart';

/// Block B (#418), Use Cases fuer offene Eintraege: Der Tag kommt aus der Id.
/// Fixtures sind inkonsistent (Id und `date` meinen verschiedene Tage),
/// zonenunabhaengig. Das Mini-Fake liefert Listen je Monat (der
/// `FakeWorkRepository` indiziert nach `date`).
class _MonthListRepository implements WorkRepository {
  final Map<String, List<WorkEntryEntity>> months = {};
  final List<WorkEntryEntity> saved = [];
  final List<String> monthReads = [];

  static String _key(int y, int m) =>
      '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(
      int year, int month) async {
    monthReads.add(_key(year, month));
    return months[_key(year, month)] ?? const [];
  }

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async => saved.add(entry);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

WorkEntryEntity _open(String id, DateTime date, DateTime start) =>
    WorkEntryEntity(id: id, date: date, workStart: start);

void main() {
  // Uhr: Mo 02.11.2026 12:00 (aktueller Monat November, Vormonat Oktober).
  final now = DateTime(2026, 11, 2, 12);
  late _MonthListRepository repo;

  setUp(() => repo = _MonthListRepository());

  group('GetOpenPastWorkEntries', () {
    test('heutiger Eintrag laut Id ist kein offener Vortag', () async {
      // Id heute (02.11.), date am Vortag.
      final today =
          _open('2026-11-02', DateTime(2026, 11, 1), DateTime(2026, 11, 2, 8));
      repo.months['2026-11'] = [today];
      final result = await GetOpenPastWorkEntries(repo, clock: () => now)();
      expect(result, isEmpty);
    });

    test('Vortag laut Id wird gefunden, auch wenn date heute zeigt', () async {
      final yesterday =
          _open('2026-11-01', DateTime(2026, 11, 2), DateTime(2026, 11, 1, 22));
      repo.months['2026-11'] = [yesterday];
      final result = await GetOpenPastWorkEntries(repo, clock: () => now)();
      expect(result, [yesterday]);
    });

    test('Sortierung: neuester Tag laut Id zuerst', () async {
      final newer =
          _open('2026-11-01', DateTime(2026, 10, 29), DateTime(2026, 11, 1, 8));
      final older = _open(
          '2026-10-31', DateTime(2026, 10, 30), DateTime(2026, 10, 31, 8));
      repo.months['2026-11'] = [newer];
      repo.months['2026-10'] = [older];
      final result = await GetOpenPastWorkEntries(repo, clock: () => now)();
      expect(result.map((e) => e.id), ['2026-11-01', '2026-10-31']);
    });

    test('excludeDate nimmt den Eintrag mit passender Id aus', () async {
      final running =
          _open('2026-11-01', DateTime(2026, 10, 29), DateTime(2026, 11, 1, 8));
      repo.months['2026-11'] = [running];
      final result = await GetOpenPastWorkEntries(repo, clock: () => now)(
          excludeDate: DateTime(2026, 11, 1));
      expect(result, isEmpty);
    });
  });

  group('CloseOpenWorkEntry._readFresh', () {
    test('liest den Monat des Eintragstags (Id 01.11., date 31.10.)', () async {
      // Monatsgrenze: date zeigt den Vormonat. Der frische Eintrag steht im
      // November, im Oktober liegt nichts.
      final entry =
          _open('2026-11-01', DateTime(2026, 10, 31), DateTime(2026, 11, 1, 8));
      repo.months['2026-11'] = [entry];
      final overtime = FakeOvertimeRepository();

      final result = await CloseOpenWorkEntry(repo, overtime, clock: () => now)(
        entry: entry,
        end: DateTime(2026, 11, 1, 16),
        dailyTarget: Duration.zero,
      );

      expect(result, CloseOpenEntryResult.closed);
      expect(repo.monthReads, ['2026-11']);
      expect(repo.saved.single.id, '2026-11-01');
      expect(repo.saved.single.workEnd, DateTime(2026, 11, 1, 16));
    });
  });
}
