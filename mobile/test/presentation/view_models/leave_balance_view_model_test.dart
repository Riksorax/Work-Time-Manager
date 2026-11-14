import 'package:logger/logger.dart';
import '../../support/reported_logs.dart';
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';

import '../../support/fake_clock.dart';
import 'leave_balance_view_model_test.mocks.dart';

/// Aktives Profil, im Test umschaltbar.
class _SwitchableProfile extends ActiveWorkProfileIdNotifier {
  _SwitchableProfile(this._initial);
  final String? _initial;
  @override
  String? build() => _initial;

  void set(String? id) => state = id;
}

const _user = UserEntity(id: 'u1', email: 'a@b.c');

@GenerateMocks([WorkRepository, SettingsRepository, ApiClient])
void main() {
  // todayProvider (#379) registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late MockWorkRepository work;
  late MockSettingsRepository settings;
  late MockApiClient api;
  late ProviderContainer container;
  late DateTime now;

  WorkEntryEntity entry(DateTime d, WorkEntryType t) =>
      WorkEntryEntity(id: d.toIso8601String(), date: d, type: t);

  setUp(() {
    work = MockWorkRepository();
    settings = MockSettingsRepository();
    api = MockApiClient();
    now = DateTime(2026, 6, 15);
    when(settings.getVacationDaysPerYear()).thenReturn(30);
    when(work.getWorkEntriesForMonth(any, any)).thenAnswer((_) async => []);
    container = ProviderContainer(overrides: [
      workRepositoryProvider.overrideWithValue(work),
      settingsRepositoryProvider.overrideWithValue(settings),
      clockProvider.overrideWithValue(() => now),
      // Gast (nicht angemeldet): lokale Rechnung.
      authStateProvider.overrideWithValue(const AsyncValue.data(null)),
      apiClientProvider.overrideWithValue(api),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('startet im Ladezustand und laedt 12 Monate des Jahres', () async {
    when(work.getWorkEntriesForMonth(2026, 3)).thenAnswer((_) async => [
          entry(DateTime(2026, 3, 2), WorkEntryType.vacation),
          entry(DateTime(2026, 3, 3), WorkEntryType.vacation),
          entry(DateTime(2026, 3, 4), WorkEntryType.sick),
        ]);

    expect(container.read(leaveBalanceViewModelProvider).isLoading, true);
    await settle();

    final state = container.read(leaveBalanceViewModelProvider);
    expect(state.isLoading, false);
    expect(state.hasError, false);
    expect(state.balance!.year, 2026);
    expect(state.balance!.entitlement, 30);
    expect(state.balance!.taken, 2);
    expect(state.balance!.remaining, 28);
    expect(state.balance!.sickDays, 1);
    for (var m = 1; m <= 12; m++) {
      verify(work.getWorkEntriesForMonth(2026, m)).called(1);
    }
    // Gast: kein API-Aufruf (#535).
    verifyZeroInteractions(api);
  });

  test('Anspruch kommt aus dem Repository', () async {
    when(settings.getVacationDaysPerYear()).thenReturn(25);
    container.read(leaveBalanceViewModelProvider);
    await settle();
    expect(
        container.read(leaveBalanceViewModelProvider).balance!.remaining, 25);
  });

  test('Fehler fuehrt zu error-State ohne stillen Wert', () async {
    when(work.getWorkEntriesForMonth(2026, 5)).thenThrow(Exception('boom'));
    container.read(leaveBalanceViewModelProvider);
    await settle();
    final state = container.read(leaveBalanceViewModelProvider);
    expect(state.hasError, true);
    expect(state.isLoading, false);
    expect(state.balance, isNull);
  });

  test('reload nach Fehler laedt neu', () async {
    when(work.getWorkEntriesForMonth(2026, 5)).thenThrow(Exception('boom'));
    container.read(leaveBalanceViewModelProvider);
    await settle();
    when(work.getWorkEntriesForMonth(2026, 5)).thenAnswer((_) async => []);
    await container.read(leaveBalanceViewModelProvider.notifier).reload();
    final state = container.read(leaveBalanceViewModelProvider);
    expect(state.hasError, false);
    expect(state.balance!.remaining, 30);
  });

  test('invalidate nach Jahreswechsel laedt das neue Jahr', () async {
    container.read(leaveBalanceViewModelProvider);
    await settle();
    expect(container.read(leaveBalanceViewModelProvider).balance!.year, 2026);

    now = DateTime(2027, 1, 2);
    when(work.getWorkEntriesForMonth(2027, 1)).thenAnswer(
        (_) async => [entry(DateTime(2027, 1, 2), WorkEntryType.vacation)]);
    container.read(todayProvider.notifier).refresh();
    container.invalidate(leaveBalanceViewModelProvider);
    container.read(leaveBalanceViewModelProvider); // Rebuild ist lazy
    await settle();

    final state = container.read(leaveBalanceViewModelProvider);
    expect(state.balance!.year, 2027);
    expect(state.balance!.taken, 1);
  });

  test('Vorwert bleibt waehrend des Neuladens erhalten', () async {
    container.read(leaveBalanceViewModelProvider);
    await settle();
    container.invalidate(leaveBalanceViewModelProvider);
    final loading = container.read(leaveBalanceViewModelProvider);
    expect(loading.isLoading, true);
    expect(loading.balance, isNotNull);
  });

  test('funktioniert ohne Premium/Login-Gate', () async {
    // Nur die Repositories sind gesetzt - weder isPremium noch Auth werden
    // benoetigt.
    container.read(leaveBalanceViewModelProvider);
    await settle();
    expect(container.read(leaveBalanceViewModelProvider).balance, isNotNull);
  });

  group('Tageswechsel (#387)', () {
    late FakeClock clock;

    ProviderContainer makeContainer(FakeAsync async, DateTime start) {
      clock = FakeClock(start)..bind(async);
      final c = ProviderContainer(overrides: [
        workRepositoryProvider.overrideWithValue(work),
        settingsRepositoryProvider.overrideWithValue(settings),
        clockProvider.overrideWithValue(clock.call),
        authStateProvider.overrideWithValue(const AsyncValue.data(null)),
        apiClientProvider.overrideWithValue(api),
      ]);
      return c;
    }

    void verifyYear(int year, {int times = 1}) {
      for (var m = 1; m <= 12; m++) {
        verify(work.getWorkEntriesForMonth(year, m)).called(times);
      }
    }

    test('U1 Jahr kommt aus der Uhr', () {
      fakeAsync((async) {
        final c = makeContainer(async, DateTime(2026, 12, 31, 23, 59, 30));
        c.read(leaveBalanceViewModelProvider);
        async.flushMicrotasks();
        verifyYear(2026);
        expect(c.read(leaveBalanceViewModelProvider).balance!.year, 2026);
        c.dispose();
      });
    });

    test('U2 Jahreswechsel verwirft Vorjahreswerte und laedt neu', () {
      fakeAsync((async) {
        final c = makeContainer(async, DateTime(2026, 12, 31, 23, 59, 30));
        c.read(leaveBalanceViewModelProvider);
        async.flushMicrotasks();
        clearInteractions(work);

        final releases = Completer<List<WorkEntryEntity>>();
        when(work.getWorkEntriesForMonth(2027, 1))
            .thenAnswer((_) => releases.future);

        async.elapse(const Duration(seconds: 30));
        final loading = c.read(leaveBalanceViewModelProvider);
        expect(loading.isLoading, true);
        expect(loading.balance, isNull);
        verifyYear(2027);

        releases.complete([]);
        async.flushMicrotasks();
        final done = c.read(leaveBalanceViewModelProvider);
        expect(done.isLoading, false);
        expect(done.balance!.year, 2027);
        c.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('U3 Tageswechsel im Jahr loest keinen Reload aus', () {
      fakeAsync((async) {
        final c = makeContainer(async, DateTime(2026, 10, 2, 23, 59, 30));
        c.read(leaveBalanceViewModelProvider);
        async.flushMicrotasks();
        clearInteractions(work);

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(c.read(todayProvider), DateTime(2026, 10, 3));
        verifyNever(work.getWorkEntriesForMonth(any, any));
        expect(c.read(leaveBalanceViewModelProvider).balance!.year, 2026);
        c.dispose();
      });
    });

    test('U4 Resume-Pfad (jumpTo + refresh) laedt beim Jahreswechsel neu', () {
      fakeAsync((async) {
        final c = makeContainer(async, DateTime(2026, 12, 31, 12));
        c.read(leaveBalanceViewModelProvider);
        async.flushMicrotasks();
        clearInteractions(work);

        clock.jumpTo(DateTime(2027, 1, 1, 0, 0, 5));
        c.read(todayProvider.notifier).refresh();
        async.flushMicrotasks();
        verifyYear(2027);
        expect(c.read(leaveBalanceViewModelProvider).balance!.year, 2027);
        c.dispose();
      });
    });

    test('U5 Dispose waehrend des Reloads schreibt keinen State', () {
      fakeAsync((async) {
        final c = makeContainer(async, DateTime(2026, 12, 31, 23, 59, 30));
        c.read(leaveBalanceViewModelProvider);
        async.flushMicrotasks();

        final pending = Completer<List<WorkEntryEntity>>();
        when(work.getWorkEntriesForMonth(2027, 1))
            .thenAnswer((_) => pending.future);
        async.elapse(const Duration(seconds: 30));
        c.dispose();
        pending.complete([]);
        async.flushMicrotasks();
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('reload() nach Dispose schreibt keinen State (ref.mounted-Guard)', () {
      fakeAsync((async) {
        final c = makeContainer(async, DateTime(2026, 10, 2, 12));
        final vm = c.read(leaveBalanceViewModelProvider.notifier);
        async.flushMicrotasks();
        c.dispose();
        clearInteractions(work);

        // Ohne Guard: StateError beim Schreiben in einen entsorgten Notifier.
        vm.reload();
        async.flushMicrotasks();
        verifyNever(work.getWorkEntriesForMonth(any, any));
      });
    });

    test('Neuaufbau verwirft eine Bilanz aus dem Vorjahr (Nachzuegler)', () {
      fakeAsync((async) {
        final stale = Completer<List<WorkEntryEntity>>();
        when(work.getWorkEntriesForMonth(2026, 1))
            .thenAnswer((_) => stale.future);
        final c = makeContainer(async, DateTime(2026, 12, 31, 23, 59, 30));
        c.read(leaveBalanceViewModelProvider);
        async.flushMicrotasks();

        // Jahreswechsel, Vorjahres-Ladevorgang haengt noch.
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        // Der Nachzuegler endet erst jetzt; er ist ueberholt (#535: Ladelauf-
        // Zaehler) und setzt die 2026er Bilanz nicht mehr.
        stale.complete([]);
        async.flushMicrotasks();
        expect(c.read(leaveBalanceViewModelProvider).balance!.year, 2027);

        // Neuaufbau (z. B. Profilwechsel) waehrend das 2027er Laden haengt.
        final pending = Completer<List<WorkEntryEntity>>();
        when(work.getWorkEntriesForMonth(2027, 1))
            .thenAnswer((_) => pending.future);
        c.invalidate(leaveBalanceViewModelProvider);
        final s = c.read(leaveBalanceViewModelProvider);
        expect(s.isLoading, true);
        // Nie die Vorjahres-Bilanz; als Vorwert bleibt hoechstens die
        // bereits geladene 2027er stehen.
        expect(s.balance?.year, anyOf(isNull, 2027));
        pending.complete([]);
        async.flushMicrotasks();
        c.dispose();
      });
    });
  });

  group('Logging beim Fehler (#506) - LeaveBalance', () {
    final events = <LogEvent>[];
    captureLogs(events);

    for (final entry in transientNetworkErrors.entries) {
      test('${entry.key} wird nicht an Crashlytics gemeldet', () async {
        when(work.getWorkEntriesForMonth(2026, 5))
            .thenAnswer((_) async => throw entry.value);
        await (() async {
          container.read(leaveBalanceViewModelProvider);
          await settle();
        })();
        expect(reported(events, 'LeaveBalanceViewModel'), isEmpty);
      });
    }

    test(
        'ohne angemeldeten Nutzer (kurz nach Abmelden): kein Fehlerzustand, '
        'nichts gemeldet (#522)', () async {
      when(work.getWorkEntriesForMonth(2026, 5)).thenAnswer((_) async =>
          throw const NotSignedInException('getWorkEntriesForMonth'));
      await (() async {
        container.read(leaveBalanceViewModelProvider);
        await settle();
      })();
      final state = container.read(leaveBalanceViewModelProvider);
      expect(state.hasError, isFalse);
      expect(state.isLoading, isTrue);
      expect(reported(events, 'LeaveBalanceViewModel'), isEmpty);
    });

    test('anderer Fehler wird weiter auf Level error geloggt', () async {
      when(work.getWorkEntriesForMonth(2026, 5))
          .thenAnswer((_) async => throw StateError('kaputt'));
      await (() async {
        container.read(leaveBalanceViewModelProvider);
        await settle();
      })();
      expect(reported(events, 'LeaveBalanceViewModel').map((e) => e.level),
          [Level.error]);
    });
  });

  group('Angemeldet: Urlaubsbilanz vom Backend (#535)', () {
    Map<String, dynamic> answer({
      int year = 2026,
      int perYear = 30,
      int taken = 4,
      int? remaining,
      int sick = 2,
    }) =>
        {
          'year': year,
          'vacationDaysPerYear': perYear,
          'vacationDaysTaken': taken,
          'vacationDaysRemaining': remaining ?? perYear - taken,
          'sickDays': sick,
          // Weitere Felder sind möglich und werden ignoriert.
          'holidayDays': 7,
        };

    ProviderContainer signedIn({String? profileId, DateTime Function()? clk}) {
      return ProviderContainer(overrides: [
        // Wie in der App hängt das Repository am aktiven Profil (neue
        // Instanz je Profil); ein Profilwechsel baut das ViewModel neu.
        workRepositoryProvider.overrideWith((ref) =>
            ref.watch(activeWorkProfileIdProvider) == profileId
                ? work
                : MockWorkRepository()),
        settingsRepositoryProvider.overrideWithValue(settings),
        clockProvider.overrideWithValue(clk ?? () => now),
        authStateProvider.overrideWithValue(const AsyncValue.data(_user)),
        apiClientProvider.overrideWithValue(api),
        activeWorkProfileIdProvider
            .overrideWith(() => _SwitchableProfile(profileId)),
      ]);
    }

    test('ein API-Aufruf, kein Monats-Laden, Werte aus der Antwort', () async {
      when(api.getYearlyLeave(2026, profileId: anyNamed('profileId')))
          .thenAnswer((_) async => answer(taken: 4, sick: 2));
      final c = signedIn();
      addTearDown(c.dispose);

      expect(c.read(leaveBalanceViewModelProvider).isLoading, true);
      await settle();

      final state = c.read(leaveBalanceViewModelProvider);
      expect(state.isLoading, false);
      expect(state.hasError, false);
      expect(state.balance!.year, 2026);
      expect(state.balance!.entitlement, 30);
      expect(state.balance!.taken, 4);
      expect(state.balance!.remaining, 26);
      expect(state.balance!.sickDays, 2);
      verify(api.getYearlyLeave(2026, profileId: null)).called(1);
      verifyNever(work.getWorkEntriesForMonth(any, any));
    });

    test('Rest kommt vom Server (auch negativ), wenn der Anspruch passt',
        () async {
      when(api.getYearlyLeave(2026, profileId: anyNamed('profileId')))
          .thenAnswer((_) async => answer(taken: 33, remaining: -3));
      final c = signedIn();
      addTearDown(c.dispose);
      c.read(leaveBalanceViewModelProvider);
      await settle();
      expect(c.read(leaveBalanceViewModelProvider).balance!.remaining, -3);
    });

    test('zusätzliches Profil: profileId geht mit', () async {
      when(api.getYearlyLeave(2026, profileId: anyNamed('profileId')))
          .thenAnswer((_) async => answer());
      final c = signedIn(profileId: 'p1');
      addTearDown(c.dispose);
      c.read(leaveBalanceViewModelProvider);
      await settle();
      verify(api.getYearlyLeave(2026, profileId: 'p1')).called(1);
    });

    test(
        'gerade lokal geänderter Anspruch wird nicht vom veralteten '
        'Serverwert überschrieben', () async {
      // Einstellungen: lokal schon 25, der Server meldet noch 30 (das
      // Speichern dorthin ist noch unterwegs).
      when(settings.getVacationDaysPerYear()).thenReturn(25);
      when(api.getYearlyLeave(2026, profileId: anyNamed('profileId')))
          .thenAnswer((_) async => answer(perYear: 30, taken: 4));
      final c = signedIn();
      addTearDown(c.dispose);
      c.read(leaveBalanceViewModelProvider);
      await settle();
      final b = c.read(leaveBalanceViewModelProvider).balance!;
      expect(b.entitlement, 25);
      expect(b.taken, 4);
      expect(b.remaining, 21);
    });

    test('Fehler der API: Fehlerzustand, reload lädt erneut', () async {
      when(api.getYearlyLeave(2026, profileId: anyNamed('profileId')))
          .thenThrow(const ApiException('getYearlyLeave', 503));
      final c = signedIn();
      addTearDown(c.dispose);
      c.read(leaveBalanceViewModelProvider);
      await settle();
      expect(c.read(leaveBalanceViewModelProvider).hasError, true);
      expect(c.read(leaveBalanceViewModelProvider).balance, isNull);

      when(api.getYearlyLeave(2026, profileId: anyNamed('profileId')))
          .thenAnswer((_) async => answer());
      await c.read(leaveBalanceViewModelProvider.notifier).reload();
      final s = c.read(leaveBalanceViewModelProvider);
      expect(s.hasError, false);
      expect(s.balance!.remaining, 26);
    });

    test('NotSignedInException: kein Fehlerzustand (#522)', () async {
      when(api.getYearlyLeave(2026, profileId: anyNamed('profileId')))
          .thenThrow(const NotSignedInException('getYearlyLeave'));
      final c = signedIn();
      addTearDown(c.dispose);
      c.read(leaveBalanceViewModelProvider);
      await settle();
      final s = c.read(leaveBalanceViewModelProvider);
      expect(s.hasError, false);
      expect(s.isLoading, true);
    });

    test('Profilwechsel lädt neu, späte Antwort des alten Profils verfällt',
        () async {
      final old = Completer<Map<String, dynamic>>();
      when(api.getYearlyLeave(2026, profileId: null))
          .thenAnswer((_) => old.future);
      when(api.getYearlyLeave(2026, profileId: 'p1'))
          .thenAnswer((_) async => answer(taken: 10));
      final c = signedIn();
      addTearDown(c.dispose);
      c.listen(leaveBalanceViewModelProvider, (_, __) {});
      await settle();

      (c.read(activeWorkProfileIdProvider.notifier) as _SwitchableProfile)
          .set('p1');
      c.read(leaveBalanceViewModelProvider); // Rebuild ist lazy
      for (var i = 0; i < 3; i++) {
        await settle();
      }
      expect(c.read(leaveBalanceViewModelProvider).balance!.taken, 10);

      old.complete(answer(taken: 1));
      await settle();
      expect(c.read(leaveBalanceViewModelProvider).balance!.taken, 10);
      verify(api.getYearlyLeave(2026, profileId: 'p1')).called(1);
    });

    test('Jahreswechsel lädt das neue Jahr, Tageswechsel im Jahr nicht', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime(2026, 12, 30, 23, 59, 30))
          ..bind(async);
        when(api.getYearlyLeave(any, profileId: anyNamed('profileId')))
            .thenAnswer((inv) async =>
                answer(year: inv.positionalArguments.first as int));
        final c = signedIn(clk: clock.call);
        c.listen(leaveBalanceViewModelProvider, (_, __) {});
        async.flushMicrotasks();
        verify(api.getYearlyLeave(2026, profileId: null)).called(1);

        // Tageswechsel im Jahr (30. -> 31.12.): kein neuer Aufruf.
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(c.read(todayProvider), DateTime(2026, 12, 31));
        verifyNever(api.getYearlyLeave(any, profileId: anyNamed('profileId')));

        // Jahreswechsel: neues Jahr.
        async.elapse(const Duration(days: 1));
        async.flushMicrotasks();
        verify(api.getYearlyLeave(2027, profileId: null)).called(1);
        expect(c.read(leaveBalanceViewModelProvider).balance!.year, 2027);
        verifyNever(work.getWorkEntriesForMonth(any, any));
        c.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });

    group('Logging', () {
      final events = <LogEvent>[];
      captureLogs(events);

      for (final e in transientNetworkErrors.entries) {
        test('${e.key}: Fehlerzustand, nicht an Crashlytics gemeldet',
            () async {
          when(api.getYearlyLeave(2026, profileId: anyNamed('profileId')))
              .thenAnswer((_) async => throw e.value);
          final c = signedIn();
          addTearDown(c.dispose);
          c.read(leaveBalanceViewModelProvider);
          await settle();
          expect(c.read(leaveBalanceViewModelProvider).hasError, true);
          expect(reported(events, 'LeaveBalanceViewModel'), isEmpty);
        });
      }

      test('ApiException wird mit Status auf Level error geloggt', () async {
        when(api.getYearlyLeave(2026, profileId: anyNamed('profileId')))
            .thenAnswer(
                (_) async => throw const ApiException('getYearlyLeave', 503));
        final c = signedIn();
        addTearDown(c.dispose);
        c.read(leaveBalanceViewModelProvider);
        await settle();
        final logs = reported(events, 'LeaveBalanceViewModel').toList();
        expect(logs.map((e) => e.level), [Level.error]);
        expect(logs.single.message.toString(), contains('ApiException(503)'));
      });
    });
  });
}
