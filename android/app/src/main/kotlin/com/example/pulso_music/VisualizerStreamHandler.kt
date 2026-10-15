package com.example.pulso_music

import android.media.audiofx.Visualizer
import io.flutter.plugin.common.EventChannel
import kotlin.math.hypot
import kotlin.math.log10
import kotlin.math.pow

/**
 * Visualizador de audio real.
 *
 * Se engancha a la sesión de audio de ExoPlayer (el id llega desde Dart) y manda
 * a Flutter [BANDS] valores 0..1 calculados de la FFT. Requiere RECORD_AUDIO:
 * Android lo exige porque Visualizer puede leer la salida de audio.
 *
 * Las bandas van en escala logarítmica: así los graves, que es donde está el
 * "latido" de la música, ocupan más barras que los agudos.
 */
class VisualizerStreamHandler : EventChannel.StreamHandler {
    private var visualizer: Visualizer? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        release()
        val sessionId = (arguments as? Number)?.toInt()
        if (sessionId == null || sessionId <= 0) {
            events.error("no_session", "Sesión de audio inválida", null)
            return
        }
        try {
            // Se crea en el hilo principal, así los callbacks también llegan ahí
            // y EventSink se puede usar directamente.
            visualizer = Visualizer(sessionId).apply {
                captureSize = Visualizer.getCaptureSizeRange()[1].coerceAtMost(1024)
                setDataCaptureListener(
                    object : Visualizer.OnDataCaptureListener {
                        override fun onWaveFormDataCapture(v: Visualizer, data: ByteArray, rate: Int) = Unit

                        override fun onFftDataCapture(v: Visualizer, fft: ByteArray, rate: Int) {
                            events.success(toBands(fft))
                        }
                    },
                    Visualizer.getMaxCaptureRate(),
                    false,
                    true,
                )
                enabled = true
            }
        } catch (e: Exception) {
            // Sin permiso o sesión ocupada: Dart cae a la animación simulada.
            events.error("visualizer_unavailable", e.message, null)
            release()
        }
    }

    override fun onCancel(arguments: Any?) = release()

    private fun release() {
        visualizer?.run {
            enabled = false
            release()
        }
        visualizer = null
    }

    private fun toBands(fft: ByteArray): List<Double> {
        // Formato de Visualizer: [0]=DC, [1]=Nyquist, luego pares (real, imaginario).
        val bins = fft.size / 2
        val result = ArrayList<Double>(BANDS)
        for (band in 0 until BANDS) {
            val start = binAt(band, bins)
            val end = binAt(band + 1, bins).coerceAtLeast(start + 1)
            var peak = 0.0
            for (k in start until end.coerceAtMost(bins)) {
                val re = fft[2 * k].toDouble()
                val im = fft[2 * k + 1].toDouble()
                peak = maxOf(peak, hypot(re, im))
            }
            // A decibeles y a 0..1; 40 dB cubre bien el rango útil de un byte.
            val db = 20 * log10(peak + 1)
            result += (db / 40.0).coerceIn(0.0, 1.0)
        }
        return result
    }

    private fun binAt(band: Int, bins: Int): Int {
        val fraction = band.toDouble() / BANDS
        return (1 + (bins - 1) * fraction.pow(2.2)).toInt()
    }

    companion object {
        const val BANDS = 48
    }
}
