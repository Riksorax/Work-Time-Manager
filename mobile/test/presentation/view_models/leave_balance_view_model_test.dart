import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/repositories/settings_repository.dart';
import 'package:flutter_work_time/domain/repositories/work_repository.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';

import 'leave_balance_view_model_test.mocks.dart';

@GenerateMocks([WorkRepository, SettingsRepository])
void main() {
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
      leaveBalanceNowProvider.overrideWith((ref) => () => now),
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

  test('invalidate laedt neu, Jahreswechsel bestimmt Jahr neu', () async {
    container.read(leaveBalanceViewModelProvider);
    await settle();
    expect(container.read(leaveBalanceViewModelProvider).balance!.year, 2026);

    now = DateTime(2027, 1, 2);
    when(work.getWorkEntriesForMonth(2027, 1)).thenAnswer(
        (_) async => [entry(DateTime(2027, 1, 2), WorkEntryType.vacation)]);
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
}
