import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/domain/repositories/work_profile_repository.dart';
import 'package:flutter_work_time/presentation/view_models/work_profile_view_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

class _FakeProfileRepo implements WorkProfileRepository {
  final added = <String>[];
  final deleted = <String>[];

  @override
  Future<WorkProfileEntity> addProfile(String name) async {
    added.add(name);
    return WorkProfileEntity(id: 'p1', name: name);
  }

  @override
  Future<void> deleteProfile(String profileId) async => deleted.add(profileId);

  @override
  Future<List<WorkProfileEntity>> getAdditionalProfiles() async => const [];
}

class _ThrowingDashboard extends DashboardViewModel {
  @override
  DashboardState build() => throw StateError('nicht baubar');
}

// Guard vor dem Profilwechsel (#388, PR 2). Mo 2026-10-05, Uhr 17:00, A
// laufend ab 08:00.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final mo = DateTime(2026, 10, 5);
  final moKey = dayKey(mo);
  DateTime at(int h) => DateTime(2026, 10, 5, h);
  final running = entryOf(mo, start: at(8));
  final finished = entryOf(mo, start: at(8), end: at(17));

  void Function(Harness) prep([WorkEntryEntity? a]) => (h) {
        h.seed(a ?? running);
        h.overtime.stored = const Duration(minutes: 120);
      };

  WorkProfileViewModel guardVm(Harness h) =>
      h.container.read(workProfileViewModelProvider);

  /// Ruft den Guard auf; [confirm] zaehlt Aufrufe in [calls].
  ({ProfileSwitchGuardResult? Function() result, bool Function() done}) run(
    Harness h,
    List<int> calls, {
    Future<bool> Function()? confirm,
  }) {
    ProfileSwitchGuardResult? result;
    var done = false;
    unawaited(guardVm(h).checkSwitchAllowed(confirm: () {
      calls.add(1);
      return confirm != null ? confirm() : Future.value(true);
    }).then((v) {
      result = v;
      done = true;
    }));
    h.async.flushMicrotasks();
    return (result: () => result, done: () => done);
  }

  int entryWrites(Harness h) =>
      h.writeLog.where((e) => e.contains(':entry:')).length;

  group('checkSwitchAllowed', () {
    scenario('G1 kein Timer: allowed ohne confirm', at(17), (h) {
      h.boot();
      final calls = <int>[];
      final r = run(h, calls);
      expect(r.result(), ProfileSwitchGuardResult.allowed);
      expect(calls, isEmpty);
    }, setUp: prep(finished), profiles: true);

    scenario(
        'G2 confirm true, Stop ok: allowed, Eintrag in A gespeichert', at(17),
        (h) {
      h.boot();
      final calls = <int>[];
      final r = run(h, calls);
      expect(r.result(), ProfileSwitchGuardResult.allowed);
      expect(calls, hasLength(1));
      // Reihenfolge seit #412: Eintrag vor Saldo.
      expect(h.writeLog, [
        'A:entry:$moKey:08:00-17:00',
        'A:overtime:135',
        'A:lastUpdate',
      ]);
    }, setUp: prep(), profiles: true);

    scenario('G3 confirm false: cancelled, keine Writes, Timer laeuft', at(17),
        (h) {
      h.boot();
      final r = run(h, [], confirm: () async => false);
      expect(r.result(), ProfileSwitchGuardResult.cancelled);
      expect(h.writeLog, isEmpty);
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.workEntry.workEnd, isNull);
    }, setUp: prep(), profiles: true);

    scenario('G4 Stop scheitert: saveFailed, State/Timer unveraendert', at(17),
        (h) {
      h.boot();
      h.overtime.failSaveOvertime = true;
      final r = run(h, []);
      expect(r.result(), ProfileSwitchGuardResult.saveFailed);
      // #412: Eintrag neu + Kompensation auf den Vorzustand.
      expect(entryWrites(h), 2);
      expect(h.writeLog.last, 'A:entry:$moKey:08:00--');
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.workEntry.workEnd, isNull);
    }, setUp: prep(), profiles: true);

    scenario(
        'E19 Eintrag-Fehler: saveFailed, nichts geschrieben, Profil bleibt',
        at(17), (h) {
      h.boot();
      h.work.failSaves = true;
      final r = run(h, []);
      expect(r.result(), ProfileSwitchGuardResult.saveFailed);
      expect(h.writeLog, isEmpty);
      expect(h.async.periodicTimerCount, 1);
      expect(h.state.workEntry.workEnd, isNull);
    }, setUp: prep(), profiles: true);

    scenario('G5 isLoading: allowed ohne confirm', at(17), (h) {
      h.work.holdReads = true;
      h.boot();
      expect(h.state.isLoading, isTrue);
      final calls = <int>[];
      final r = run(h, calls);
      expect(r.result(), ProfileSwitchGuardResult.allowed);
      expect(calls, isEmpty);
      h.work.holdReads = false;
      for (final c in h.work.pendingReads) {
        c.complete();
      }
      h.async.flushMicrotasks();
    }, setUp: prep(), profiles: true);

    scenario('G6 Reentranz: busy, danach wieder frei', at(17), (h) {
      h.boot();
      final dialog = Completer<bool>();
      final calls = <int>[];
      final first = run(h, calls, confirm: () => dialog.future);
      expect(first.done(), isFalse);

      final second = run(h, calls);
      expect(second.result(), ProfileSwitchGuardResult.busy);
      expect(calls, hasLength(1));

      dialog.complete(false);
      h.async.flushMicrotasks();
      expect(first.result(), ProfileSwitchGuardResult.cancelled);

      final third = run(h, calls, confirm: () async => false);
      expect(third.result(), ProfileSwitchGuardResult.cancelled);
      expect(calls, hasLength(2));
    }, setUp: prep(), profiles: true);

    scenario('G6b confirm wirft: cancelled, Flag zurueckgesetzt', at(17), (h) {
      h.boot();
      final r = run(h, [], confirm: () async => throw StateError('boom'));
      expect(r.result(), ProfileSwitchGuardResult.cancelled);
      final again = run(h, [], confirm: () async => false);
      expect(again.result(), ProfileSwitchGuardResult.cancelled);
      expect(h.writeLog, isEmpty);
    }, setUp: prep(), profiles: true);

    final repo = _FakeProfileRepo();
    scenario('G7 addProfile/deleteProfile rufen den Guard nicht', at(17), (h) {
      h.boot();
      final vm = h.container.read(workProfileViewModelProvider);

      // addProfile: kein Stop, kein Dialog; wechselt (friert A ein).
      unawaited(vm.addProfile('X'));
      h.async.flushMicrotasks();
      h.async.elapse(Duration.zero);
      expect(repo.added, ['X']);
      expect(h.container.read(activeWorkProfileIdProvider), 'p1');
      expect(h.writeLog, isEmpty);

      // deleteProfile(aktiv): wechselt auf Standard, ohne Stop in B.
      unawaited(vm.deleteProfile('p1'));
      h.async.flushMicrotasks();
      h.async.elapse(Duration.zero);
      expect(repo.deleted, ['p1']);
      expect(h.container.read(activeWorkProfileIdProvider), isNull);
      expect(h.writeLog, isEmpty);
    },
        setUp: prep(),
        profiles: true,
        overrides: [workProfileRepositoryProvider.overrideWithValue(repo)]);

    test('G8 Dashboard nicht baubar: allowed ohne confirm', () async {
      final container = ProviderContainer(overrides: [
        dashboardViewModelProvider.overrideWith(_ThrowingDashboard.new),
      ]);
      addTearDown(container.dispose);
      var calls = 0;
      final result = await container
          .read(workProfileViewModelProvider)
          .checkSwitchAllowed(confirm: () async {
        calls++;
        return true;
      });
      expect(result, ProfileSwitchGuardResult.allowed);
      expect(calls, 0);
    });
  });
}
