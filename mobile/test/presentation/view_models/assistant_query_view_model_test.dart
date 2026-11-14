import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/services/assistant_query_inbox.dart';
import 'package:flutter_work_time/domain/entities/user_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/utils/assistant_query.dart';
import 'package:flutter_work_time/domain/utils/timer_action.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/assistant_query_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';

import '../../support/fake_clock.dart';

/// Zaehlt Instanziierungen und Timer-Aktionen: eine Abfrage darf das
/// Dashboard-ViewModel weder bauen noch eine Aktion ausloesen (#287).
class _FakeDashboard extends DashboardViewModel {
  static int builds = 0;
  static final List<TimerAction> performed = [];

  static void reset() {
    builds = 0;
    performed.clear();
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
    return Future.value(TimerActionResult.applied);
  }
}

const _user = UserEntity(id: 'u1');

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  late FakeClock clock;
  late AssistantQueryInbox inbox;
  late StreamController<UserEntity?> auth;
  late bool locked;
  late ProviderContainer container;
  late List<AssistantQuery?> delivered;

  ProviderContainer make() {
    final c = ProviderContainer(overrides: [
      assistantQueryInboxProvider.overrideWithValue(inbox),
      authStateProvider.overrideWith((ref) => auth.stream),
      isAppLockedProvider.overrideWith((ref) => locked),
      dashboardViewModelProvider.overrideWith(_FakeDashboard.new),
    ]);
    // Wie main.dart: das ViewModel wird instanziiert und gehalten.
    c.listen(assistantQueryViewModelProvider, (_, __) {});
    // Wie der DashboardScreen: jede zugestellte Abfrage abholen.
    c.listen<AssistantQuery?>(assistantQueryPendingProvider, (_, next) {
      if (next == null) return;
      delivered.add(next);
      c.read(assistantQueryPendingProvider.notifier).state = null;
    });
    return c;
  }

  setUp(() {
    _FakeDashboard.reset();
    clock = FakeClock(DateTime.utc(2026, 10, 5, 8));
    inbox = AssistantQueryInbox(clock: clock.call);
    auth = StreamController<UserEntity?>();
    locked = false;
    delivered = [];
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  test('ohne Abfrage nichts zugestellt', () async {
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    expect(delivered, isEmpty);
    expect(container.read(assistantQueryPendingProvider), isNull);
    expect(container.read(assistantQueryViewModelProvider).lastQuery, isNull);
  });

  test('Abfrage + entsperrt + Auth geladen -> genau einmal zugestellt',
      () async {
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    inbox.push(AssistantQuery.overtime);
    await pumpEventQueue();

    expect(delivered, [AssistantQuery.overtime]);
    expect(
        container.read(assistantQueryViewModelProvider),
        const AssistantQueryState(
            lastQuery: AssistantQuery.overtime, handled: 1));
    expect(inbox.hasPending, isFalse);
  });

  test('Abfrage beruehrt das Dashboard-ViewModel nicht', () async {
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    inbox.push(AssistantQuery.overtime);
    await pumpEventQueue();
    inbox.push(AssistantQuery.leave);
    await pumpEventQueue();

    expect(delivered, [AssistantQuery.overtime, AssistantQuery.leave]);
    expect(_FakeDashboard.builds, 0);
    expect(_FakeDashboard.performed, isEmpty);
  });

  test('Kaltstart: vor dem Start gepufferte Abfrage wird zugestellt', () async {
    inbox.push(AssistantQuery.leave);
    container = make();
    auth.add(_user);
    await pumpEventQueue();

    expect(delivered, [AssistantQuery.leave]);
  });

  test('gesperrt: nichts zugestellt, nach dem Entsperren schon', () async {
    locked = true;
    container = make();
    auth.add(_user);
    inbox.push(AssistantQuery.overtime);
    await pumpEventQueue();

    expect(delivered, isEmpty);
    expect(inbox.hasPending, isTrue);

    container.read(isAppLockedProvider.notifier).state = false;
    await pumpEventQueue();

    expect(delivered, [AssistantQuery.overtime]);
  });

  test('Auth ohne Wert: wartet, nach dem ersten Wert zugestellt', () async {
    container = make();
    inbox.push(AssistantQuery.overtime);
    await pumpEventQueue();

    expect(delivered, isEmpty);

    auth.add(null); // ausgeloggt = erster Wert
    await pumpEventQueue();

    expect(delivered, [AssistantQuery.overtime]);
  });

  test('Abfrage aelter als 2 Minuten verfaellt beim Entsperren still',
      () async {
    locked = true;
    container = make();
    auth.add(_user);
    inbox.push(AssistantQuery.leave);
    await pumpEventQueue();

    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 3));
    container.read(isAppLockedProvider.notifier).state = false;
    await pumpEventQueue();

    expect(delivered, isEmpty);
    expect(container.read(assistantQueryPendingProvider), isNull);
    expect(container.read(assistantQueryViewModelProvider).lastQuery, isNull);
  });

  test('Rebuild/Auth-Wechsel stellt die Abfrage nicht doppelt zu', () async {
    container = make();
    auth.add(_user);
    await pumpEventQueue();
    inbox.push(AssistantQuery.overtime);
    await pumpEventQueue();

    auth.add(null);
    auth.add(_user);
    container.read(isAppLockedProvider.notifier).state = true;
    container.read(isAppLockedProvider.notifier).state = false;
    await pumpEventQueue();

    expect(delivered, [AssistantQuery.overtime]);
  });
}
