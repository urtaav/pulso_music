package com.example.pulso_music

import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/** PendingIntents compartidos por todos los widgets. */
object WidgetIntents {

    fun action(context: Context, action: String): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java)
            .setAction("com.example.pulso_music.widget.$action")
            .putExtra(WidgetActionReceiver.EXTRA_ACTION, action)
        return PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun openApp(context: Context): PendingIntent {
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
