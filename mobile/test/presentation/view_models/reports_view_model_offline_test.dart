import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/clock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/api_client.dart';
import 'package:flutter_work_time/domain/entities/overtime_freshness.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/state/reports_state.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:logger/logger.dart';

import '../../support/fake_repositories.dart';
import '../../support/reported_logs.dart';

class _Api extends Fake implements ApiClient {
  int calls = 0;
  bool offline = true;

  Future<Map<String, dynamic>> _answer(String op) async {
    calls++;
    if (offline) throw const SocketException('Network is unreachable');
    throw ApiException(op, 503);
  }

  @override
  Future<Map<String, dynamic>> getDailyReport(int y, int m, int d,
          {String? profileId}) =>
      _answer('getDailyReport');
  @override
  Future<Map<String, dynamic>> getWeeklyReport(int y, int m, int d,
          {String? profileId}) =>
      _answer('getWeeklyReport');
  @override
  Future<Map<String, dynamic>> getMonthlyReport(int y, int m,
          {String? profileId}) =>
      _answer('getMonthlyReport');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = <LogEvent>[];
  captureLogs(logs);

  late FakeWorkRepository work;
  late FakeOvertimeRepository overtime;
  late _Api api;
  late ProviderContainer container;

  setUp(() {
    work = FakeWorkRepository();
    overtime = FakeOvertimeRepository()
      ..stored = const Duration(hours: 3)
      ..freshness = OvertimeFreshness.cached;
    api = _Api();
    container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => DateTime(2026, 6, 10, 12)),
      workRepositoryProvider.overrideWithValue(work),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      overtimeRepositoryProvider.overrideWithValue(overtime),
      apiClientProvider.overrideWithValue(api),
    ]);
  });
  tearDown(() => container.dispose());

  Future<ReportsState> settle() async {
    container.read(reportsViewModelProvider);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(reportsViewModelProvider);
  }

  group('Berichte ohne Netz (#573)', () {
    test('Einträge nicht ladbar: Zustand offline, kein Report-Abruf', () async {
      work
        ..failReads = true
        ..readError = const SocketException('Failed host lookup');
      final s = await settle();

      expect(s.isLoading, isFalse);
      expect(s.loadFailure, ReportsLoadFailure.offline);
      expect(api.calls, 0);
      expect(reported(logs, ''), isEmpty);
    });

    test('anderer Fehler: Zustand failed, als Fehler geloggt', () async {
      work
        ..failReads = true
        ..readError = const ApiException('getWorkEntriesForMonth', 500);
      final s = await settle();

      expect(s.loadFailure, ReportsLoadFailure.failed);
      expect(reported(logs, 'Arbeitseinträge'), isNotEmpty);
    });

    test('ohne angemeldeten Nutzer: kein Fehlerzustand', () async {
      work
        ..failReads = true
        ..readError = const NotSignedInException('getWorkEntriesForMonth');
      final s = await settle();
      expect(s.loadFailure, ReportsLoadFailure.none);
    });

    test('Erneut versuchen lädt neu und hebt den Fehler auf', () async {
      work
        ..failReads = true
        ..readError = const SocketException('Failed host lookup');
      await settle();

      work.failReads = false;
      work.store['2026-06-10'] = WorkEntryEntity(
          id: '2026-06-10',
          date: DateTime(2026, 6, 10),
          workStart: DateTime(2026, 6, 10, 8),
          workEnd: DateTime(2026, 6, 10, 16));
      await container.read(reportsViewModelProvider.notifier).retry();
      final s = container.read(reportsViewModelProvider);
      expect(s.loadFailure, ReportsLoadFailure.none);
      expect(s.dailyReportState.entries, hasLength(1));
    });

    test('Monats-Gesamtüberstunden: zuletzt bekannter Stand mit Herkunft',
        () async {
      final s = await settle();
      expect(s.monthlyReportState.totalOvertime, const Duration(hours: 3));
      expect(s.overtimeFreshness, OvertimeFreshness.cached);
      // Report-API ohne Netz: nur info.
      expect(api.calls, greaterThan(0));
      expect(reported(logs, 'ReportsViewModel'), isEmpty);
    });

    test('unbekannter Saldo wird als unbekannt markiert', () async {
      overtime
        ..stored = Duration.zero
        ..freshness = OvertimeFreshness.unknown;
      final s = await settle();
      expect(s.overtimeFreshness, OvertimeFreshness.unknown);
    });
  });
}
