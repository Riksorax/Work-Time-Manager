package app.work_time_manager

import android.content.Intent
import android.util.Log
import java.util.Locale

/**
 * Google Assistant / App Actions (#280): Der Intent aus `res/xml/shortcuts.xml`
 * (BII `actions.intent.OPEN_APP_FEATURE`) trägt das gesprochene Feature als Text
 * im Extra `feature` ("Arbeitstag starten", "Pause beenden", "clock out" ...).
 * Hier wird er auf dieselbe Timer-Aktion abgebildet wie App-Icon-Shortcuts und
 * Widget-Buttons: Extra des `quick_actions`-Plugins mit der Aktions-Id; Dart
 * führt sie dann über den Briefkasten aus (nach Auth und Entsperren).
 *
 * Abfragen (#287, "Überstunden", "Resturlaub", "Wochen-Trend") laufen über
 * denselben Intent mit eigenen Ids `query_*`; Dart zeigt die Antwort als
 * Ansicht in der App, sie verändern keine Daten.
 */
object AssistantTimerIntent {
    const val ACTION = "app.work_time_manager.ASSISTANT_TIMER"
    const val EXTRA_FEATURE = "feature"

    /** Extra, das das `quick_actions`-Plugin als Shortcut-Typ liest. */
    const val EXTRA_QUICK_ACTION = "some unique action key"

    const val START = "timer_start"
    const val STOP = "timer_stop"
    const val PAUSE = "timer_pause"
    const val RESUME = "timer_resume"

    const val QUERY_OVERTIME = "query_overtime"
    const val QUERY_LEAVE = "query_leave"
    const val QUERY_TREND = "query_trend"

    /** Setzt das Quick-Action-Extra, wenn [intent] ein Assistant-Intent ist. */
    fun normalize(intent: Intent?) {
        if (intent == null || intent.action != ACTION) return
        val id = map(intent.getStringExtra(EXTRA_FEATURE))
        Log.i("WtmAssistant", "feature='${intent.getStringExtra(EXTRA_FEATURE)}' -> $id")
        if (id == null) return
        intent.putExtra(EXTRA_QUICK_ACTION, id)
    }

    /** Gesprochener Text zur Aktions-Id; `null`, wenn nichts passt. */
    fun map(feature: String?): String? {
        val text = feature?.lowercase(Locale.ROOT)?.trim().orEmpty()
        if (text.isEmpty()) return null
        fun has(vararg words: String) = words.any { text.contains(it) }

        // Abfragen ZUERST (#287): der Abgleich prüft mit "enthält", und das
        // Stop-Wort "end" steckt in "Wochen-Trend"/"weekly trend". Würden die
        // Timer-Wörter zuerst geprüft, stempelte "Trend" den Nutzer aus.
        if (has("trend")) return QUERY_TREND
        if (has("überstunden", "gleitzeit", "overtime", "flextime")) return QUERY_OVERTIME
        // Bewusst nicht "leave" allein: "leave work" darf keine Abfrage sein.
        if (has("resturlaub", "urlaub", "vacation", "leave balance", "remaining leave", "annual leave", "days off")) {
            return QUERY_LEAVE
        }

        if (has("pause", "break")) {
            return if (has("beend", "ende", "end", "stop", "weiter", "resume", "fortsetz", "finish")) RESUME
            else PAUSE
        }
        if (has("ausstempel", "clock out", "check out", "stop", "stopp", "beend", "feierabend", "ende", "end")) {
            return STOP
        }
        if (has("einstempel", "clock in", "check in", "start", "beginn", "begin")) return START
        return null
    }
}
