package app.work_time_manager

import android.content.Intent
import java.util.Locale

/**
 * Google Assistant / App Actions (#280): Der Intent aus `res/xml/shortcuts.xml`
 * (BII `actions.intent.OPEN_APP_FEATURE`) trägt das gesprochene Feature als Text
 * im Extra `feature` ("Arbeitstag starten", "Pause beenden", "clock out" ...).
 * Hier wird er auf dieselbe Timer-Aktion abgebildet wie App-Icon-Shortcuts und
 * Widget-Buttons: Extra des `quick_actions`-Plugins mit der Aktions-Id; Dart
 * führt sie dann über den Briefkasten aus (nach Auth und Entsperren).
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

    /** Setzt das Quick-Action-Extra, wenn [intent] ein Assistant-Intent ist. */
    fun normalize(intent: Intent?) {
        if (intent == null || intent.action != ACTION) return
        val id = map(intent.getStringExtra(EXTRA_FEATURE)) ?: return
        intent.putExtra(EXTRA_QUICK_ACTION, id)
    }

    /** Gesprochener Text zur Aktions-Id; `null`, wenn nichts passt. */
    fun map(feature: String?): String? {
        val text = feature?.lowercase(Locale.ROOT)?.trim().orEmpty()
        if (text.isEmpty()) return null
        fun has(vararg words: String) = words.any { text.contains(it) }

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
