import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/timer_action_inbox.dart';
import 'package:flutter_work_time/domain/utils/timer_action.dart';

import '../../support/fake_clock.dart';

void main() {
  late FakeClock clock;
  late TimerActionInbox inbox;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 10, 5, 8));
    inbox = TimerActionInbox(clock: clock.call);
  });

  test('push ohne Zuhoerer puffert, takePending liefert genau einmal', () {
    inbox.push(TimerAction.start);

    expect(inbox.takePending(), TimerAction.start);
    expect(inbox.takePending(), isNull);
  });

  test('ohne push ist nichts anstehend', () {
    expect(inbox.takePending(), isNull);
  });

  test('Aktion verfaellt nach 2 Minuten', () {
    inbox.push(TimerAction.stop);
    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 2, 0, 1));

    expect(inbox.takePending(), isNull);
  });

  test('Aktion ist genau an der Grenze von 2 Minuten noch gueltig', () {
    inbox.push(TimerAction.stop);
    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 2));

    expect(inbox.takePending(), TimerAction.stop);
  });

  test('neuere Aktion ersetzt die aeltere und erneuert den Zeitstempel', () {
    inbox.push(TimerAction.start);
    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 1, 30));
    inbox.push(TimerAction.stop);
    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 3));

    expect(inbox.takePending(), TimerAction.stop);
    expect(inbox.takePending(), isNull);
  });

  test('Zuhoerer wird benachrichtigt, die Aktion bleibt einmal konsumierbar',
      () async {
    var notified = 0;
    final sub = inbox.pushes.listen((_) => notified++);

    inbox.push(TimerAction.start);
    await Future<void>.delayed(Duration.zero);

    expect(notified, 1);
    expect(inbox.takePending(), TimerAction.start);
    expect(inbox.takePending(), isNull);
    await sub.cancel();
  });

  test('hasPending spiegelt Verfall und Konsum', () {
    expect(inbox.hasPending, isFalse);
    inbox.push(TimerAction.start);
    expect(inbox.hasPending, isTrue);
    clock.jumpTo(DateTime.utc(2026, 10, 5, 9));
    expect(inbox.hasPending, isFalse);
  });

  test('clear verwirft eine anstehende Aktion', () {
    inbox.push(TimerAction.start);
    inbox.clear();
    expect(inbox.takePending(), isNull);
  });
}
