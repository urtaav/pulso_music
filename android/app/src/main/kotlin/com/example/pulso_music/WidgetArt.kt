package com.example.pulso_music

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface

/** Imágenes que los widgets no pueden dibujar por sí mismos. */
object WidgetArt {

    // RemoteViews tiene un límite de memoria por widget: carátulas chicas.
    fun cover(context: Context, state: WidgetState, size: Int = 360): Bitmap? =
        state.songId?.let { MediaScanner.loadBitmap(context, it, size) }

    /**
     * Gráfica de "Tu semana": barras por día con el récord en el color de
     * acento, y abajo los días como círculos (relleno si escuchaste ese día).
     */
    fun weekChart(state: WidgetState, width: Int = 720, height: Int = 300): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val minutes = state.weekMinutes
        val max = (minutes.maxOrNull() ?: 0).coerceAtLeast(1)
        val slot = width / 7f
        val circle = slot * 0.36f
        val chartBottom = height - circle * 2 - 16f
        val barWidth = slot * 0.38f
        val fg = state.foreground

        val bar = Paint(Paint.ANTI_ALIAS_FLAG)
        val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = state.accent
            alpha = 120
            maskFilter = BlurMaskFilter(18f, BlurMaskFilter.Blur.NORMAL)
        }
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = circle * 0.9f
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        val dot = Paint(Paint.ANTI_ALIAS_FLAG)

        for (i in 0 until 7) {
            val cx = slot * i + slot / 2
            val fraction = minutes[i].toFloat() / max
            val top = chartBottom - (chartBottom - 8f) * fraction.coerceAtLeast(0.03f)
            val rect = RectF(cx - barWidth / 2, top, cx + barWidth / 2, chartBottom)
            when (i) {
                state.weekBest -> {
                    canvas.drawRoundRect(rect, barWidth / 2, barWidth / 2, glow)
                    bar.color = state.accent
                }
                state.weekToday -> bar.color = withAlpha(fg, 200)
                else -> bar.color = withAlpha(fg, 50)
            }
            canvas.drawRoundRect(rect, barWidth / 2, barWidth / 2, bar)

            // Día: círculo relleno si hubo música; hoy, sólido.
            val cy = height - circle - 4f
            dot.color = when {
                i == state.weekToday -> fg
                minutes[i] > 0 -> withAlpha(fg, 60)
                else -> withAlpha(fg, 18)
            }
            canvas.drawCircle(cx, cy, circle, dot)
            label.color = if (i == state.weekToday) {
                if (WidgetState.isDark(fg)) Color.WHITE else Color.BLACK
            } else {
                withAlpha(fg, 200)
            }
            canvas.drawText(DAYS[i], cx, cy - (label.descent() + label.ascent()) / 2, label)
        }
        return bitmap
    }

    private fun withAlpha(color: Int, alpha: Int) = (color and 0x00FFFFFF) or (alpha shl 24)

    private val DAYS = listOf("L", "M", "M", "J", "V", "S", "D")
}
