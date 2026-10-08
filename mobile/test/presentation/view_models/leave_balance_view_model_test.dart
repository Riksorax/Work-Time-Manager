import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/today_provider.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';

import '../../support/fake_clock.dart';
import 'leave_balance_view_model_test.mocks.dart';

@GenerateMocks([WorkRepository, SettingsRepository])
void main() {
  // todayProvider (#379) registriert einen WidgetsBindingObserver.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late MockWorkRepository work;
  late MockSettingsRepository settings;
  late ProviderContainer container;
  late DateTime now;

  WorkEntryEntity entry(DateTime d, WorkEntryType t) =>
      WorkEntryEntity(id: d.toIso8601String(), date: d, type: t);

  setUp(() {
    work = MockWorkRepository();
    settings = MockSettingsRepository();
    now = DateTime(2026, 6, 15);
    when(settings.getVacationDaysPerYear()).thenReturn(30);
    when(work.getWorkEntriesForMonth(any, any)).thenAnswer((_) async => []);
    container = ProviderContainer(overrides: [
      workRepositoryProvider.overrideWithValue(work),
      settingsRepositoryProvider.overrideWithValue(settings),
      clockProvider.overrideWithValue(() => now),
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
        // Der Nachzuegler endet erst jetzt und setzt die 2026er Bilanz.
        stale.complete([]);
        async.flushMicrotasks();

        // Neuaufbau (z. B. Profilwechsel) waehrend das 2027er Laden haengt.
        final pending = Completer<List<WorkEntryEntity>>();
        when(work.getWorkEntriesForMonth(2027, 1))
            .thenAnswer((_) => pending.future);
        c.invalidate(leaveBalanceViewModelProvider);
        final s = c.read(leaveBalanceViewModelProvider);
        expect(s.isLoading, true);
        expect(s.balance, isNull);
        pending.complete([]);
        async.flushMicrotasks();
        c.dispose();
      });
    });
  });
}
