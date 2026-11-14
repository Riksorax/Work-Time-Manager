import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/assistant_query.dart';
import 'package:flutter_work_time/domain/utils/timer_action.dart';

void main() {
  test('Ids stimmen mit AssistantTimerIntent.kt ueberein', () {
    expect(queryOvertimeId, 'query_overtime');
    expect(queryLeaveId, 'query_leave');
    expect(queryTrendId, 'query_trend');
  });

  test('Id <-> Abfrage in beide Richtungen', () {
    for (final q in AssistantQuery.values) {
      expect(assistantQueryFromId(assistantQueryId(q)), q);
    }
  });

  test('Trend, unbekannt, leer und null ergeben keine Abfrage', () {
    expect(assistantQueryFromId(queryTrendId), isNull);
    expect(assistantQueryFromId('query_irgendwas'), isNull);
    expect(assistantQueryFromId(''), isNull);
    expect(assistantQueryFromId(null), isNull);
  });

  test('Abfrage-Ids sind keine Timer-Aktionen und umgekehrt', () {
    for (final id in [queryOvertimeId, queryLeaveId, queryTrendId]) {
      expect(timerActionFromId(id), isNull, reason: id);
    }
    for (final a in TimerAction.values) {
      expect(assistantQueryFromId(timerActionId(a)), isNull);
    }
  });
}
