/// Sprachabfragen über den Google Assistant (#287): reine Ids und Abbildung,
/// kein Riverpod, kein Plugin.
///
/// Abfragen sind bewusst **keine** `TimerAction`: sie zeigen nur eine Antwort
/// in der App und verändern keine Daten. Sie kommen über denselben Weg wie die
/// Timer-Befehle (Assistant-Intent -> `quick_actions`-Extra), aber mit eigenen
/// Ids `query_*`.
library;

/// Abfrage, deren Antwort die App als Ansicht über dem Dashboard zeigt.
enum AssistantQuery { overtime, leave }

/// Id für [AssistantQuery.overtime] (Gesamt-Überstunden).
const String queryOvertimeId = 'query_overtime';

/// Id für [AssistantQuery.leave] (Resturlaub des laufenden Jahres).
const String queryLeaveId = 'query_leave';

/// Id der Trend-Abfrage. Der Assistant-Abgleich erkennt sie schon (damit
/// „Wochen-Trend“ nie ausstempelt), die Ansicht dazu folgt erst mit Teil B
/// von #287. Bis dahin verwirft die App sie still (nur Log).
const String queryTrendId = 'query_trend';

/// Id zu einer [AssistantQuery].
String assistantQueryId(AssistantQuery query) => switch (query) {
      AssistantQuery.overtime => queryOvertimeId,
      AssistantQuery.leave => queryLeaveId,
    };

/// [AssistantQuery] zu einer Id; unbekannt, leer, `null` oder die noch nicht
/// unterstützte [queryTrendId] ergibt `null`.
AssistantQuery? assistantQueryFromId(String? id) => switch (id) {
      queryOvertimeId => AssistantQuery.overtime,
      queryLeaveId => AssistantQuery.leave,
      _ => null,
    };
