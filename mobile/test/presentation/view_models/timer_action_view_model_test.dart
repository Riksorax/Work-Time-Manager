import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/services/timer_action_inbox.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/timer_action.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/timer_action_view_model.dart';

import '../../support/fake_clock.dart';

/// Zaehlt `performTimerAction`-Aufrufe; `build` laeuft ohne Repositories.
class _FakeDashboard extends DashboardViewModel {
  static int builds = 0;
  static final List<TimerAction> performed = [];
  static TimerActionResult result = TimerActionResult.applied;
  static Completer<TimerActionResult>? hold;

  static void reset() {
    builds = 0;
    performed.clear();
    result = TimerActionResult.applied;
    hold = null;
  }

  @override
  DashboardState build() {
    builds++;
    return DashboardState(
      workEntry: WorkEntryEntity(id: 'x', date: DateTime(2026, 10, 5)),
      elapsedTime: Duration.zero,
    );
  }

  @override
  Future<TimerActionResult> performTimerAction(TimerAction action) {
    performed.add(action);
    return hold?.future ?? Future.value(result);
  }
}

const _user = UserEntity(id: 'u1');

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late FakeClock clock;
  late TimerActionInbox inbox;
  late StreamController<UserEntity?> auth;
  late bool locked;
  late ProviderContainer container;

  ProviderContainer make() {
    final c = ProviderContainer(overrides: [
      timerActionInboxProvider.overrideWithValue(inbox),
      authStateProvider.overrideWith((ref) => auth.stream),
      isAppLockedProvider.overrideWith((ref) => locked),
      dashboardViewModelProvider.overrideWith(_FakeDashboard.new),
    ]);
    // Wie main.dart: das ViewModel wird instanziiert und gehalten.
    c.listen(timerActionViewModelProvider, (_, __) {});
    return c;
  }

  setUp(() {
    _FakeDashboard.reset();
    clock = FakeClock(DateTime.utc(2026, 10, 5, 8));
    inbox = TimerActionInbox(clock: clock.call);
    auth = StreamController<UserEntity?>();
    locked = false;
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  test('ohne Aktion keine Dashboard-ViewModel-Instanziierung', () async {
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    expect(_FakeDashboard.builds, 0);
    expect(_FakeDashboard.performed, isEmpty);
    expect(container.read(timerActionViewModelProvider).lastResult, isNull);
  });

  test('Aktion + entsperrt + Auth geladen -> performTimerAction genau einmal',
      () async {
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    inbox.push(TimerAction.start);
    await pumpEventQueue();

    expect(_FakeDashboard.performed, [TimerAction.start]);
    expect(container.read(timerActionViewModelProvider).lastResult,
        TimerActionResult.applied);
    expect(inbox.hasPending, isFalse);
  });

  test('Kaltstart: vor dem Start gepufferte Aktion wird ausgefuehrt', () async {
    inbox.push(TimerAction.stop);
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    expect(_FakeDashboard.performed, [TimerAction.stop]);
  });

  test('gesperrt: keine Ausfuehrung, nach dem Entsperren schon', () async {
    locked = true;
    container = make();
    auth.add(_user);
    inbox.push(TimerAction.start);
    await pumpEventQueue();

    expect(_FakeDashboard.performed, isEmpty);
    expect(inbox.hasPending, isTrue);

    container.read(isAppLockedProvider.notifier).state = false;
    await pumpEventQueue();

    expect(_FakeDashboard.performed, [TimerAction.start]);
  });

  test('Auth ohne Wert: wartet, nach dem ersten Wert ausgefuehrt', () async {
    container = make();
    inbox.push(TimerAction.start);
    await pumpEventQueue();

    expect(_FakeDashboard.performed, isEmpty);

    auth.add(null); // ausgeloggt = erster Wert, lokale Nutzer
    await pumpEventQueue();

    expect(_FakeDashboard.performed, [TimerAction.start]);
  });

  test('Aktion aelter als 2 Minuten wird nach dem Entsperren verworfen',
      () async {
    locked = true;
    container = make();
    auth.add(_user);
    inbox.push(TimerAction.start);
    await pumpEventQueue();

    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 3));
    container.read(isAppLockedProvider.notifier).state = false;
    await pumpEventQueue();

    expect(_FakeDashboard.performed, isEmpty);
    expect(container.read(timerActionViewModelProvider).lastResult, isNull);
  });

  test('notApplicable ist kein Fehlerzustand', () async {
    _FakeDashboard.result = TimerActionResult.notApplicable;
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    inbox.push(TimerAction.stop);
    await pumpEventQueue();

    expect(container.read(timerActionViewModelProvider).lastResult,
        TimerActionResult.notApplicable);
    expect(container.read(timerActionFailurePendingProvider), isFalse);
  });

  test('failed -> lastResult failed und Fehlerhinweis ansteht', () async {
    _FakeDashboard.result = TimerActionResult.failed;
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    inbox.push(TimerAction.stop);
    await pumpEventQueue();

    expect(container.read(timerActionViewModelProvider).lastResult,
        TimerActionResult.failed);
    expect(container.read(timerActionFailurePendingProvider), isTrue);
  });

  test('Rebuild/Auth-Wechsel konsumiert die Aktion nicht doppelt', () async {
    container = make();
    auth.add(_user);
    await pumpEventQueue();
    inbox.push(TimerAction.start);
    await pumpEventQueue();

    auth.add(null);
    auth.add(_user);
    container.read(isAppLockedProvider.notifier).state = true;
    container.read(isAppLockedProvider.notifier).state = false;
    await pumpEventQueue();

    expect(_FakeDashboard.performed, [TimerAction.start]);
  });

  test('zweite Aktion waehrend der ersten wird danach ausgefuehrt', () async {
    _FakeDashboard.hold = Completer<TimerActionResult>();
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    inbox.push(TimerAction.start);
    await pumpEventQueue();
    inbox.push(TimerAction.stop);
    await pumpEventQueue();
    expect(_FakeDashboard.performed, [TimerAction.start]);

    final hold = _FakeDashboard.hold!;
    _FakeDashboard.hold = null;
    hold.complete(TimerActionResult.applied);
    await pumpEventQueue();

    expect(_FakeDashboard.performed, [TimerAction.start, TimerAction.stop]);
  });
}
