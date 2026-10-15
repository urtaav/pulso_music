package com.example.pulso_music

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget de pantalla de inicio con tres diseños que cambian al redimensionarlo:
 * pequeño (portada + play), mediano (portada, título y controles) y grande
 * (portada grande arriba). Flutter guarda los datos con home_widget como texto
 * para evitar problemas Int/Long con los colores ARGB.
 */
class PlayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val state = WidgetState.from(widgetData)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, appWidgetManager, id, state))
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
            buildViews(context, appWidgetManager, appWidgetId, state),
        )
    }

    private fun buildViews(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        state: WidgetState,
    ): RemoteViews {
        val art = state.songId?.let { MediaScanner.loadBitmap(context, it, 320) }
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
        art: android.graphics.Bitmap?,
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
                action(context, WidgetActionReceiver.PREVIOUS, 1),
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                action(context, WidgetActionReceiver.NEXT, 2),
            )
        }

        views.setImageViewResource(
            R.id.widget_play,
            if (state.playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
        )
        views.setInt(R.id.widget_play_bg, "setColorFilter", state.accent)
        views.setInt(R.id.widget_play, "setColorFilter", state.onAccent)
        views.setOnClickPendingIntent(
            R.id.widget_play_area,
            action(context, WidgetActionReceiver.PLAY_PAUSE, 0),
        )
        views.setOnClickPendingIntent(R.id.widget_root, openApp(context))
        return views
    }

    private fun action(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java)
            .setAction("com.example.pulso_music.widget.$action")
            .putExtra(WidgetActionReceiver.EXTRA_ACTION, action)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            10,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

private data class WidgetState(
    val title: String,
    val artist: String,
    val playing: Boolean,
    val songId: Long?,
    val background: Int,
    val accent: Int,
    val alpha: Int,
) {
    // El texto se adapta al fondo para que siempre se lea.
    val foreground = if (isDark(background)) Color.WHITE else Color.BLACK
    val secondary = (foreground and 0x00FFFFFF) or (0x99 shl 24)
    val onAccent = if (isDark(accent)) Color.WHITE else Color.BLACK

    companion object {
        // Luminancia percibida simple; suficiente para elegir texto blanco o negro.
        private fun isDark(color: Int): Boolean {
            val luma = 0.299 * Color.red(color) + 0.587 * Color.green(color) +
                0.114 * Color.blue(color)
            return luma < 150
        }

        fun from(prefs: SharedPreferences) = WidgetState(
            title = prefs.getString("title", null) ?: "pulso",
            artist = prefs.getString("artist", null) ?: "toca para empezar",
            playing = prefs.getString("playing", null) == "true",
            songId = prefs.getString("songId", null)?.toLongOrNull(),
            background = prefs.getString("background", null)?.toLongOrNull()?.toInt()
                ?: 0xFF1C1C1C.toInt(),
            accent = prefs.getString("accent", null)?.toLongOrNull()?.toInt()
                ?: 0xFFF2F25A.toInt(),
            alpha = prefs.getString("alpha", null)?.toIntOrNull()?.coerceIn(0, 255) ?: 255,
        )
    }
}
