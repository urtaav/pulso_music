package com.example.pulso_music

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget "Portada": la carátula a sangre completa con un degradado oscuro,
 * artista, título, ♡, barra de progreso con tiempos y la cápsula de vidrio
 * "Pausa". El tiempo transcurrido usa un Chronometer: avanza solo sin que la
 * app tenga que actualizar el widget cada segundo.
 */
class CoverWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val state = WidgetState.from(widgetData)
        val art = WidgetArt.cover(context, state, size = 480)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, appWidgetManager, id, state, art))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val state = WidgetState.from(HomeWidgetPlugin.getData(context))
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildViews(
                context,
                appWidgetManager,
                appWidgetId,
                state,
                WidgetArt.cover(context, state, size = 480),
            ),
        )
    }

    private fun buildViews(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        state: WidgetState,
        art: Bitmap?,
    ): RemoteViews {
        val small = render(context, R.layout.widget_cover_small, state, art)
        val full = render(context, R.layout.widget_cover, state, art)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return RemoteViews(
                mapOf(
                    SizeF(100f, 100f) to small,
                    SizeF(170f, 200f) to full,
                ),
            )
        }
        val options = manager.getAppWidgetOptions(id)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        return if (width >= 170 && height >= 200) full else small
    }

    private fun render(
        context: Context,
        layout: Int,
        state: WidgetState,
        art: Bitmap?,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layout)

        if (art != null) {
            views.setImageViewBitmap(R.id.cover_art, art)
            views.setInt(R.id.cover_art, "setColorFilter", 0)
        } else {
            // Sin carátula: fondo del color de acento del widget.
            views.setImageViewResource(R.id.cover_art, R.drawable.widget_square)
            views.setInt(R.id.cover_art, "setColorFilter", state.accent)
        }

        views.setTextViewText(R.id.cover_title, state.title)
        views.setTextViewText(R.id.cover_artist, state.artist)
        views.setImageViewResource(
            R.id.cover_play_icon,
            if (state.playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
        )
        views.setOnClickPendingIntent(
            R.id.cover_play,
            WidgetIntents.action(context, WidgetActionReceiver.PLAY_PAUSE),
        )
        views.setOnClickPendingIntent(R.id.cover_root, WidgetIntents.openApp(context))

        if (layout == R.layout.widget_cover) {
            views.setTextViewText(R.id.cover_play_label, if (state.playing) "Pausa" else "Reproducir")
            views.setImageViewResource(
                R.id.cover_heart,
                if (state.favorite) R.drawable.ic_widget_heart_filled else R.drawable.ic_widget_heart,
            )
            views.setOnClickPendingIntent(
                R.id.cover_heart,
                WidgetIntents.action(context, WidgetActionReceiver.FAVORITE),
            )
            views.setOnClickPendingIntent(
                R.id.cover_prev,
                WidgetIntents.action(context, WidgetActionReceiver.PREVIOUS),
            )
            views.setOnClickPendingIntent(
                R.id.cover_next,
                WidgetIntents.action(context, WidgetActionReceiver.NEXT),
            )

            val hasTime = state.durationMs > 0
            views.setViewVisibility(R.id.cover_progress_row, if (hasTime) View.VISIBLE else View.GONE)
            if (hasTime) {
                views.setProgressBar(R.id.cover_progress, 1000, state.progressPermille(), false)
                views.setChronometer(
                    R.id.cover_elapsed,
                    state.chronometerBase(),
                    null,
                    state.playing,
                )
                views.setTextViewText(
                    R.id.cover_duration,
                    WidgetState.formatTime(state.durationMs),
                )
            }
        }
        return views
    }
}
