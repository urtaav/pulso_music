package com.example.pulso_music

import android.content.SharedPreferences
import android.graphics.Color
import android.os.SystemClock

/**
 * Lo que Flutter guardó para los widgets (HomeWidgetSync.dart), ya parseado.
 * Todo viaja como texto para evitar problemas Int/Long con los colores ARGB.
 */
data class WidgetState(
    val title: String,
    val artist: String,
    val playing: Boolean,
    val favorite: Boolean,
    val songId: Long?,
    val positionMs: Long,
    val durationMs: Long,
    val savedAt: Long,
    val background: Int,
    val accent: Int,
    val alpha: Int,
    val weekMinutes: List<Int>,
    val weekToday: Int,
    val weekBest: Int,
    val weekFavorite: String,
) {
    val foreground = if (isDark(background)) Color.WHITE else Color.BLACK
    val secondary = (foreground and 0x00FFFFFF) or (0x99 shl 24)
    val onAccent = if (isDark(accent)) Color.WHITE else Color.BLACK

    /** Posición estimada ahora, contando lo que avanzó desde que se guardó. */
    fun currentPositionMs(): Long {
        val elapsed = if (playing) System.currentTimeMillis() - savedAt else 0L
        val position = positionMs + elapsed.coerceAtLeast(0)
        return if (durationMs > 0) position.coerceAtMost(durationMs) else position
    }

    /** Base para un Chronometer que muestra la posición y avanza solo. */
    fun chronometerBase(): Long = SystemClock.elapsedRealtime() - currentPositionMs()

    fun progressPermille(): Int =
        if (durationMs <= 0) 0 else (currentPositionMs() * 1000 / durationMs).toInt()

    companion object {
        // Luminancia percibida simple; suficiente para elegir texto blanco o negro.
        fun isDark(color: Int): Boolean {
            val luma = 0.299 * Color.red(color) + 0.587 * Color.green(color) +
                0.114 * Color.blue(color)
            return luma < 150
        }

        fun formatTime(ms: Long): String {
            val total = ms / 1000
            return "%d:%02d".format(total / 60, total % 60)
        }

        fun formatMinutes(minutes: Int): String = when {
            minutes < 60 -> "$minutes min"
            minutes % 60 == 0 -> "${minutes / 60} h"
            else -> "${minutes / 60} h ${"%02d".format(minutes % 60)} min"
        }

        fun from(prefs: SharedPreferences): WidgetState {
            fun text(key: String) = prefs.getString(key, null)
            return WidgetState(
                title = text("title") ?: "pulso",
                artist = text("artist") ?: "Toca para empezar",
                playing = text("playing") == "true",
                favorite = text("favorite") == "true",
                songId = text("songId")?.toLongOrNull(),
                positionMs = text("positionMs")?.toLongOrNull() ?: 0,
                durationMs = text("durationMs")?.toLongOrNull() ?: 0,
                savedAt = text("savedAt")?.toLongOrNull() ?: System.currentTimeMillis(),
                background = text("background")?.toLongOrNull()?.toInt() ?: 0xFF1C1C1E.toInt(),
                accent = text("accent")?.toLongOrNull()?.toInt() ?: 0xFFF2F25A.toInt(),
                alpha = text("alpha")?.toIntOrNull()?.coerceIn(0, 255) ?: 255,
                weekMinutes = text("weekMinutes")
                    ?.split(',')
                    ?.mapNotNull { it.toIntOrNull() }
                    ?.takeIf { it.size == 7 }
                    ?: List(7) { 0 },
                weekToday = text("weekToday")?.toIntOrNull() ?: -1,
                weekBest = text("weekBest")?.toIntOrNull() ?: -1,
                weekFavorite = text("weekFavorite") ?: "",
            )
        }
    }
}
