package com.example.pulso_music

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget "Reproductor" (Now Playing compacto). Conserva el nombre de clase del
 * widget original para que el que ya está en la pantalla de inicio siga vivo.
 *
 * Tres diseños según el tamaño: pequeño (portada + play), compacto
 * horizontal (portada, título y ⏮ ⏯ ⏭) y grande (portada arriba).
 */
class PlayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val state = WidgetState.from(widgetData)
        val art = WidgetArt.cover(context, state)
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
        // Antes de Android 12 hay que elegir el diseño a mano al redimensionar.
        val state = WidgetState.from(HomeWidgetPlugin.getData(context))
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildViews(context, appWidgetManager, appWidgetId, state, WidgetArt.cover(context, state)),
        )
    }

    private fun buildViews(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        state: WidgetState,
        art: Bitmap?,
    ): RemoteViews {
        val small = render(context, R.layout.widget_small, state, art)
        val medium = render(context, R.layout.widget_medium, state, art)
        val large = render(context, R.layout.widget_large, state, art)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android elige el diseño más grande que quepa en el tamaño actual.
            return RemoteViews(
                mapOf(
                    SizeF(100f, 100f) to small,
                    SizeF(220f, 100f) to medium,
                    SizeF(220f, 220f) to large,
                ),
            )
        }
        val options = manager.getAppWidgetOptions(id)
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        return when {
            width >= 220 && height >= 220 -> large
            width >= 220 -> medium
            else -> small
        }
    }

    private fun render(
        context: Context,
        layout: Int,
        state: WidgetState,
        art: Bitmap?,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layout)

        // Fondo: forma redondeada blanca teñida con el color elegido por el usuario.
        views.setInt(R.id.widget_bg, "setColorFilter", state.background)
        views.setInt(R.id.widget_bg, "setImageAlpha", state.alpha)

        if (art != null) {
            views.setImageViewBitmap(R.id.widget_art, art)
            views.setInt(R.id.widget_art, "setColorFilter", Color.TRANSPARENT)
            views.setViewVisibility(R.id.widget_art_placeholder, View.GONE)
        } else {
            views.setImageViewResource(R.id.widget_art, R.drawable.widget_art_bg)
            views.setInt(R.id.widget_art, "setColorFilter", state.accent)
            views.setViewVisibility(R.id.widget_art_placeholder, View.VISIBLE)
            views.setInt(R.id.widget_art_placeholder, "setColorFilter", state.onAccent)
        }

        if (layout != R.layout.widget_small) {
            views.setTextViewText(R.id.widget_title, state.title)
            views.setTextViewText(R.id.widget_artist, state.artist)
            views.setTextColor(R.id.widget_title, state.foreground)
            views.setTextColor(R.id.widget_artist, state.secondary)
            views.setInt(R.id.widget_prev, "setColorFilter", state.foreground)
            views.setInt(R.id.widget_next, "setColorFilter", state.foreground)
            views.setOnClickPendingIntent(
                R.id.widget_prev,
                WidgetIntents.action(context, WidgetActionReceiver.PREVIOUS),
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                WidgetIntents.action(context, WidgetActionReceiver.NEXT),
            )
        }

        views.setImageViewResource(
            R.id.widget_play,
            if (state.playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
        )
        if (layout == R.layout.widget_medium) {
            // Estilo Now Playing: controles grandes sin círculo, del color del texto.
            views.setViewVisibility(R.id.widget_play_bg, View.GONE)
            views.setInt(R.id.widget_play, "setColorFilter", state.foreground)
        } else {
            views.setInt(R.id.widget_play_bg, "setColorFilter", state.accent)
            views.setInt(R.id.widget_play, "setColorFilter", state.onAccent)
        }
        views.setOnClickPendingIntent(
            R.id.widget_play_area,
            WidgetIntents.action(context, WidgetActionReceiver.PLAY_PAUSE),
        )
        views.setOnClickPendingIntent(R.id.widget_root, WidgetIntents.openApp(context))
        return views
    }
}
