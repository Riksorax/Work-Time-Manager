import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/providers/widget_sync_provider.dart';
import 'package:flutter_work_time/core/services/app_lock_service.dart';
import 'package:flutter_work_time/core/services/home_widget_gateway.dart';
import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

// Status-Widget-Sync (#276). Feste Daten: Mo 2026-10-05 (Soll 8 h), Fr
// 2026-10-02. Die Tests lesen nur die Schluessel des Gateways, keine Uhrzeit-
// Formatierung (die ist nativ).

class FakeGateway implements HomeWidgetGateway {
  /// Reihenfolge aller Aufrufe: `save`, `update`, `clear`.
  final List<String> events = [];
  final List<Map<String, Object?>> saves = [];

  @override
  Future<void> saveData(Map<String, Object?> data) async {
    events.add('save');
    saves.add(Map.of(data));
  }

  @override
  Future<void> update() async => events.add('update');

  @override
  Future<void> clear() async => events.add('clear');

  Map<String, Object?> get last => saves.last;
}

/// App-Sperre ohne SharedPreferences; [configured] = aktiviert mit PIN.
class FakeLockService extends Fake implements AppLockService {
  FakeLockService({required this.configured});
  final bool configured;

  @override
  bool get isEnabled => configured;

  @override
  bool get hasPin => configured;
}

class Sync {
  Sync(this.h, this.gateway, this.auth, this.locked);
  final Harness h;
  final FakeGateway gateway;
  final StreamController<UserEntity?> auth;
  final bool locked;

  void flush() {
    h.async.flushMicrotasks();
  }
}

void widgetScenario(
  String name,
  DateTime start,
  void Function(Sync s) body, {
  void Function(Harness h)? setUp,
  bool lockedAtStart = false,
  bool lockConfigured = false,
}) {
  test(name, () {
    fakeAsync((async) {
      TestWidgetsFlutterBinding.ensureInitialized();
      final gateway = FakeGateway();
      final auth = StreamController<UserEntity?>.broadcast();
      final h = Harness(async, start, profiles: true, overrides: [
        homeWidgetGatewayProvider.overrideWithValue(gateway),
        authStateProvider.overrideWith((ref) => auth.stream),
        isAppLockedProvider.overrideWith((ref) => lockedAtStart),
        appLockServiceProvider
            .overrideWithValue(FakeLockService(configured: lockConfigured)),
      ]);
      setUp?.call(h);
      body(Sync(h, gateway, auth, lockedAtStart));
      h.dispose();
      auth.close();
      async.flushMicrotasks();
      expect(async.periodicTimerCount, 0, reason: 'Timer-Leak');
      expect(async.nonPeriodicTimerCount, 0, reason: 'Timer-Leak');
    });
  });
}

/// Startet den Sync. Ohne Auth-Wert schreibt der Sync nichts (die
/// Repositories fallen davor auf den lokalen Speicher zurueck), daher schickt
/// der Helper standardmaessig einen; `withAuth: false` schaltet das ab.
void startSync(Sync s, {bool withAuth = true}) {
  s.h.container.listen(widgetSyncProvider, (_, __) {});
  if (withAuth) s.auth.add(const UserEntity(id: 'u0'));
  s.h.boot();
  s.flush();
}

