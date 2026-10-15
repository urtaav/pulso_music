package com.example.pulso_music

import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.RoundedCorner
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Hereda de AudioServiceActivity para que audio_service comparta el mismo motor
 * de Flutter entre la UI y el servicio de reproducción en segundo plano.
 */
class MainActivity : AudioServiceActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scan" -> background(result) { MediaScanner.scan(applicationContext) }
                "artwork" -> {
                    val id = (call.argument<Number>("id"))?.toLong()
                    val size = call.argument<Int>("size") ?: 512
                    if (id == null) {
                        result.error("bad_args", "Falta el id", null)
                    } else {
                        background(result) { MediaScanner.artwork(applicationContext, id, size) }
                    }
                }
                "screenCornerRadius" -> result.success(screenCornerRadiusDp())
                "consumeLaunchAction" -> {
                    result.success(intent?.getStringExtra(WidgetActionReceiver.EXTRA_ACTION))
                    intent?.removeExtra(WidgetActionReceiver.EXTRA_ACTION)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, VISUALIZER_CHANNEL).setStreamHandler(VisualizerStreamHandler())
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    // El escaneo y la lectura de carátulas tocan disco: nunca en el hilo principal.
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("native_error", e.message, null) }
            }
        }
    }

    /** Radio real de las esquinas de la pantalla, para que el visualizador las siga. */
    private fun screenCornerRadiusDp(): Double {
        val density = resources.displayMetrics.density
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val corner = window.decorView.rootWindowInsets
                ?.getRoundedCorner(RoundedCorner.POSITION_TOP_LEFT)
            if (corner != null) return corner.radius / density.toDouble()
        }
        return 0.0
    }

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }

    companion object {
        const val MEDIA_CHANNEL = "pulso/media"
        const val VISUALIZER_CHANNEL = "pulso/visualizer"
    }
}
