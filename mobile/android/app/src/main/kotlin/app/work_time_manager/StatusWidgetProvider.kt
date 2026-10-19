package app.work_time_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.SystemClock
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Status-Widget (#276): Status, Live-Timer (Netto der heutigen Arbeitszeit),
 * "Seit HH:mm" und Start-/Pause-/Stopp-Buttons.
 *
 * Der Timer ist ein natives [android.widget.Chronometer]: er zaehlt vom
 * Snapshot (`netMinutes` zum Zeitpunkt `netAtMs`) selbststaendig weiter, auch
 * wenn die App nicht laeuft. Der Button oeffnet die App mit dem Shortcut-Extra
 * von `quick_actions` (`timer_start`/`timer_stop`/`timer_pause`/`timer_resume`); die App fuehrt die Aktion
 * nach Entsperren aus (gleicher Weg wie die App-Icon-Shortcuts, #274).
 *
 * Wird nur von der App aktualisiert (Dart schreibt den Snapshot per `home_widget`
 * und löst [onUpdate] aus). Die Schlüssel müssen zu `home_widget_gateway.dart`
 * passen. Tipp auf das Widget öffnet die App. Ein Snapshot mit `locked` (App-Sperre
 * aktiviert) enthält keine Zeiten; das Widget zeigt dann "App gesperrt" (bei
 * "nicht gestartet" nur den Status).
 *
 * Die Logik ist bewusst klein gehalten (nicht automatisiert testbar).
 */
class StatusWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.status_widget)
            render(context, views, widgetData)
            views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun render(context: Context, views: RemoteViews, data: SharedPreferences) {
        val all = data.all
        val status = all["status"] as? String ?: "none"
        val dayKey = all["dayKey"] as? String
        val locked = all["locked"] as? Boolean ?: false
        val workStartMs = (all["workStartMs"] as? Number)?.toLong()
        val netMinutes = (all["netMinutes"] as? Number)?.toLong() ?: 0L
        val netAtMs = (all["netAtMs"] as? Number)?.toLong()

        // Ein Stand vom Vortag (App seit Mitternacht nicht geöffnet) wird nicht
        // angezeigt; ein über Mitternacht laufender Timer bleibt "läuft".
        val active = status == "running" || status == "paused"
        val effective = if (!active && status != "none" && dayKey != todayKey()) {
            "notStarted"
        } else {
            status
        }

        val statusRes = when (effective) {
            "running" -> R.string.widget_status_running
            "paused" -> R.string.widget_status_paused
            "stopped" -> R.string.widget_status_stopped
            "notStarted" -> R.string.widget_status_not_started
            else -> R.string.widget_status_none
        }
        views.setTextViewText(R.id.widget_status, context.getString(statusRes))

        val hasTimes = effective == "running" || effective == "paused" || effective == "stopped"
        var line1: String? = null
        var showTimer = false
        if (effective == "none") {
            line1 = context.getString(R.string.widget_open_hint)
        } else if (locked && effective != "notStarted") {
            line1 = context.getString(R.string.widget_locked)
        } else if (hasTimes && workStartMs != null && workStartMs > 0) {
            val time = DateFormat.getTimeFormat(context).format(Date(workStartMs))
            line1 = context.getString(R.string.widget_since, time)
            showTimer = true
        }
        setLine(views, R.id.widget_since, line1)

        if (showTimer) {
            var elapsedMs = netMinutes * 60_000L
            if (effective == "running" && netAtMs != null) {
                elapsedMs += (System.currentTimeMillis() - netAtMs).coerceAtLeast(0L)
            }
            views.setChronometer(
                R.id.widget_timer,
                SystemClock.elapsedRealtime() - elapsedMs,
                null,
                effective == "running",
            )
            views.setViewVisibility(R.id.widget_timer, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_timer, View.GONE)
        }

        // Start bei "nicht gestartet"; bei laufend/pausiert Pause bzw. Weiter plus
        // Stopp; sonst keine Buttons.
        val primary = when (effective) {
            "notStarted" -> "timer_start"
            "running", "paused" -> "timer_stop"
            else -> null
        }
        val secondary = when (effective) {
            "running" -> "timer_pause"
            "paused" -> "timer_resume"
            else -> null
        }
        setButton(context, views, R.id.widget_action, primary)
        setButton(context, views, R.id.widget_pause, secondary)
        views.setViewVisibility(
            R.id.widget_buttons,
            if (primary == null) View.GONE else View.VISIBLE,
        )
    }

    private fun setButton(context: Context, views: RemoteViews, viewId: Int, actionId: String?) {
        if (actionId == null) {
            views.setViewVisibility(viewId, View.GONE)
            return
        }
        val label = when (actionId) {
            "timer_start" -> R.string.widget_action_start
            "timer_stop" -> R.string.widget_action_stop
            "timer_pause" -> R.string.widget_action_pause
            else -> R.string.widget_action_resume
        }
        views.setTextViewText(viewId, context.getString(label))
        views.setOnClickPendingIntent(viewId, actionIntent(context, actionId))
        views.setViewVisibility(viewId, View.VISIBLE)
    }

    private fun setLine(views: RemoteViews, viewId: Int, text: String?) {
        if (text == null) {
            views.setViewVisibility(viewId, View.GONE)
        } else {
            views.setTextViewText(viewId, text)
            views.setViewVisibility(viewId, View.VISIBLE)
        }
    }

    /** Lokaler Kalendertag des Geräts als `yyyy-MM-dd` (wie `dayKey` im Snapshot). */
    private fun todayKey(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

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
