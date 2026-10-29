import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/timer_action_background.dart';
import 'package:flutter_work_time/core/services/timer_action_inbox.dart';
import 'package:flutter_work_time/domain/utils/timer_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Hintergrund-Aktionen der Erinnerungs-Buttons (#485): Weiterleitung an die
// laufende App oder Ausführung ohne App, plus gemerkte Aktion bei App-Sperre.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimerActionDispatcher', () {
    test('unbekannte oder leere Aktion wird ignoriert', () async {
      var headlessCalls = 0;
      final dispatcher = TimerActionDispatcher(
        lookupPort: () => null,
        runHeadless: (_) async {
          headlessCalls++;
          return TimerActionDispatch.headless;
        },
      );
      expect(await dispatcher.dispatch(null), TimerActionDispatch.ignored);
      expect(await dispatcher.dispatch(''), TimerActionDispatch.ignored);
      expect(
          await dispatcher.dispatch('timer_foo'), TimerActionDispatch.ignored);
      expect(headlessCalls, 0);
    });

    test('läuft die App (Port gefunden), wird die Aktion an sie gesendet',
        () async {
      final port = ReceivePort();
      final received = <Object?>[];
      port.listen(received.add);
      var headlessCalls = 0;
      final dispatcher = TimerActionDispatcher(
        lookupPort: () => port.sendPort,
        runHeadless: (_) async {
          headlessCalls++;
          return TimerActionDispatch.headless;
        },
      );

      expect(await dispatcher.dispatch('timer_pause'),
          TimerActionDispatch.forwarded);
      await Future<void>.delayed(Duration.zero);

      expect(received, ['timer_pause']);
      expect(headlessCalls, 0);
      port.close();
    });

    test('ohne laufende App läuft die Aktion im Hintergrund', () async {
      TimerAction? ran;
      final dispatcher = TimerActionDispatcher(
        lookupPort: () => null,
        runHeadless: (a) async {
          ran = a;
          return TimerActionDispatch.headless;
        },
      );
      expect(await dispatcher.dispatch('timer_start'),
          TimerActionDispatch.headless);
      expect(ran, TimerAction.start);
    });

    test('gibt der Hintergrundlauf deferred zurück (App-Sperre), bleibt es so',
        () async {
      final dispatcher = TimerActionDispatcher(
        lookupPort: () => null,
        runHeadless: (_) async => TimerActionDispatch.deferred,
      );
      expect(await dispatcher.dispatch('timer_stop'),
          TimerActionDispatch.deferred);
    });

    test('ein Fehler im Hintergrundlauf wird nicht weitergeworfen', () async {
      final dispatcher = TimerActionDispatcher(
        lookupPort: () => null,
        runHeadless: (_) async => throw StateError('boom'),
      );
      expect(
          await dispatcher.dispatch('timer_stop'), TimerActionDispatch.ignored);
    });
  });

  group('registerTimerActionPort', () {
    test('Aktionen vom Port landen im Briefkasten, Unbekanntes nicht',
        () async {
      final inbox = TimerActionInbox();
      final port = registerTimerActionPort(inbox);
      addTearDown(port.close);

      final sender = port.sendPort;
      sender.send('timer_stop');
      sender.send('timer_foo');
      sender.send(42);
      await Future<void>.delayed(Duration.zero);

      expect(inbox.takePending(), TimerAction.stop);
      expect(inbox.takePending(), isNull);
    });
  });

  group('gemerkte Aktion bei App-Sperre', () {
    final t0 = DateTime(2026, 3, 18, 9);

    Future<SharedPreferences> prefs([Map<String, Object> v = const {}]) async {
      SharedPreferences.setMockInitialValues(v);
      return SharedPreferences.getInstance();
    }

    test('wird genau einmal geliefert und gelöscht', () async {
      final p = await prefs();
      await storePendingTimerAction(p, TimerAction.start, t0);

      expect(takePendingTimerAction(p, t0.add(const Duration(minutes: 1))),
          TimerAction.start);
      expect(takePendingTimerAction(p, t0.add(const Duration(minutes: 1))),
          isNull);
      expect(p.getString(pendingTimerActionKey), isNull);
    });

    test('verfällt nach der TTL', () async {
      final p = await prefs();
      await storePendingTimerAction(p, TimerAction.stop, t0);
      expect(
          takePendingTimerAction(
              p, t0.add(pendingTimerActionTtl + const Duration(seconds: 1))),
          isNull);
    });

    test('genau an der Grenze gilt sie noch', () async {
      final p = await prefs();
      await storePendingTimerAction(p, TimerAction.pause, t0);
      expect(takePendingTimerAction(p, t0.add(pendingTimerActionTtl)),
          TimerAction.pause);
    });

    test('unlesbare oder fremde Werte werden verworfen', () async {
      for (final raw in ['', 'timer_start', 'timer_start|abc', 'foo|1', '|']) {
        final p = await prefs({pendingTimerActionKey: raw});
        expect(takePendingTimerAction(p, t0), isNull, reason: raw);
        expect(p.getString(pendingTimerActionKey), isNull, reason: raw);
      }
    });

    test('ohne Eintrag: null', () async {
      expect(takePendingTimerAction(await prefs(), t0), isNull);
    });
  });
}
