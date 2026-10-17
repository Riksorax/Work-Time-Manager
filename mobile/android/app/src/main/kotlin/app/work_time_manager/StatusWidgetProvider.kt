package app.work_time_manager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Status-Widget (#276): Status, "Seit HH:mm" und Netto der heutigen Arbeitszeit.
 *
 * Wird nur von der App aktualisiert (Dart schreibt den Snapshot per `home_widget`
 * und löst [onUpdate] aus). Die Schlüssel müssen zu `home_widget_gateway.dart`
 * passen. Tipp auf das Widget öffnet die App. Ein Snapshot mit `locked` (aktive
 * App-Sperre) zeigt nur den Status, keine Zeiten.
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
        var line2: String? = null
        if (effective == "none") {
            line1 = context.getString(R.string.widget_open_hint)
        } else if (locked && effective != "notStarted") {
            line1 = context.getString(R.string.widget_locked)
        } else if (hasTimes && workStartMs != null && workStartMs > 0) {
            val time = DateFormat.getTimeFormat(context).format(Date(workStartMs))
            line1 = context.getString(R.string.widget_since, time)
            line2 = context.getString(
                R.string.widget_net,
                String.format(Locale.getDefault(), "%d:%02d", netMinutes / 60, netMinutes % 60),
            )
        }
        setLine(views, R.id.widget_since, line1)
        setLine(views, R.id.widget_net, line2)
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