void main() {
  final mo = DateTime(2026, 10, 5);
  final fr = DateTime(2026, 10, 2);
  DateTime at(int h, [int m = 0, int sec = 0]) =>
      DateTime(2026, 10, 5, h, m, sec);

  group('Statuswechsel', () {
    widgetScenario('leerer Tag: notStarted, danach Start/Pause/Stop', at(8),
        (s) {
      startSync(s);
      expect(s.gateway.saves, hasLength(1));
      expect(s.gateway.last['status'], 'notStarted');
      expect(s.gateway.last['dayKey'], dayKey(mo));
      expect(s.gateway.last['locked'], false);
      expect(s.gateway.events, ['save', 'update']);

      s.h.act(s.h.vm.startOrStopTimer);
      expect(s.gateway.last['status'], 'running');
      expect(s.gateway.last['workStartMs'], at(8).millisecondsSinceEpoch);
      expect(s.gateway.last['netMinutes'], 0);
      expect(s.gateway.last['pauseStartMs'], isNull);

      s.h.tick(const Duration(minutes: 10));
      s.h.act(s.h.vm.startOrStopBreak);
      expect(s.gateway.last['status'], 'paused');
      expect(s.gateway.last['pauseStartMs'], at(8, 10).millisecondsSinceEpoch);
      expect(s.gateway.last['netMinutes'], 10);

      s.h.tick(const Duration(minutes: 5));
      s.h.act(s.h.vm.startOrStopBreak);
      expect(s.gateway.last['status'], 'running');
      expect(s.gateway.last['pauseStartMs'], isNull);

      s.h.tick(const Duration(minutes: 20));
      s.h.act(s.h.vm.startOrStopTimer);
      expect(s.gateway.last['status'], 'stopped');
      expect(s.gateway.last['netMinutes'], isNonZero);
    });

    widgetScenario('Schreiben nur bei Aenderung (Netto-Minute)', at(8), (s) {
      startSync(s);
      s.h.act(s.h.vm.startOrStopTimer);
      final count = s.gateway.saves.length;

      s.h.tick(const Duration(seconds: 29));
      expect(s.gateway.saves.length, count, reason: 'gleiche Minute');

      s.h.tick(const Duration(seconds: 32));
      expect(s.gateway.saves.length, count + 1);
      expect(s.gateway.last['netMinutes'], 1);
    });

    widgetScenario('Ladezustand wird nicht geschrieben', at(8), (s) {
      s.h.work.holdReads = true;
      startSync(s);
      expect(s.gateway.saves, isEmpty);

      s.h.work.holdReads = false;
      for (final c in s.h.work.pendingReads) {
        c.complete();
      }
      s.flush();
      expect(s.gateway.saves, hasLength(1));
      expect(s.gateway.last['status'], 'running');
    }, setUp: (h) => h.seed(entryOf(mo, start: at(7, 30))));
  });

  group('Auth und Profil', () {
    widgetScenario('kein Write vor erstem Auth-Wert, danach genau einer', at(8),
        (s) {
      startSync(s, withAuth: false);
      expect(s.gateway.saves, isEmpty);

      s.auth.add(const UserEntity(id: 'u1'));
      s.flush();
      expect(s.gateway.saves, hasLength(1));
      expect(s.gateway.last['status'], 'notStarted');
    });

    widgetScenario('Logout leert den Snapshot, erster Auth-Wert nicht', at(8),
        (s) {
      startSync(s, withAuth: false);
      s.auth.add(const UserEntity(id: 'u1'));
      s.flush();
      expect(s.gateway.events.contains('clear'), isFalse);

      s.auth.add(null);
      s.flush();
      expect(s.gateway.events.last, 'clear');
    });

    widgetScenario(
        'Profilwechsel: clear vor dem Write des neuen Profils', at(12), (s) {
      startSync(s);
      expect(s.gateway.last['status'], 'running');
      final before = s.gateway.events.length;

      s.h.switchProfile('b');
      final after = s.gateway.events.sublist(before);
      expect(after.first, 'clear');
      expect(after.sublist(1), ['save', 'update']);
      expect(s.gateway.last['status'], 'stopped');
      expect(s.gateway.last['workStartMs'], at(9).millisecondsSinceEpoch);
    }, setUp: (h) {
      h.seed(entryOf(mo, start: at(8)));
      h.workB.store[dayKey(mo)] =
          entryOf(mo, start: at(9), end: at(11), breaks: const <BreakEntity>[]);
    });
  });

  group('App-Sperre', () {
    widgetScenario('Sperre an/aus schreibt locked, Status bleibt', at(8), (s) {
      startSync(s);
      expect(s.gateway.last['locked'], false);

      expect(s.gateway.last['workStartMs'], at(7, 30).millisecondsSinceEpoch);

      s.h.container.read(isAppLockedProvider.notifier).state = true;
      s.flush();
      expect(s.gateway.last['locked'], true);
      expect(s.gateway.last['status'], 'running');
      expect(s.gateway.last['workStartMs'], isNull);
      expect(s.gateway.last['netMinutes'], 0);

      s.h.container.read(isAppLockedProvider.notifier).state = false;
      s.flush();
      expect(s.gateway.last['locked'], false);
      expect(s.gateway.last['workStartMs'], at(7, 30).millisecondsSinceEpoch);
    }, setUp: (h) => h.seed(entryOf(mo, start: at(7, 30))));

    widgetScenario('gesperrt beim Start: erster Write ist locked', at(8), (s) {
      startSync(s);
      expect(s.gateway.saves, hasLength(1));
      expect(s.gateway.last['locked'], true);
    }, lockedAtStart: true);

    widgetScenario(
        'Sperre konfiguriert: nie Zeiten, auch nicht entsperrt', at(8), (s) {
      startSync(s);
      expect(s.gateway.saves, isNotEmpty);
      for (final save in s.gateway.saves) {
        expect(save['locked'], true);
        expect(save['status'], 'running');
        expect(save['workStartMs'], isNull);
        expect(save['pauseStartMs'], isNull);
        expect(save['netMinutes'], 0);
      }

      s.h.container.read(isAppLockedProvider.notifier).state = false;
      s.h.tick(const Duration(minutes: 5));
      s.h.act(s.h.vm.startOrStopBreak);
      expect(s.gateway.last['locked'], true);
      expect(s.gateway.last['status'], 'paused');
      expect(s.gateway.last['workStartMs'], isNull);
      expect(s.gateway.last['pauseStartMs'], isNull);
      expect(s.gateway.last['netMinutes'], 0);
    },
        setUp: (h) => h.seed(entryOf(mo, start: at(7, 30))),
        lockConfigured: true);

    widgetScenario('Sperre ohne geladenen Stand schreibt nichts', at(8), (s) {
      s.h.work.holdReads = true;
      startSync(s);
      s.h.container.read(isAppLockedProvider.notifier).state = true;
      s.flush();
      expect(s.gateway.saves, isEmpty);
      s.h.work.holdReads = false;
      for (final c in s.h.work.pendingReads) {
        c.complete();
      }
      s.flush();
    });
  });

  group('Tageswechsel (#379)', () {
    widgetScenario('leerer Tag: neuer dayKey nach Mitternacht',
        DateTime(2026, 10, 2, 23, 59, 30), (s) {
      startSync(s);
      expect(s.gateway.last['dayKey'], dayKey(fr));

      s.h.tick(const Duration(seconds: 31));
      expect(s.gateway.last['dayKey'], dayKey(DateTime(2026, 10, 3)));
      expect(s.gateway.last['status'], 'notStarted');
    });

    widgetScenario(
        'laufender Timer bleibt ueber Mitternacht running mit altem '
        'dayKey',
        DateTime(2026, 10, 2, 23, 59, 30), (s) {
      startSync(s);
      s.h.tick(const Duration(seconds: 31));
      expect(s.gateway.last['status'], 'running');
      expect(s.gateway.last['dayKey'], dayKey(fr));
    }, setUp: (h) => h.seed(entryOf(fr, start: DateTime(2026, 10, 2, 22))));
  });

  group('Nutzerarten und Aufraeumen', () {
    widgetScenario('Zusaetzliches Profil verhaelt sich wie Standard', at(10),
        (s) {
      s.h.switchProfile('b');
      startSync(s);
      expect(s.gateway.last['status'], 'running');
      s.h.act(s.h.vm.startOrStopTimer);
      expect(s.gateway.last['status'], 'stopped');
    }, setUp: (h) => h.workB.store[dayKey(mo)] = entryOf(mo, start: at(9)));

    widgetScenario('keine Writes nach Dispose', at(8), (s) {
      startSync(s);
      s.h.act(s.h.vm.startOrStopTimer);
      final count = s.gateway.events.length;
      s.h.dispose();
      s.auth.add(const UserEntity(id: 'x'));
      s.auth.add(null);
      s.flush();
      expect(s.gateway.events.length, count);
    });
  });
}
