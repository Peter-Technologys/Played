package com.petersmart.played

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val pipChannel = "com.petersmart.played/pip"
    private val mediaChannel = "com.petersmart.played/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // PiP channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pipChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    val width = call.argument<Int>("width") ?: 16
                    val height = call.argument<Int>("height") ?: 9
                    enterPipMode(width, height, result)
                }
                "isPipSupported" -> result.success(isPipSupported())
                else -> result.notImplemented()
            }
        }

        // MediaStore channel
        // Queries Android's media database directly. Works on ALL Android
        // versions with READ_MEDIA_AUDIO/VIDEO (API 33+) or
        // READ_EXTERNAL_STORAGE (API <= 32). No filesystem walk needed.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            mediaChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryAudio" -> result.success(queryAudio())
                "queryVideo" -> result.success(queryVideo())
                else -> result.notImplemented()
            }
        }
    }

    private fun queryAudio(): List<Map<String, Any?>> {
        val items = mutableListOf<Map<String, Any?>>()
        val uri: Uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
        )
        val selection = "${MediaStore.Audio.Media.SIZE} >= 10240 AND ${MediaStore.Audio.Media.DURATION} > 0"
        val cursor: Cursor? = contentResolver.query(
            uri, projection, selection, null,
            "${MediaStore.Audio.Media.DATE_ADDED} DESC"
        )
        cursor?.use {
            val idCol     = it.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val nameCol   = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val dataCol   = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val durCol    = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val sizeCol   = it.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val dateCol   = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val artistCol = it.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol  = it.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            while (it.moveToNext()) {
                val path = it.getString(dataCol) ?: continue
                items.add(mapOf(
                    "id"          to it.getLong(idCol).toString(),
                    "displayName" to (it.getString(nameCol) ?: ""),
                    "path"        to path,
                    "durationMs"  to it.getLong(durCol),
                    "size"        to it.getLong(sizeCol),
                    "dateAdded"   to it.getLong(dateCol),
                    "artist"      to it.getString(artistCol),
                    "album"       to it.getString(albumCol),
                    "isVideo"     to false,
                ))
            }
        }
        return items
    }

    private fun queryVideo(): List<Map<String, Any?>> {
        val items = mutableListOf<Map<String, Any?>>()
        val uri: Uri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
        )
        val selection = "${MediaStore.Video.Media.SIZE} >= 10240 AND ${MediaStore.Video.Media.DURATION} > 0"
        val cursor: Cursor? = contentResolver.query(
            uri, projection, selection, null,
            "${MediaStore.Video.Media.DATE_ADDED} DESC"
        )
        cursor?.use {
            val idCol   = it.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val nameCol = it.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val dataCol = it.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
            val durCol  = it.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val sizeCol = it.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val dateCol = it.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
            while (it.moveToNext()) {
                val path = it.getString(dataCol) ?: continue
                items.add(mapOf(
                    "id"          to it.getLong(idCol).toString(),
                    "displayName" to (it.getString(nameCol) ?: ""),
                    "path"        to path,
                    "durationMs"  to it.getLong(durCol),
                    "size"        to it.getLong(sizeCol),
                    "dateAdded"   to it.getLong(dateCol),
                    "artist"      to null,
                    "album"       to null,
                    "isVideo"     to true,
                ))
            }
        }
        return items
    }

    private fun isPipSupported(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        } else {
            false
        }
    }

    private fun enterPipMode(width: Int, height: Int, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(width, height))
                    .build()
                enterPictureInPictureMode(params)
                result.success(true)
            } catch (e: Exception) {
                result.error("PIP_ERROR", e.message, null)
            }
        } else {
            result.error("PIP_UNSUPPORTED", "PiP requires Android 8.0+", null)
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isPipSupported()) {
            try {
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .build()
                enterPictureInPictureMode(params)
            } catch (_: Exception) {}
        }
    }
}
