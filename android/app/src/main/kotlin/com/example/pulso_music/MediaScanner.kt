package com.example.pulso_music

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Lee la música del teléfono desde MediaStore.
 *
 * Aquí no se filtra por carpeta ni por duración: se devuelve todo con banderas
 * (tono del sistema, grabación) y Dart decide qué excluir según los ajustes del
 * usuario. Así cambiar un ajuste no requiere volver a consultar Android.
 */
object MediaScanner {

    fun scan(context: Context): List<Map<String, Any?>> {
        val columns = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.IS_RINGTONE,
            MediaStore.Audio.Media.IS_NOTIFICATION,
            MediaStore.Audio.Media.IS_ALARM,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            columns += MediaStore.Audio.Media.RELATIVE_PATH
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            columns += MediaStore.Audio.Media.IS_RECORDING
        }

        val songs = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            columns.toTypedArray(),
            null,
            null,
            null,
        )?.use { cursor ->
            fun index(name: String) = cursor.getColumnIndex(name)
            fun string(name: String): String? =
                index(name).takeIf { it >= 0 }?.let { cursor.getString(it) }
            fun long(name: String): Long =
                index(name).takeIf { it >= 0 }?.let { cursor.getLong(it) } ?: 0L
            fun flag(name: String): Boolean = long(name) != 0L

            while (cursor.moveToNext()) {
                val path = string(MediaStore.Audio.Media.DATA)
                // DATA puede venir vacío en algunos Android; RELATIVE_PATH es el respaldo.
                val folder = path?.let { File(it).parent }
                    ?: string(MediaStore.Audio.Media.RELATIVE_PATH)?.trimEnd('/')
                    ?: ""
                songs += mapOf(
                    "id" to long(MediaStore.Audio.Media._ID),
                    "title" to string(MediaStore.Audio.Media.TITLE),
                    "artist" to string(MediaStore.Audio.Media.ARTIST)
                        ?.takeUnless { it == MediaStore.UNKNOWN_STRING },
                    "album" to string(MediaStore.Audio.Media.ALBUM),
                    "albumId" to long(MediaStore.Audio.Media.ALBUM_ID),
                    "durationMs" to long(MediaStore.Audio.Media.DURATION),
                    "path" to (path ?: ""),
                    "folder" to folder,
                    "dateAdded" to long(MediaStore.Audio.Media.DATE_ADDED),
                    "track" to long(MediaStore.Audio.Media.TRACK),
                    "isSystemSound" to (flag(MediaStore.Audio.Media.IS_RINGTONE) ||
                        flag(MediaStore.Audio.Media.IS_NOTIFICATION) ||
                        flag(MediaStore.Audio.Media.IS_ALARM)),
                    "isRecording" to flag("is_recording"),
                )
            }
        }
        return songs
    }

    /** Carátula como JPEG, o null si la canción no tiene. */
    fun artwork(context: Context, id: Long, size: Int): ByteArray? {
        val bitmap = loadBitmap(context, id, size) ?: return null
        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
            out.toByteArray()
        }
    }

    fun loadBitmap(context: Context, id: Long, size: Int): Bitmap? {
        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return try {
                context.contentResolver.loadThumbnail(uri, Size(size, size), null)
            } catch (_: Exception) {
                null // Sin carátula embebida ni de álbum.
            }
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            val bytes = retriever.embeddedPicture ?: return null
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
            var sample = 1
            while (options.outWidth / (sample * 2) >= size) sample *= 2
            BitmapFactory.decodeByteArray(
                bytes, 0, bytes.size,
                BitmapFactory.Options().apply { inSampleSize = sample },
            )
        } catch (_: Exception) {
            null
        } finally {
            retriever.release()
        }
    }
}
