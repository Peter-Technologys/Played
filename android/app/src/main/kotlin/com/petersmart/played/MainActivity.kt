package com.petersmart.played

import android.app.PictureInPictureParams
import android.content.ContentUris
import android.content.pm.PackageManager
import android.database.Cursor
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Rational
import android.util.Size
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val pipChannel   = "com.petersmart.played/pip"
    private val mediaChannel = "com.petersmart.played/media_store"
    private val fileChannel  = "com.petersmart.played/file_ops"
    private val eqChannel    = "com.petersmart.played/equalizer"

    // Android Equalizer AudioEffect — created once, reused across sessions.
    private var equalizer: android.media.audiofx.Equalizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── PiP ──────────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPip" -> {
                        val w = call.argument<Int>("width") ?: 16
                        val h = call.argument<Int>("height") ?: 9
                        enterPipMode(w, h, result)
                    }
                    "isPipSupported" -> result.success(isPipSupported())
                    else -> result.notImplemented()
                }
            }

        // ── MediaStore ───────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryAudio" -> result.success(queryAudio())
                    "queryVideo" -> result.success(queryVideo())
                    "getVideoThumbnail" -> {
                        val path = call.argument<String>("path") ?: ""
                        val id   = call.argument<String>("id") ?: ""
                        result.success(getVideoThumbnail(path, id))
                    }
                    "getAlbumArt" -> {
                        val albumId = call.argument<String>("albumId") ?: ""
                        result.success(getAlbumArt(albumId))
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Equalizer ─────────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, eqChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBands" -> {
                        @Suppress("UNCHECKED_CAST")
                        val gains = call.argument<List<Double>>("gains") ?: emptyList()
                        applyEqBands(gains)
                        result.success(null)
                    }
                    "release" -> {
                        equalizer?.release()
                        equalizer = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── File operations ──────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deleteFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        result.success(deleteMediaFile(path))
                    }
                    "renameFile" -> {
                        val path    = call.argument<String>("path") ?: ""
                        val newName = call.argument<String>("newName") ?: ""
                        result.success(renameFile(path, newName))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Audio query ──────────────────────────────────────────────────────

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
            MediaStore.Audio.Media.ALBUM_ID,
        )
        val selection = "${MediaStore.Audio.Media.SIZE} >= 10240 AND ${MediaStore.Audio.Media.DURATION} > 0"
        val cursor: Cursor? = contentResolver.query(
            uri, projection, selection, null,
            "${MediaStore.Audio.Media.DATE_ADDED} DESC"
        )
        cursor?.use {
            val idCol      = it.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val nameCol    = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val dataCol    = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val durCol     = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val sizeCol    = it.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val dateCol    = it.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val artistCol  = it.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol   = it.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = it.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
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
                    "albumId"     to it.getLong(albumIdCol).toString(),
                    "isVideo"     to false,
                ))
            }
        }
        return items
    }

    // ── Video query ──────────────────────────────────────────────────────

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
                    "albumId"     to null,
                    "isVideo"     to true,
                ))
            }
        }
        return items
    }

    // ── Video thumbnail ──────────────────────────────────────────────────
    // Returns the path to a cached JPEG thumbnail for the given video.
    // Uses MediaStore.Video.Thumbnails on API < 29, loadThumbnail on API 29+.

    private fun getVideoThumbnail(videoPath: String, videoId: String): String? {
        return try {
            val cacheDir = File(cacheDir, "video_thumbs")
            cacheDir.mkdirs()
            val thumbFile = File(cacheDir, "$videoId.jpg")
            if (thumbFile.exists()) return thumbFile.absolutePath

            val bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val uri = ContentUris.withAppendedId(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    videoId.toLongOrNull() ?: return null
                )
                contentResolver.loadThumbnail(uri, Size(320, 180), null)
            } else {
                @Suppress("DEPRECATION")
                MediaStore.Video.Thumbnails.getThumbnail(
                    contentResolver,
                    videoId.toLongOrNull() ?: return null,
                    MediaStore.Video.Thumbnails.MINI_KIND,
                    null
                )
            }

            bitmap?.let {
                FileOutputStream(thumbFile).use { out ->
                    it.compress(Bitmap.CompressFormat.JPEG, 80, out)
                }
                thumbFile.absolutePath
            }
        } catch (_: Exception) { null }
    }

    // ── Album art ────────────────────────────────────────────────────────
    // Returns the path to a cached JPEG of the album art for the given albumId.

    private fun getAlbumArt(albumId: String): String? {
        return try {
            val cacheDir = File(cacheDir, "album_art")
            cacheDir.mkdirs()
            val artFile = File(cacheDir, "$albumId.jpg")
            if (artFile.exists()) return artFile.absolutePath

            val artUri = Uri.parse("content://media/external/audio/albumart/$albumId")
            val bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    contentResolver.loadThumbnail(artUri, Size(300, 300), null)
                } catch (_: Exception) { null }
            } else {
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(artUri.toString())
                    val art = retriever.embeddedPicture
                    art?.let { android.graphics.BitmapFactory.decodeByteArray(it, 0, it.size) }
                } catch (_: Exception) { null } finally { retriever.release() }
            }

            bitmap?.let {
                FileOutputStream(artFile).use { out ->
                    it.compress(Bitmap.CompressFormat.JPEG, 85, out)
                }
                artFile.absolutePath
            }
        } catch (_: Exception) { null }
    }

    // ── File operations ──────────────────────────────────────────────────

    private fun deleteMediaFile(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false
            // Try MediaStore delete first (required on Android 10+)
            val deleted = contentResolver.delete(
                MediaStore.Files.getContentUri("external"),
                "${MediaStore.Files.FileColumns.DATA} = ?",
                arrayOf(path)
            ) > 0
            if (!deleted) file.delete() else true
        } catch (_: Exception) { false }
    }

    // ── Equalizer ────────────────────────────────────────────────────────────
    // Uses Android's built-in AudioEffect Equalizer (no extra library needed).
    // audioSessionId 0 = global output mix — affects all audio on the device.
    private fun applyEqBands(gains: List<Double>) {
        try {
            if (equalizer == null) {
                equalizer = android.media.audiofx.Equalizer(0, 0).apply {
                    enabled = true
                }
            }
            val eq = equalizer ?: return
            val bandCount = eq.numberOfBands.toInt()
            val range = eq.getBandLevelRange()
            gains.take(bandCount).forEachIndexed { i, gainDb ->
                val millibels = (gainDb * 100).toInt().toShort()
                val clamped = millibels.coerceIn(range[0], range[1])
                eq.setBandLevel(i.toShort(), clamped)
            }
        } catch (e: Exception) {
            android.util.Log.w("Equalizer", "applyEqBands failed: ${e.message}")
        }
    }

    private fun renameFile(path: String, newName: String): String? {
        return try {
            val file = File(path)
            if (!file.exists()) return null
            val newFile = File(file.parent ?: return null, newName)
            if (file.renameTo(newFile)) newFile.absolutePath else null
        } catch (_: Exception) { null }
    }

    // ── PiP helpers ──────────────────────────────────────────────────────

    private fun isPipSupported(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        } else false
    }

    private fun enterPipMode(width: Int, height: Int, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(width, height)).build()
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
                    .setAspectRatio(Rational(16, 9)).build()
                enterPictureInPictureMode(params)
            } catch (_: Exception) {}
        }
    }
}
