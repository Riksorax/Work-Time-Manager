import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/assistant_query_inbox.dart';
import 'package:flutter_work_time/domain/utils/assistant_query.dart';

import '../../support/fake_clock.dart';

void main() {
  late FakeClock clock;
  late AssistantQueryInbox inbox;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 10, 5, 8));
    inbox = AssistantQueryInbox(clock: clock.call);
  });

  test('push ohne Zuhoerer puffert, takePending liefert genau einmal', () {
    inbox.push(AssistantQuery.overtime);

    expect(inbox.takePending(), AssistantQuery.overtime);
    expect(inbox.takePending(), isNull);
  });

  test('ohne push ist nichts anstehend', () {
    expect(inbox.hasPending, isFalse);
    expect(inbox.takePending(), isNull);
  });

  test('Abfrage verfaellt nach 2 Minuten still', () {
    inbox.push(AssistantQuery.leave);
    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 2, 0, 1));

    expect(inbox.hasPending, isFalse);
    expect(inbox.takePending(), isNull);
  });

  test('Abfrage ist genau an der Grenze von 2 Minuten noch gueltig', () {
    inbox.push(AssistantQuery.leave);
    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 2));

    expect(inbox.takePending(), AssistantQuery.leave);
  });

  test('neuere Abfrage ersetzt die aeltere und erneuert den Zeitstempel', () {
    inbox.push(AssistantQuery.overtime);
    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 1, 30));
    inbox.push(AssistantQuery.leave);
    clock.jumpTo(DateTime.utc(2026, 10, 5, 8, 3));

    expect(inbox.takePending(), AssistantQuery.leave);
    expect(inbox.takePending(), isNull);
  });

  test('Zuhoerer wird benachrichtigt, die Abfrage bleibt einmal konsumierbar',
      () async {
    var notified = 0;
    final sub = inbox.pushes.listen((_) => notified++);

    inbox.push(AssistantQuery.overtime);
    await Future<void>.delayed(Duration.zero);

    expect(notified, 1);
    expect(inbox.takePending(), AssistantQuery.overtime);
    expect(inbox.takePending(), isNull);
    await sub.cancel();
  });

  test('clear verwirft eine anstehende Abfrage', () {
    inbox.push(AssistantQuery.overtime);
    inbox.clear();

    expect(inbox.takePending(), isNull);
  });
}
