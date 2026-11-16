import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/utils/api_errors.dart';
import 'package:flutter_work_time/data/datasources/remote/firestore_datasource.dart';
import 'package:flutter_work_time/data/repositories/firebase_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/hybrid_overtime_repository_impl.dart';
import 'package:flutter_work_time/data/repositories/local_overtime_repository_impl.dart';
import 'package:flutter_work_time/domain/entities/overtime_freshness.dart';
import 'package:flutter_work_time/presentation/state/leave_balance_state.dart';
import 'package:flutter_work_time/presentation/view_models/leave_balance_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/settings_view_model.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/reported_logs.dart';

/// Gerätetest 1.9.0 (#573): genau dieser Fehler kam ohne Netz.
final _hostLookup = http.ClientException(
    "SocketException: Failed host lookup: 'api.work-time-manager.app' "
    '(OS Error: No address associated with hostname, errno = 7)',
    Uri.parse('https://api.work-time-manager.app/api/overtime'));

class _ServerDs extends Fake implements FirestoreDataSource {
  final Map<String, int> minutes = {};
  bool offline = false;
  Object? failWith;

  void _check() {
    if (offline) throw _hostLookup;
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<Duration> getOvertime(String userId, {String? profileId}) async {
    _check();
    return Duration(minutes: minutes['$userId|${profileId ?? 'default'}'] ?? 0);
  }

  @override
  Future<DateTime?> getLastOvertimeUpdate(String userId,
      {String? profileId}) async {
    _check();
    return null;
  }
}

/// Lokale Einstellungen (Standardwerte, Wochensoll 38,5 h).
class _LocalSettings extends NoOpSettingsRepository {
  @override
  double getTargetWeeklyHours() => 38.5;
}

class _Leave extends LeaveBalanceViewModel {
  @override
  LeaveBalanceState build() => const LeaveBalanceState();
}

void main() {
  final logs = <LogEvent>[];
  captureLogs(logs);

  late SharedPreferences prefs;
  late _ServerDs ds;
  late _LocalSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ds = _ServerDs();
    settings = _LocalSettings();
  });

  /// Ein „App-Start“: neuer Container, frische Repositories, gleicher Speicher.
  ProviderContainer start({String uid = 'u1', String? profileId}) {
    final c = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      overtimeRepositoryProvider
          .overrideWith((ref) => HybridOvertimeRepositoryImpl(
                firebaseRepository: FirebaseOvertimeRepositoryImpl(
                    dataSource: ds,
                    userId: uid,
                    profileId: profileId,
                    prefs: prefs),
                localRepository: LocalOvertimeRepositoryImpl(prefs),
                userId: uid,
              )),
      leaveBalanceViewModelProvider.overrideWith(_Leave.new),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle(ProviderContainer c) async {
    c.read(settingsViewModelProvider);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('Einstellungen ohne Netz (#573)', () {
    test(
        'ohne gemerkten Saldo: data mit lokalen Einstellungen, Saldo unbekannt',
        () async {
      ds.offline = true;
      final c = start();
      await settle(c);

      final value = c.read(settingsViewModelProvider);
      expect(value.hasError, isFalse);
      final state = value.requireValue;
      expect(state.settings.weeklyTargetHours, 38.5);
      expect(state.overtimeBalance, isNull);
      expect(state.overtimeFreshness, OvertimeFreshness.unknown);
      expect(reported(logs, ''), isEmpty);
    });

    test('mit gemerktem Saldo: data, zuletzt bekannter Stand', () async {
      ds.minutes['u1|default'] = 750;
      await settle(start()); // online geladen und gemerkt

      ds.offline = true;
      final c = start(); // Neustart ohne Netz
      await settle(c);

      final state = c.read(settingsViewModelProvider).requireValue;
      expect(state.overtimeBalance, const Duration(minutes: 750));
      expect(state.overtimeFreshness, OvertimeFreshness.cached);
      expect(reported(logs, ''), isEmpty);
    });

    test('Nutzerwechsel: nie der gemerkte Saldo eines anderen Nutzers',
        () async {
      ds.minutes['u1|default'] = 750;
      await settle(start(uid: 'u1'));

      ds.offline = true;
      final c = start(uid: 'u2');
      await settle(c);
      final state = c.read(settingsViewModelProvider).requireValue;
      expect(state.overtimeBalance, isNull);
      expect(state.overtimeFreshness, OvertimeFreshness.unknown);
    });

    test('Profilwechsel: Saldo je Arbeitszeit-Profil getrennt', () async {
      ds.minutes['u1|default'] = 750;
      ds.minutes['u1|p2'] = -45;
      await settle(start());
      await settle(start(profileId: 'p2'));

      ds.offline = true;
      final a = start();
      await settle(a);
      final b = start(profileId: 'p2');
      await settle(b);
      expect(a.read(settingsViewModelProvider).requireValue.overtimeBalance,
          const Duration(minutes: 750));
      expect(b.read(settingsViewModelProvider).requireValue.overtimeBalance,
          const Duration(minutes: -45));
    });

    test('unerwarteter Fehler: Fehlerzustand, als Fehler geloggt', () async {
      ds.failWith = const ApiException('getOvertime', 500);
      final c = start();
      await settle(c);

      expect(c.read(settingsViewModelProvider).hasError, isTrue);
      expect(reported(logs, 'Einstellungen'), isNotEmpty);
    });

    test('reload lädt nach einem Fehler neu', () async {
      ds.failWith = const ApiException('getOvertime', 500);
      final c = start();
      await settle(c);
      expect(c.read(settingsViewModelProvider).hasError, isTrue);

      ds.failWith = null;
      ds.minutes['u1|default'] = 30;
      await c.read(settingsViewModelProvider.notifier).reload();
      final state = c.read(settingsViewModelProvider).requireValue;
      expect(state.overtimeBalance, const Duration(minutes: 30));
      expect(state.overtimeFreshness, OvertimeFreshness.current);
    });

    test('online: aktueller Saldo', () async {
      ds.minutes['u1|default'] = -15;
      final c = start();
      await settle(c);
      final state = c.read(settingsViewModelProvider).requireValue;
      expect(state.overtimeBalance, const Duration(minutes: -15));
      expect(state.overtimeFreshness, OvertimeFreshness.current);
    });
  });

  test('SocketException direkt zählt ebenso als „ohne Netz“', () async {
    ds.failWith = const SocketException('Network is unreachable');
    final c = start();
    await settle(c);
    expect(c.read(settingsViewModelProvider).hasError, isFalse);
  });
}
