import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/domain/utils/iso_week.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';

import '../../support/api_backed_work_repository.dart';
import '../../support/fake_repositories.dart';

/// Block B (#418): Tages-, Wochen- und Monatsbericht bilden den Tag eines
/// Eintrags ueber `entryDay`. Fixtures sind **inkonsistent** (Id Montag
/// 2026-10-05, `date` Sonntag 2026-10-04), zonenunabhaengig. Uhr: Mo 05.10.2026.
class _MonthListRepository implements WorkRepository {
  final Map<String, List<WorkEntryEntity>> months = {};

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(
          int year, int month) async =>
      months['$year-${month.toString().padLeft(2, '0')}'] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;
}

WorkEntryEntity _work(String id, DateTime date, int day, int month) =>
    WorkEntryEntity(
      id: id,
      date: date,
      workStart: DateTime(2026, month, day, 8),
      workEnd: DateTime(2026, month, day, 16),
    );

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late _MonthListRepository repo;

  setUp(() => repo = _MonthListRepository());

  ProviderContainer newContainer() {
    final c = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 12)),
      workRepositoryProvider.overrideWithValue(repo),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      // Report-Endpunkte antworten 500: die lokale Berechnung bleibt stehen.
      apiClientProvider.overrideWithValue(ApiBackedWork().api),
      activeWorkProfileIdProvider.overrideWith(_NoProfile.new),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<ReportsState> loadAt(ProviderContainer c, DateTime day) async {
    c.listen(reportsViewModelProvider, (_, __) {});
    c.read(reportsViewModelProvider.notifier);
    await pumpEventQueue();
    c.read(reportsViewModelProvider.notifier).selectDate(day);
    await pumpEventQueue();
    return c.read(reportsViewModelProvider);
  }

  final monday = _work('2026-10-05', DateTime(2026, 10, 4), 5, 10);

  group('Oktober: Id Montag 05.10., date Sonntag 04.10.', () {
    setUp(() => repo.months['2026-10'] = [monday]);

    test('Tagesbericht: Eintrag gehoert zum 05.10., nicht zum 04.10.',
        () async {
      final c = newContainer();
      final mon = await loadAt(c, DateTime(2026, 10, 5));
      expect(mon.dailyReportState.entries, [monday]);
      expect(mon.dailyReportState.workTime, const Duration(hours: 8));

      c
          .read(reportsViewModelProvider.notifier)
          .selectDate(DateTime(2026, 10, 4));
      await pumpEventQueue();
      expect(
          c.read(reportsViewModelProvider).dailyReportState.entries, isEmpty);
    });

    test('Wochenbericht: Montag zaehlt in KW 41, Schluessel ist der 05.10.',
        () async {
      final c = newContainer();
      final mon = await loadAt(c, DateTime(2026, 10, 5));
      expect(mon.weeklyReportState.dailyWork.keys, [DateTime(2026, 10, 5)]);
      expect(mon.weeklyReportState.workDays, 1);

      // Sonntag 04.10. gehoert zur Vorwoche (KW 40): dort kein Eintrag.
      c
          .read(reportsViewModelProvider.notifier)
          .selectDate(DateTime(2026, 10, 4));
      await pumpEventQueue();
      final sun = c.read(reportsViewModelProvider);
      expect(sun.weeklyReportState.dailyWork, isEmpty);
      expect(isoWeekNumber(DateTime(2026, 10, 4)), 40);
      expect(isoWeekNumber(DateTime(2026, 10, 5)), 41);
    });

    test('Monatsbericht: KW 41, Arbeitstag 05.10., Soll Montag', () async {
      final c = newContainer();
      final state = await loadAt(c, DateTime(2026, 10, 5));
      final month = state.monthlyReportState;
      expect(month.dailyWork.keys, [DateTime(2026, 10, 5)]);
      expect(month.weeklyWork.keys, [41]);
      // Montag ist Arbeitstag: 8 h Soll, 8 h geleistet.
      expect(month.workDays, 1);
      expect(month.overtime, Duration.zero);
    });
  });

  group('Monats- und Jahresgrenze: Id gewinnt', () {
    test('Id 01.11., date 31.10.: Tagesbericht am 01.11.', () async {
      final e = _work('2026-11-01', DateTime(2026, 10, 31), 1, 11);
      repo.months['2026-11'] = [e];
      final c = newContainer();
      final state = await loadAt(c, DateTime(2026, 11, 1));
      expect(state.dailyReportState.entries, [e]);
      expect(state.monthlyReportState.dailyWork.keys, [DateTime(2026, 11, 1)]);
    });

    test('Id 01.01.2026, date 31.12.2025: Tagesbericht am 01.01.', () async {
      final e = WorkEntryEntity(
        id: '2026-01-01',
        date: DateTime(2025, 12, 31),
        workStart: DateTime(2026, 1, 1, 8),
        workEnd: DateTime(2026, 1, 1, 16),
      );
      repo.months['2026-01'] = [e];
      final c = newContainer();
      final state = await loadAt(c, DateTime(2026, 1, 1));
      expect(state.dailyReportState.entries, [e]);
    });
  });
}
