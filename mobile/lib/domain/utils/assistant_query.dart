/// Sprachabfragen über den Google Assistant (#287): reine Ids und Abbildung,
/// kein Riverpod, kein Plugin.
///
/// Abfragen sind bewusst **keine** `TimerAction`: sie zeigen nur eine Antwort
/// in der App und verändern keine Daten. Sie kommen über denselben Weg wie die
/// Timer-Befehle (Assistant-Intent -> `quick_actions`-Extra), aber mit eigenen
/// Ids `query_*`.
library;

/// Abfrage, deren Antwort die App als Ansicht über dem Dashboard zeigt.
enum AssistantQuery { overtime, leave, trend }

/// Id für [AssistantQuery.overtime] (Gesamt-Überstunden).
const String queryOvertimeId = 'query_overtime';

/// Id für [AssistantQuery.leave] (Resturlaub des laufenden Jahres).
const String queryLeaveId = 'query_leave';

/// Id für [AssistantQuery.trend] (Wochen-Trend wie in der Trend-Ansicht,
/// Teil B von #287). Der Assistant-Abgleich prüft die Abfrage-Stichwörter vor
/// den Timer-Stichwörtern, damit „Wochen-Trend“ (enthält „end“) nie
/// ausstempelt.
const String queryTrendId = 'query_trend';

/// Id zu einer [AssistantQuery].
String assistantQueryId(AssistantQuery query) => switch (query) {
      AssistantQuery.overtime => queryOvertimeId,
      AssistantQuery.leave => queryLeaveId,
      AssistantQuery.trend => queryTrendId,
    };

/// [AssistantQuery] zu einer Id; unbekannt, leer oder `null` ergibt `null`.
AssistantQuery? assistantQueryFromId(String? id) => switch (id) {
      queryOvertimeId => AssistantQuery.overtime,
      queryLeaveId => AssistantQuery.leave,
      queryTrendId => AssistantQuery.trend,
      _ => null,
    };
