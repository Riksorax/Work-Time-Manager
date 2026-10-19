package app.work_time_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.os.SystemClock
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Status-Widget (#276) nach der Vorlage "Home Screen Widget": eine Widget-Familie
 * in vier Groessen (2x1 kompakt, 4x1 Leiste, 2x2 Fortschrittsring, 4x2 Uebersicht),
 * die Groesse folgt der Widget-Groesse auf dem Home-Screen.
 *
 * Der Timer ist ein natives [android.widget.Chronometer]: er zaehlt vom Snapshot
 * (`netMinutes` zum Zeitpunkt `netAtMs`) selbststaendig weiter, auch wenn die App
 * nicht laeuft. Die Buttons oeffnen die App mit dem Shortcut-Extra von
 * `quick_actions` (`timer_start`/`timer_pause`/`timer_resume`/`timer_stop`); die App
 * fuehrt die Aktion nach Entsperren aus (gleicher Weg wie die App-Icon-Shortcuts,
 * #274). Das Widget wird nur von der App aktualisiert (Dart schreibt den Snapshot
 * per `home_widget`); die Schluessel muessen zu `home_widget_gateway.dart` passen.
 * Ein Snapshot mit `locked` (App-Sperre) enthaelt keine Zeiten.
 *
 * Die Logik ist bewusst kompakt (nicht automatisiert testbar).
 */
class StatusWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val model = Model.from(widgetData)
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            appWidgetManager.updateAppWidget(appWidgetId, build(context, model, options))
        }
    }

    /** Groessenwechsel durch den Nutzer: passendes Layout waehlen. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            HomeWidgetPlugin.getData(context),
        )
    }

    // --- Zustand ---------------------------------------------------------

    private class Model(
        val effective: String,
        val locked: Boolean,
        val workStartMs: Long?,
        val pauseStartMs: Long?,
        val netMinutes: Long,
        val netAtMs: Long?,
        val targetMinutes: Long?,
        val breakMinutes: Long,
        val expectedEndMs: Long?,
        val workEndMs: Long?,
        val overtimeMinutes: Long?,
    ) {
        val hasTimes get() = workStartMs != null && workStartMs > 0
        /** Sperre blendet Zeiten nur aus, wenn schon gestartet wurde. */
        val showLock get() = locked && effective != "notStarted" && effective != "none"

        companion object {
            fun from(data: SharedPreferences): Model {
                val all = data.all
                val status = all["status"] as? String ?: "none"
                val dayKey = all["dayKey"] as? String
                // Ein Stand vom Vortag (App seit Mitternacht nicht geoeffnet) wird nicht
                // angezeigt; ein ueber Mitternacht laufender Timer bleibt "laeuft".
                val active = status == "running" || status == "paused"
                val effective = if (!active && status != "none" && dayKey != todayKey()) {
                    "notStarted"
                } else {
                    status
                }
                fun long(key: String) = (all[key] as? Number)?.toLong()
                return Model(
                    effective = effective,
                    locked = all["locked"] as? Boolean ?: false,
                    workStartMs = long("workStartMs"),
                    pauseStartMs = long("pauseStartMs"),
                    netMinutes = long("netMinutes") ?: 0L,
                    netAtMs = long("netAtMs"),
                    targetMinutes = long("targetMinutes"),
                    breakMinutes = long("breakMinutes") ?: 0L,
                    expectedEndMs = long("expectedEndMs"),
                    workEndMs = long("workEndMs"),
                    overtimeMinutes = long("overtimeMinutes"),
                )
            }

            /** Lokaler Kalendertag des Geraets als `yyyy-MM-dd` (wie `dayKey`). */
            private fun todayKey(): String =
                SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        }
    }

    private enum class Size { SMALL, BAR, SQUARE, LARGE }

    private enum class Tone { NEUTRAL, PRIMARY, TEAL, GREEN }

    // --- Aufbau ----------------------------------------------------------

    private fun build(context: Context, m: Model, options: Bundle): RemoteViews {
        val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
        val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
        val wide = minW >= 220
        val tall = minH >= 110
        val size = when {
            wide && tall -> Size.LARGE
            wide -> Size.BAR
            tall -> Size.SQUARE
            else -> Size.SMALL
        }
        val layout = when (size) {
            Size.LARGE -> R.layout.status_widget
            Size.BAR -> R.layout.status_widget_4x1
            Size.SQUARE -> R.layout.status_widget_2x2
            Size.SMALL -> R.layout.status_widget_2x1
        }
        val v = RemoteViews(context.packageName, layout)
        v.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))

        val tone = when (m.effective) {
            "running" -> Tone.PRIMARY
            "paused" -> Tone.TEAL
            "stopped" -> Tone.GREEN
            else -> Tone.NEUTRAL
        }
        val statusLabel = context.getString(
            when (m.effective) {
                "running" -> R.string.widget_status_running
                "paused" -> R.string.widget_status_paused
                "stopped" -> R.string.widget_status_stopped
                "notStarted" -> R.string.widget_status_not_started
                else -> R.string.widget_status_none
            },
        )

        // Chip (4x2, 2x2) bzw. Punkt plus Text (4x1, 2x1).
        v.setInt(R.id.w_dot, "setBackgroundResource", dotRes(tone, m.effective))
        if (size == Size.LARGE || size == Size.SQUARE) {
            v.setInt(R.id.w_chip, "setBackgroundResource", chipRes(tone, m.effective))
            v.setTextViewText(R.id.w_status, statusLabel)
            v.setTextColor(R.id.w_status, context.getColor(chipTextColor(tone, m.effective)))
        } else {
            val line = if (size == Size.BAR && m.hasTimes && !m.showLock && m.effective != "notStarted") {
                context.getString(R.string.widget_status_since, statusLabel, timeOf(context, m.workStartMs!!))
            } else {
                statusLabel
            }
            v.setTextViewText(R.id.w_status, line)
        }

        bindTimer(context, v, m)
        if (size == Size.LARGE) bindLarge(context, v, m, tone)
        if (size == Size.SQUARE) bindSquare(context, v, m, tone)
        if (size == Size.SMALL) bindProgress(v, m, tone)
        if (size == Size.BAR || size == Size.SQUARE) bindCircleButtons(context, v, m)
        return v
    }

    /** Timer: Chronometer nur bei laufendem Timer, sonst fester Text. */
    private fun bindTimer(context: Context, v: RemoteViews, m: Model) {
        val hidden = m.showLock || m.effective == "none"
        val running = m.effective == "running" && m.hasTimes && !hidden
        val color = if (m.effective == "notStarted") R.color.w_text_off else R.color.w_text
        if (running) {
            var elapsedMs = m.netMinutes * 60_000L
            if (m.netAtMs != null) {
                elapsedMs += (System.currentTimeMillis() - m.netAtMs).coerceAtLeast(0L)
            }
            v.setChronometer(R.id.w_timer, SystemClock.elapsedRealtime() - elapsedMs, null, true)
            v.setTextColor(R.id.w_timer, context.getColor(color))
            v.setViewVisibility(R.id.w_timer, View.VISIBLE)
            v.setViewVisibility(R.id.w_timer_static, View.GONE)
        } else {
            v.setViewVisibility(R.id.w_timer, View.GONE)
            v.setViewVisibility(R.id.w_timer_static, View.VISIBLE)
            v.setTextViewText(R.id.w_timer_static, if (hidden) "–:––" else hm(m.netMinutes))
            v.setTextColor(R.id.w_timer_static, context.getColor(color))
        }
    }

    /** Fortschrittsbalken: genau eine Farbe sichtbar, sonst nur die Spur. */
    private fun bindProgress(v: RemoteViews, m: Model, tone: Tone) {
        val pct = percent(m)
        val bars = mapOf(
            Tone.PRIMARY to R.id.w_bar_primary,
            Tone.TEAL to R.id.w_bar_teal,
            Tone.GREEN to R.id.w_bar_green,
        )
        for ((t, id) in bars) {
            val active = t == tone && !m.showLock && m.effective != "none"
            v.setViewVisibility(id, if (active) View.VISIBLE else View.GONE)
            if (active) v.setProgressBar(id, 100, pct, false)
        }
    }

    private fun percent(m: Model): Int {
        val target = m.targetMinutes ?: return 0
        if (target <= 0) return 0
        return ((m.netMinutes * 100) / target).toInt().coerceIn(0, 100)
    }

    // --- 4x2 -------------------------------------------------------------

    private fun bindLarge(context: Context, v: RemoteViews, m: Model, tone: Tone) {
        bindProgress(v, m, tone)

        // Unterzeile und Ueberstunden
        if (m.showLock) {
            v.setViewVisibility(R.id.w_main, View.GONE)
            v.setViewVisibility(R.id.w_lock_row, View.VISIBLE)
            v.setInt(R.id.w_lock_icon, "setColorFilter", context.getColor(R.color.w_text2))
        } else {
            v.setViewVisibility(R.id.w_main, View.VISIBLE)
            v.setViewVisibility(R.id.w_lock_row, View.GONE)
            v.setTextViewText(R.id.w_sub, subText(context, m))
            v.setTextColor(R.id.w_sub, context.getColor(R.color.w_text2))
            val ot = m.overtimeMinutes
            if (ot == null || m.effective == "none") {
                v.setViewVisibility(R.id.w_overtime_box, View.GONE)
            } else {
                v.setViewVisibility(R.id.w_overtime_box, View.VISIBLE)
                v.setTextViewText(R.id.w_overtime, signedHm(ot))
                v.setTextColor(
                    R.id.w_overtime,
                    context.getColor(if (ot >= 0) R.color.w_green else R.color.w_error),
                )
            }
        }

        // Buttons (Pillen mit Icon und Text)
        val a = view(R.id.w_btn_a, R.id.w_btn_a_icon, R.id.w_btn_a_text)
        val b = view(R.id.w_btn_b, R.id.w_btn_b_icon, R.id.w_btn_b_text)
        val spec = buttons(context, m)
        bindPill(context, v, a, spec.first)
        bindPill(context, v, b, spec.second)
    }

    // --- 2x2 -------------------------------------------------------------

    private fun bindSquare(context: Context, v: RemoteViews, m: Model, tone: Tone) {
        val pct = percent(m)
        val rings = mapOf(
            Tone.PRIMARY to R.id.w_ring_primary,
            Tone.TEAL to R.id.w_ring_teal,
            Tone.GREEN to R.id.w_ring_green,
        )
        for ((t, id) in rings) {
            val active = t == tone && !m.showLock && m.effective != "none"
            v.setViewVisibility(id, if (active) View.VISIBLE else View.GONE)
            if (active) v.setProgressBar(id, 100, pct, false)
        }
        val of = if (m.showLock || m.targetMinutes == null) "" else context.getString(R.string.widget_of, hm(m.targetMinutes))
        v.setTextViewText(R.id.w_of, of)
        v.setTextColor(R.id.w_of, context.getColor(R.color.w_text2))
    }

    // --- Kreis-Buttons (4x1, 2x2) -----------------------------------------

    private fun bindCircleButtons(context: Context, v: RemoteViews, m: Model) {
        val spec = buttons(context, m)
        bindCircle(context, v, R.id.w_btn_a, R.id.w_btn_a_icon, spec.first)
        bindCircle(context, v, R.id.w_btn_b, R.id.w_btn_b_icon, spec.second)
    }

    // --- Button-Beschreibung ---------------------------------------------

    private enum class Style { PRIMARY, CONTAINER, TEAL, NEUTRAL }

    private class Button(
        val icon: Int,
        val label: String,
        val style: Style,
        /** `null` = nicht klickbar (nur Anzeige). */
        val action: String?,
        /** true = oeffnet nur die App (Entsperren, "App oeffnen"). */
        val launch: Boolean = false,
    )

    private fun buttons(context: Context, m: Model): Pair<Button?, Button?> {
        val s = { id: Int -> context.getString(id) }
        if (m.showLock) {
            return Pair(
                Button(R.drawable.ic_w_lock_open, s(R.string.widget_unlock), Style.CONTAINER, null, launch = true),
                null,
            )
        }
        return when (m.effective) {
            "notStarted" -> Pair(
                Button(R.drawable.ic_w_play, s(R.string.widget_action_start), Style.PRIMARY, "timer_start"),
                null,
            )
            "running" -> Pair(
                Button(R.drawable.ic_w_pause, s(R.string.widget_action_pause), Style.CONTAINER, "timer_pause"),
                Button(R.drawable.ic_w_stop, s(R.string.widget_action_stop), Style.PRIMARY, "timer_stop"),
            )
            "paused" -> Pair(
                Button(R.drawable.ic_w_play, s(R.string.widget_action_resume), Style.TEAL, "timer_resume"),
                Button(R.drawable.ic_w_stop, s(R.string.widget_action_stop), Style.CONTAINER, "timer_stop"),
            )
            "stopped" -> {
                val delta = (m.netMinutes - (m.targetMinutes ?: m.netMinutes))
                Pair(
                    Button(
                        R.drawable.ic_w_check,
                        context.getString(R.string.widget_day_done, signedHm(delta)),
                        Style.NEUTRAL,
                        null,
                    ),
                    null,
                )
            }
            else -> Pair(
                Button(R.drawable.ic_w_play, s(R.string.widget_open_hint), Style.CONTAINER, null, launch = true),
                null,
            )
        }
    }

    private class Ids(val root: Int, val icon: Int, val text: Int)

    private fun view(root: Int, icon: Int, text: Int) = Ids(root, icon, text)

    private fun bgRes(style: Style) = when (style) {
        Style.PRIMARY -> R.drawable.w_btn_primary
        Style.CONTAINER -> R.drawable.w_btn_container
        Style.TEAL -> R.drawable.w_btn_teal
        Style.NEUTRAL -> R.drawable.w_btn_neutral
    }

    private fun fgColor(style: Style, icon: Int) = when (style) {
        Style.PRIMARY -> R.color.w_on_primary
        Style.CONTAINER -> R.color.w_on_container
        Style.TEAL -> R.color.w_on_primary
        Style.NEUTRAL -> if (icon == R.drawable.ic_w_check) R.color.w_green else R.color.w_text2
    }

    private fun bindPill(context: Context, v: RemoteViews, ids: Ids, b: Button?) {
        if (b == null) {
            v.setViewVisibility(ids.root, View.GONE)
            return
        }
        v.setViewVisibility(ids.root, View.VISIBLE)
        v.setInt(ids.root, "setBackgroundResource", bgRes(b.style))
        v.setImageViewResource(ids.icon, b.icon)
        v.setInt(ids.icon, "setColorFilter", context.getColor(fgColor(b.style, b.icon)))
        v.setTextViewText(ids.text, b.label)
        // Die Feierabend-Anzeige nutzt die Textfarbe des Neutral-Stils, nicht das Gruen.
        v.setTextColor(
            ids.text,
            context.getColor(if (b.style == Style.NEUTRAL) R.color.w_text2 else fgColor(b.style, b.icon)),
        )
        clickable(context, v, ids.root, b)
    }

    private fun bindCircle(context: Context, v: RemoteViews, root: Int, icon: Int, b: Button?) {
        if (b == null) {
            v.setViewVisibility(root, View.GONE)
            return
        }
        v.setViewVisibility(root, View.VISIBLE)
        v.setInt(root, "setBackgroundResource", bgRes(b.style))
        v.setImageViewResource(icon, b.icon)
        v.setInt(icon, "setColorFilter", context.getColor(fgColor(b.style, b.icon)))
        v.setContentDescription(root, b.label)
        clickable(context, v, root, b)
    }

    private fun clickable(context: Context, v: RemoteViews, id: Int, b: Button) {
        when {
            b.action != null -> v.setOnClickPendingIntent(id, actionIntent(context, b.action))
            b.launch -> v.setOnClickPendingIntent(id, launchAppIntent(context))
        }
    }

    // --- Texte -----------------------------------------------------------

    private fun subText(context: Context, m: Model): String {
        val start = m.workStartMs?.takeIf { it > 0 }?.let { timeOf(context, it) }
        return when (m.effective) {
            "running" -> when {
                start != null && m.expectedEndMs != null ->
                    context.getString(R.string.widget_since_end, start, timeOf(context, m.expectedEndMs))
                start != null -> context.getString(R.string.widget_since_only, start)
                else -> ""
            }
            "paused" -> {
                val from = m.pauseStartMs
                if (from == null) "" else {
                    val mins = ((System.currentTimeMillis() - from) / 60_000L).coerceAtLeast(0L)
                    context.getString(R.string.widget_pause_since, timeOf(context, from), hm(mins))
                }
            }
            "stopped" -> {
                val end = m.workEndMs
                if (start != null && end != null) {
                    context.getString(R.string.widget_range, start, timeOf(context, end), hm(m.breakMinutes))
                } else ""
            }
            "notStarted" -> m.targetMinutes?.let { context.getString(R.string.widget_target, hm(it)) } ?: ""
            else -> context.getString(R.string.widget_open_hint)
        }
    }

    private fun dotRes(tone: Tone, effective: String) = when (tone) {
        Tone.PRIMARY -> R.drawable.w_dot_primary
        Tone.TEAL -> R.drawable.w_dot_teal
        Tone.GREEN -> R.drawable.w_dot_green
        Tone.NEUTRAL -> R.drawable.w_dot_neutral
    }

    private fun chipRes(tone: Tone, effective: String) = when (tone) {
        Tone.PRIMARY -> R.drawable.w_chip_primary
        Tone.TEAL -> R.drawable.w_chip_teal
        else -> R.drawable.w_chip_neutral
    }

    private fun chipTextColor(tone: Tone, effective: String) = when (tone) {
        Tone.PRIMARY -> R.color.w_on_container
        Tone.TEAL -> R.color.w_on_teal_container
        else -> R.color.w_text2
    }

    private fun timeOf(context: Context, ms: Long): String =
        DateFormat.getTimeFormat(context).format(Date(ms))

    private fun hm(minutes: Long): String =
        String.format(Locale.getDefault(), "%d:%02d", minutes / 60, minutes % 60)

    private fun signedHm(minutes: Long): String =
        (if (minutes < 0) "−" else "+") + hm(Math.abs(minutes))

    // --- Intents ---------------------------------------------------------

    /**
     * Startet die App mit dem `quick_actions`-Extra; Dart behandelt es wie einen
     * App-Icon-Shortcut. Der Schluessel muss zu `QuickActions.EXTRA_ACTION` des
     * Plugins passen.
     */
    private fun actionIntent(context: Context, actionId: String): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent()
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        intent.putExtra("some unique action key", actionId)
        return PendingIntent.getActivity(
            context,
            when (actionId) {
                "timer_start" -> 1
                "timer_stop" -> 2
                "timer_pause" -> 3
                else -> 4
            },
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun launchAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent()
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
