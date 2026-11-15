import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/view_models/yearly_report_view_model.dart';

import '../../support/fake_repositories.dart';
import '../../support/reported_logs.dart';
import '../../support/yearly_comparison_fixture.dart';

/// Jahres-Tab (#530): angemeldet kommen Summen und Monatswerte aus `current`
/// von `GET /api/reports/yearly-comparison/{year}` (ohne Stichtag); als Gast
/// rechnet die App weiter lokal.
class _SwitchableProfile extends ActiveWorkProfileIdNotifier {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

class _Flag extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool v) => state = v;
}

final _signedIn = NotifierProvider<_Flag, bool>(_Flag.new);

const _user = UserEntity(id: 'u1', email: 'a@b.c');
const _hour = Duration(hours: 1);

void main() {
  // todayProvider registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late ProviderContainer container;
  late FakeYearlyComparisonApi api;
  late FakeWorkRepository work;
  late Map<String, WorkEntryEntity> seed;
  late List<Completer<Map<String, dynamic>>> pending;
  late bool hold;

  setUp(() {
    pending = [];
    hold = false;
    seed = {};
    work = FakeWorkRepository();
    api = FakeYearlyComparisonApi((c) {
      if (!hold) return Future.value(yearlyComparisonJsonFor(c));
      final completer = Completer<Map<String, dynamic>>();
      pending.add(completer);
      return completer.future;
    });
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 11, 15, 10)),
      apiClientProvider.overrideWithValue(api),
      // Neue Instanz je Profil/Login wie das echte Hybrid-Repository, damit
      // der Neuaufbau des ViewModels greift.
      workRepositoryProvider.overrideWith((ref) {
        ref.watch(activeWorkProfileIdProvider);
        ref.watch(_signedIn);
        return work = FakeWorkRepository()..store.addAll(seed);
      }),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      activeWorkProfileIdProvider.overrideWith(_SwitchableProfile.new),
      authStateProvider.overrideWith(
          (ref) => Stream.value(ref.watch(_signedIn) ? _user : null)),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> ready() async {
    container.listen(authStateProvider, (_, __) {});
    container.listen(yearlyReportViewModelProvider, (_, __) {});
    await settle();
  }

  YearlyReportViewModel vm() =>
      container.read(yearlyReportViewModelProvider.notifier);

  test('angemeldet: ein Aufruf ohne Stichtag, Werte aus current', () async {
    await ready();
    await vm().loadYear(2025);
    final s = container.read(yearlyReportViewModelProvider);

    expect(api.calls, hasLength(1));
    expect(api.calls.single.year, 2025);
    expect(api.calls.single.until, isNull);
    expect(api.calls.single.profileId, isNull);
    expect(work.monthReads, isEmpty, reason: 'keine lokale Rechnung');

    expect(s.isLoading, isFalse);
    expect(s.hasError, isFalse);
    expect(s.year, 2025);
    // Werte wie in der Fixture (ganzes Jahr).
    expect(s.totalNetWorkDuration, _hour * 1712 + const Duration(minutes: 15));
    expect(s.totalOvertime, _hour * 22 + const Duration(minutes: 30));
    expect(s.totalWorkDays, 214);
    expect(s.totalVacationDays, 30);
    expect(s.totalSickDays, 6);
    expect(s.totalHolidayDays, 10);
    // Monatswerte aus `months` (netto, Überstunden, Arbeitstage).
    final json = yearlyComparisonJson(2025)['current'] as Map<String, dynamic>;
    final months = json['months'] as List<dynamic>;
    expect(s.months, hasLength(12));
    for (var i = 0; i < 12; i++) {
      expect(s.months[i].month, i + 1);
      expect(s.months[i].netWorkDuration.inMilliseconds,
          months[i]['workedMs'] as int);
      expect(
          s.months[i].overtime.inMilliseconds, months[i]['overtimeMs'] as int);
      expect(s.months[i].workDays, months[i]['workDays'] as int);
    }
  });

  test('laufendes Jahr: Jahreswerte trotzdem ohne Stichtag', () async {
    await ready();
    await vm().loadYear(2026);
    expect(api.calls.single.year, 2026);
    expect(api.calls.single.until, isNull);
  });

  test('zusätzliches Profil: profileId geht mit', () async {
    (container.read(activeWorkProfileIdProvider.notifier) as _SwitchableProfile)
        .set('p1');
    await ready();
    await vm().loadYear(2026);
    expect(api.calls.single.profileId, 'p1');
  });

  test('Gast: lokale Rechnung, kein API-Aufruf', () async {
    container.read(_signedIn.notifier).set(false);
    seed['2026-03-02'] = WorkEntryEntity(
      id: '2026-03-02',
      date: DateTime(2026, 3, 2),
      workStart: DateTime(2026, 3, 2, 8),
      workEnd: DateTime(2026, 3, 2, 17),
    );
    await ready();
    await vm().loadYear(2026);
    final s = container.read(yearlyReportViewModelProvider);
    expect(api.calls, isEmpty);
    expect(work.monthReads, hasLength(12));
    expect(s.totals, isNull);
    expect(s.totalWorkDays, 1);
    expect(s.months[2].workDays, 1);
  });

  test('Jahr außerhalb 2001–2100: keine Anfrage, leer, kein Fehler', () async {
    await ready();
    await vm().loadYear(2000);
    final s = container.read(yearlyReportViewModelProvider);
    expect(api.calls, isEmpty);
    expect(s.isLoading, isFalse);
    expect(s.hasError, isFalse);
    expect(s.totalWorkDays, 0);
  });

  test('Jahreswechsel während des Ladens: alte Antwort wird verworfen',
      () async {
    await ready();
    hold = true;
    unawaited(vm().loadYear(2026));
    unawaited(vm().loadYear(2025));
    await settle();
    pending[1].complete(yearlyComparisonJson(2025, previousEmpty: true));
    await settle();
    pending[0].complete(yearlyComparisonJson(2026, currentEmpty: true));
    await settle();
    final s = container.read(yearlyReportViewModelProvider);
    expect(s.year, 2025);
    expect(s.totalWorkDays, 214);
  });

  test('Profilwechsel: dasselbe Jahr wird neu geladen, alte Antwort verworfen',
      () async {
    await ready();
    hold = true;
    unawaited(vm().loadYear(2025));
    await settle();
    (container.read(activeWorkProfileIdProvider.notifier) as _SwitchableProfile)
        .set('p2');
    await settle();
    expect(api.calls.map((c) => (c.year, c.profileId)),
        [(2025, null), (2025, 'p2')]);
    expect(container.read(yearlyReportViewModelProvider).year, 2025);

    pending[1].complete(yearlyComparisonJson(2025, currentEmpty: true));
    await settle();
    pending[0].complete(yearlyComparisonJson(2025));
    await settle();
    final s = container.read(yearlyReportViewModelProvider);
    expect(s.isLoading, isFalse);
    expect(s.totalWorkDays, 0, reason: 'Antwort des neuen Profils gilt');
  });

  test('ohne vorheriges Laden baut ein Profilwechsel nur neu (kein Aufruf)',
      () async {
    await ready();
    (container.read(activeWorkProfileIdProvider.notifier) as _SwitchableProfile)
        .set('p2');
    await settle();
    expect(api.calls, isEmpty);
  });

  group('Fehler', () {
    final events = <LogEvent>[];
    captureLogs(events);

    test('API-Fehler: Fehlerzustand ohne lokalen Ersatz, gemeldet; erneut',
        () async {
      await ready();
      api.handler = (_) async => throw const ApiException('x', 500);
      await vm().loadYear(2026);
      var s = container.read(yearlyReportViewModelProvider);
      expect(s.hasError, isTrue);
      expect(s.isLoading, isFalse);
      expect(work.monthReads, isEmpty);
      expect(reported(events, 'YearlyReportViewModel').map((e) => e.level),
          [Level.error]);
      expect(reported(events, 'YearlyReportViewModel').single.message,
          contains('500'));

      api.handler = (c) async => yearlyComparisonJsonFor(c);
      await vm().loadYear(2026);
      s = container.read(yearlyReportViewModelProvider);
      expect(s.hasError, isFalse);
      expect(s.totalWorkDays, 214);
    });

    for (final e in transientNetworkErrors.entries) {
      test('erwartbarer Netzwerkfehler (${e.key}): Fehler, nicht gemeldet',
          () async {
        await ready();
        api.handler = (_) async => throw e.value;
        await vm().loadYear(2026);
        expect(container.read(yearlyReportViewModelProvider).hasError, isTrue);
        expect(reported(events, 'YearlyReportViewModel'), isEmpty);
      });
    }

    test('NotSignedInException: kein Fehlerzustand, nicht gemeldet', () async {
      await ready();
      api.handler = (_) async => throw const NotSignedInException('x');
      await vm().loadYear(2026);
      expect(container.read(yearlyReportViewModelProvider).hasError, isFalse);
      expect(reported(events, 'YearlyReportViewModel'), isEmpty);
    });
  });
}
