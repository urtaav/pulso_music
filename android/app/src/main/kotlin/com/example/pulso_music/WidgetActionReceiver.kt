package com.example.pulso_music

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Recibe los toques de los botones del widget.
 *
 * Si la app sigue viva (audio_service mantiene su motor de Flutter en caché),
 * la acción va directo a Dart. Si Android ya cerró el proceso, se abre la app con
 * la acción pendiente; arrancar el servicio sin motor provocaría un cierre.
 */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra(EXTRA_ACTION) ?: return
        val engine = FlutterEngineCache.getInstance().get(AudioServicePlugin.getFlutterEngineId())
        if (engine != null && engine.dartExecutor.isExecutingDart) {
            MethodChannel(engine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
                .invokeMethod("action", action)
            return
        }
        context.startActivity(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(EXTRA_ACTION, action),
        )
    }

    companion object {
        const val WIDGET_CHANNEL = "pulso/widget"
        const val EXTRA_ACTION = "pulso_widget_action"
        const val PLAY_PAUSE = "playPause"
        const val NEXT = "next"
        const val PREVIOUS = "previous"
        const val FAVORITE = "favorite"
    }
}
