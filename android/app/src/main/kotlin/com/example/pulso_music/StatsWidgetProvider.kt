package com.example.pulso_music

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget "Tu semana": minutos escuchados esta semana y la gráfica por día
 * (L–D) con el día récord resaltado. Sin más texto: en tamaños chicos se apachurra.
 */
class StatsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val state = WidgetState.from(widgetData)
        val chart = WidgetArt.weekChart(state)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_stats)
            views.setInt(R.id.widget_bg, "setColorFilter", state.background)
            views.setInt(R.id.widget_bg, "setImageAlpha", state.alpha)

            views.setTextViewText(R.id.stats_total, WidgetState.formatMinutes(state.weekMinutes.sum()))
            views.setTextColor(R.id.stats_total, state.foreground)
            views.setTextColor(R.id.stats_title, state.secondary)
            views.setInt(R.id.stats_wave, "setColorFilter", state.accent)
            views.setImageViewBitmap(R.id.stats_chart, chart)
            views.setOnClickPendingIntent(R.id.widget_root, WidgetIntents.openApp(context))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
