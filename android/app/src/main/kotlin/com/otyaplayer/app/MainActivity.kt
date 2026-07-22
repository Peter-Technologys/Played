package com.otyaplayer.app

import android.app.PictureInPictureParams
import android.content.ContentUris
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.database.Cursor
import android.graphics.Bitmap
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.util.Rational
import android.util.Size
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {

    private val pipChannel      = "com.otyaplayer.app/pip"
    private val mediaChannel    = "com.otyaplayer.app/media_store"
    private val fileChannel     = "com.otyaplayer.app/file_ops"
    private val eqChannel       = "com.otyaplayer.app/equalizer"
    private val phoneChannel    = "com.otyaplayer.app/phone_state"
    private val ffmpegChannel   = "com.otyaplayer.app/ffmpeg"
    private val mediaEventCh    = "com.otyaplayer.app/media_events"
    private val deviceIdChannel = "com.otyaplayer.app/device_id"

    // Fix #10: coroutine scope for long-running FFmpeg operations.
    // Cancelled in onDestroy() to avoid leaking threads on low-RAM devices.
    private val ioScope = CoroutineScope(Dispatchers.IO + Job())

    // Tracks whether the video player is actively playing — used by
    // onUserLeaveHint() to decide whether to auto-enter PiP.
    // Set via MethodChannel from Flutter when playback state changes.
    @Volatile private var isVideoPlaying: Boolean = false

    private var equalizer: android.media.audiofx.Equalizer? = null

    @Suppress("DEPRECATION")
    private var phoneStateListener: android.telephony.PhoneStateListener? = null
    private var telephonyManager: android.telephony.TelephonyManager? = null

    // MediaStore observer — fires whenever any media file is added/removed
    private var mediaObserver: ContentObserver? = null
    private var mediaEventSink: EventChannel.EventSink? = null

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
                    // Flutter calls this whenever video playback starts or stops
                    // so onUserLeaveHint() knows whether to auto-enter PiP.
                    "setVideoPlaying" -> {
                        isVideoPlaying = call.argument<Boolean>("playing") ?: false
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── MediaStore ───────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryAudio"       -> result.success(queryAudio())
                    "queryVideo"       -> result.success(queryVideo())
                    "getVideoThumbnail" -> {
                        val path = call.argument<String>("path") ?: ""
                        val id   = call.argument<String>("id") ?: ""
                        result.success(getVideoThumbnail(path, id))
                    }
                    "getAlbumArt" -> {
                        val albumId = call.argument<String>("albumId") ?: ""
                        result.success(getAlbumArt(albumId))
                    }
                    "triggerScan" -> {
                        // Force MediaStore to re-index a specific path
                        val path = call.argument<String>("path") ?: ""
                        triggerMediaScan(path)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Media change events (live scan) ──────────────────────────────
        // Dart side listens to this stream; whenever MediaStore changes
        // (file added via USB, file manager, SD card, AirDrop, etc.)
        // Flutter gets notified and re-scans automatically.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, mediaEventCh)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    mediaEventSink = sink
                    registerMediaObserver()
                }
                override fun onCancel(args: Any?) {
                    unregisterMediaObserver()
                    mediaEventSink = null
                }
            })

        // ── Phone state (Pause During Calls) ─────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, phoneChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPauseDuringCalls" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        if (enabled) registerPhoneListener() else unregisterPhoneListener()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        registerPhoneListener()

        // ── Equalizer ────────────────────────────────────────────────────
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

        // ── File operations ──────────────────────────────────────────────
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

        // ── FFmpeg (offline trim + extract) ──────────────────────────────
        // Uses Android's built-in MediaExtractor + MediaMuxer — no FFmpeg
        // binary needed, works 100% offline on all Android versions.
        // Fix #10: replaced raw Thread with a coroutine on Dispatchers.IO.
        // The ioScope is cancelled in onDestroy() so operations are properly
        // cleaned up and do not leak threads on low-RAM devices.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ffmpegChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "trimVideo" -> {
                        val path    = call.argument<String>("path") ?: ""
                        val startMs = call.argument<Int>("startMs") ?: 0
                        val endMs   = call.argument<Int>("endMs") ?: 30000
                        ioScope.launch {
                            val out = trimVideo(path, startMs.toLong(), endMs.toLong())
                            runOnUiThread {
                                if (out != null) result.success(out)
                                else result.error("TRIM_FAILED", "Trim failed", null)
                            }
                        }
                    }
                    "extractAudio" -> {
                        val path = call.argument<String>("path") ?: ""
                        ioScope.launch {
                            val out = extractAudio(path)
                            runOnUiThread {
                                if (out != null) result.success(out)
                                else result.error("EXTRACT_FAILED", "Extract failed", null)
                            }
                        }
                    }
                    "cancel" -> result.success(null)
                    else     -> result.notImplemented()
                }
            }

        // ── Device ID (ANDROID_ID for vault key fallback) ─────────────────
        // Fix #12: exposes Settings.Secure.ANDROID_ID to Dart so the vault
        // key derivation can use a stable, device-unique value when
        // FlutterSecureStorage is unavailable (no secure enclave, policy, etc.)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceIdChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidId" -> {
                        val androidId = Settings.Secure.getString(
                            contentResolver, Settings.Secure.ANDROID_ID)
                        result.success(androidId)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Brightness ────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.otyaplayer.app/brightness")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBrightness" -> {
                        val value = call.argument<Double>("value")?.toFloat() ?: 0.5f
                        val lp = window.attributes
                        lp.screenBrightness = value.coerceIn(0.01f, 1.0f)
                        window.attributes = lp
                        result.success(null)
                    }
                    "getBrightness" -> {
                        val lp = window.attributes
                        val b = if (lp.screenBrightness < 0) 0.5f else lp.screenBrightness
                        result.success(b.toDouble())
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Volume ────────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.otyaplayer.app/volume")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVolume" -> {
                        val value = call.argument<Double>("value") ?: 0.5
                        val am = getSystemService(AUDIO_SERVICE) as android.media.AudioManager
                        val maxVol = am.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                        am.setStreamVolume(android.media.AudioManager.STREAM_MUSIC,
                            (value * maxVol).toInt().coerceIn(0, maxVol), 0)
                        result.success(null)
                    }
                    "getVolume" -> {
                        val am = getSystemService(AUDIO_SERVICE) as android.media.AudioManager
                        val maxVol = am.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                        val curVol = am.getStreamVolume(android.media.AudioManager.STREAM_MUSIC)
                        result.success(curVol.toDouble() / maxVol.toDouble())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── MediaStore observer ───────────────────────────────────────────────
    // Watches both audio and video URIs. When any file is added, removed,
    // or modified (USB copy, file manager, SD card, AirDrop receive, etc.)
    // the Dart side is notified and triggers a background re-scan.

    private fun registerMediaObserver() {
        val handler = Handler(Looper.getMainLooper())
        val observer = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean) {
                mediaEventSink?.success("changed")
            }
        }
        contentResolver.registerContentObserver(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, true, observer)
        contentResolver.registerContentObserver(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI, true, observer)
        // Also watch the Files URI to catch files not yet categorised
        contentResolver.registerContentObserver(
            MediaStore.Files.getContentUri("external"), true, observer)
        mediaObserver = observer
        Log.d("MediaObserver", "Registered")
    }

    private fun unregisterMediaObserver() {
        mediaObserver?.let { contentResolver.unregisterContentObserver(it) }
        mediaObserver = null
    }

    // Force MediaStore to index a newly added file immediately
    private fun triggerMediaScan(path: String) {
        try {
            val values = android.content.ContentValues().apply {
                put(MediaStore.Files.FileColumns.DATA, path)
            }
            contentResolver.insert(MediaStore.Files.getContentUri("external"), values)
        } catch (_: Exception) {}
        // Also use the broadcast approach for older Android
        try {
            sendBroadcast(android.content.Intent(
                android.content.Intent.ACTION_MEDIA_SCANNER_SCAN_FILE,
                Uri.fromFile(File(path))
            ))
        } catch (_: Exception) {}
    }

    // ── FFmpeg: Trim video (offline, uses MediaExtractor + MediaMuxer) ────

    private fun trimVideo(inputPath: String, startMs: Long, endMs: Long): String? {
        return try {
            val outDir = File(getExternalFilesDir(null), "Trimmed")
            outDir.mkdirs()
            val outFile = File(outDir, "trimmed_${System.currentTimeMillis()}.mp4")

            val extractor = MediaExtractor()
            extractor.setDataSource(inputPath)

            val muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val trackMap = mutableMapOf<Int, Int>() // extractor track → muxer track
            for (i in 0 until extractor.trackCount) {
                val fmt  = extractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/") || mime.startsWith("video/")) {
                    trackMap[i] = muxer.addTrack(fmt)
                }
            }

            muxer.start()

            val buf  = ByteBuffer.allocate(1024 * 1024)
            val info = android.media.MediaCodec.BufferInfo()

            // Fix: seek each track independently from a clean state.
            // Previously the extractor's position was shared across tracks,
            // causing audio/video desync in multi-track files.
            for ((extTrack, muxTrack) in trackMap) {
                // Unselect all tracks first so seekTo operates on a clean state
                for (i in 0 until extractor.trackCount) {
                    try { extractor.unselectTrack(i) } catch (_: Exception) {}
                }
                extractor.selectTrack(extTrack)
                // Seek to the trim start for THIS track independently
                extractor.seekTo(startMs * 1000L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

                while (true) {
                    val size = extractor.readSampleData(buf, 0)
                    if (size < 0) break
                    val pts = extractor.sampleTime
                    if (pts > endMs * 1000L) break

                    info.offset             = 0
                    info.size               = size
                    info.presentationTimeUs = pts - (startMs * 1000L)
                    info.flags              = extractor.sampleFlags
                    muxer.writeSampleData(muxTrack, buf, info)
                    extractor.advance()
                }
            }

            muxer.stop()
            muxer.release()
            extractor.release()

            // Notify MediaStore so the file appears in Downloads
            triggerMediaScan(outFile.absolutePath)
            outFile.absolutePath
        } catch (e: Exception) {
            Log.e("FFmpeg", "trimVideo failed: ${e.message}")
            null
        }
    }

    // ── FFmpeg: Extract audio (offline, uses MediaExtractor + MediaMuxer) ─

    private fun extractAudio(inputPath: String): String? {
        return try {
            val outDir = File(getExternalFilesDir(null), "Extracted")
            outDir.mkdirs()
            val outFile = File(outDir, "audio_${System.currentTimeMillis()}.m4a")

            val extractor = MediaExtractor()
            extractor.setDataSource(inputPath)

            var audioTrack = -1
            var audioFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val fmt  = extractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrack  = i
                    audioFormat = fmt
                    break
                }
            }
            if (audioTrack < 0 || audioFormat == null) return null

            extractor.selectTrack(audioTrack)

            val muxer    = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val muxTrack = muxer.addTrack(audioFormat)
            muxer.start()

            val buf  = ByteBuffer.allocate(512 * 1024)
            val info = android.media.MediaCodec.BufferInfo()

            while (true) {
                val size = extractor.readSampleData(buf, 0)
                if (size < 0) break
                info.offset             = 0
                info.size               = size
                info.presentationTimeUs = extractor.sampleTime
                info.flags              = extractor.sampleFlags
                muxer.writeSampleData(muxTrack, buf, info)
                extractor.advance()
            }

            muxer.stop()
            muxer.release()
            extractor.release()

            triggerMediaScan(outFile.absolutePath)
            outFile.absolutePath
        } catch (e: Exception) {
            Log.e("FFmpeg", "extractAudio failed: ${e.message}")
            null
        }
    }

    // ── Audio query ──────────────────────────────────────────────────────

    private fun queryAudio(): List<Map<String, Any?>> {
        val items = mutableListOf<Map<String, Any?>>()
        val uri   = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
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
        contentResolver.query(uri, projection, selection, null,
            "${MediaStore.Audio.Media.DATE_ADDED} DESC")?.use {
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
        val uri   = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
        )
        val selection = "${MediaStore.Video.Media.SIZE} >= 10240 AND ${MediaStore.Video.Media.DURATION} > 0"
        contentResolver.query(uri, projection, selection, null,
            "${MediaStore.Video.Media.DATE_ADDED} DESC")?.use {
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

    private fun getVideoThumbnail(videoPath: String, videoId: String): String? {
        return try {
            val thumbDir  = File(cacheDir, "video_thumbs").also { it.mkdirs() }
            val thumbFile = File(thumbDir, "$videoId.jpg")
            if (thumbFile.exists()) return thumbFile.absolutePath
            val bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val uri = ContentUris.withAppendedId(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    videoId.toLongOrNull() ?: return null)
                contentResolver.loadThumbnail(uri, Size(320, 180), null)
            } else {
                @Suppress("DEPRECATION")
                MediaStore.Video.Thumbnails.getThumbnail(
                    contentResolver, videoId.toLongOrNull() ?: return null,
                    MediaStore.Video.Thumbnails.MINI_KIND, null)
            }
            bitmap?.let {
                FileOutputStream(thumbFile).use { out -> it.compress(Bitmap.CompressFormat.JPEG, 80, out) }
                thumbFile.absolutePath
            }
        } catch (_: Exception) { null }
    }

    // ── Album art ────────────────────────────────────────────────────────

    private fun getAlbumArt(albumId: String): String? {
        return try {
            val artDir  = File(cacheDir, "album_art").also { it.mkdirs() }
            val artFile = File(artDir, "$albumId.jpg")
            if (artFile.exists()) return artFile.absolutePath
            val artUri  = Uri.parse("content://media/external/audio/albumart/$albumId")
            val bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try { contentResolver.loadThumbnail(artUri, Size(300, 300), null) }
                catch (_: Exception) { null }
            } else {
                // Fix: use setDataSource(context, uri) overload — passing uri.toString()
                // to the single-arg overload does not work for content:// URIs on
                // Android 9 and below, causing silent null returns.
                val r = MediaMetadataRetriever()
                try {
                    r.setDataSource(this, artUri)
                    r.embeddedPicture?.let { android.graphics.BitmapFactory.decodeByteArray(it, 0, it.size) }
                } catch (_: Exception) { null } finally { r.release() }
            }
            bitmap?.let {
                FileOutputStream(artFile).use { out -> it.compress(Bitmap.CompressFormat.JPEG, 85, out) }
                artFile.absolutePath
            }
        } catch (_: Exception) { null }
    }

    // ── File operations ──────────────────────────────────────────────────

    private fun deleteMediaFile(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false
            val deleted = contentResolver.delete(
                MediaStore.Files.getContentUri("external"),
                "${MediaStore.Files.FileColumns.DATA} = ?", arrayOf(path)) > 0
            if (!deleted) file.delete() else true
        } catch (_: Exception) { false }
    }

    private fun renameFile(path: String, newName: String): String? {
        return try {
            val file    = File(path)
            if (!file.exists()) return null
            val newFile = File(file.parent ?: return null, newName)
            if (file.renameTo(newFile)) {
                triggerMediaScan(newFile.absolutePath)
                newFile.absolutePath
            } else null
        } catch (_: Exception) { null }
    }

    // ── Phone state ──────────────────────────────────────────────────────

    // Modern TelephonyCallback (Android 12+ / API 31+) — avoids deprecation warning.
    private var telephonyCallback: Any? = null // typed as Any to avoid API-level import issues

    @Suppress("DEPRECATION")
    private fun registerPhoneListener() {
        telephonyManager = getSystemService(TELEPHONY_SERVICE) as? android.telephony.TelephonyManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // API 31+ path — TelephonyCallback
            val cb = object : android.telephony.TelephonyCallback(),
                android.telephony.TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) {
                    handleCallState(state)
                }
            }
            telephonyCallback = cb
            try {
                telephonyManager!!.registerTelephonyCallback(
                    mainExecutor, cb)
            } catch (e: Exception) { Log.w("PhoneState", "TelephonyCallback register failed: ${e.message}") }
        } else {
            // Legacy path — PhoneStateListener (deprecated in API 31)
            if (phoneStateListener != null) return
            phoneStateListener = object : android.telephony.PhoneStateListener() {
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    handleCallState(state)
                }
            }
            try {
                telephonyManager!!.listen(phoneStateListener,
                    android.telephony.PhoneStateListener.LISTEN_CALL_STATE)
            } catch (e: Exception) { Log.w("PhoneState", "PhoneStateListener register failed: ${e.message}") }
        }
    }

    // Audio focus request — kept as a field so we can abandon the exact same
    // request object, which is required by the API 26+ AudioFocusRequest API.
    private var audioFocusRequest: android.media.AudioFocusRequest? = null

    private fun handleCallState(state: Int) {
        val am = getSystemService(AUDIO_SERVICE) as android.media.AudioManager
        when (state) {
            android.telephony.TelephonyManager.CALL_STATE_RINGING,
            android.telephony.TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // API 26+ — use AudioFocusRequest with a proper listener so
                    // playback resumes automatically when the call ends.
                    val req = android.media.AudioFocusRequest.Builder(
                        android.media.AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                    ).apply {
                        setAudioAttributes(
                            android.media.AudioAttributes.Builder()
                                .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                                .build()
                        )
                        setOnAudioFocusChangeListener({ focusChange ->
                            Log.d("AudioFocus", "Focus changed: $focusChange")
                        }, Handler(Looper.getMainLooper()))
                    }.build()
                    audioFocusRequest = req
                    am.requestAudioFocus(req)
                } else {
                    @Suppress("DEPRECATION")
                    am.requestAudioFocus(
                        null,
                        android.media.AudioManager.STREAM_MUSIC,
                        android.media.AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                    )
                }
            }
            android.telephony.TelephonyManager.CALL_STATE_IDLE -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
                    audioFocusRequest = null
                } else {
                    @Suppress("DEPRECATION")
                    am.abandonAudioFocus(null)
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun unregisterPhoneListener() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (telephonyCallback as? android.telephony.TelephonyCallback)?.let {
                try { telephonyManager?.unregisterTelephonyCallback(it) } catch (_: Exception) {}
            }
            telephonyCallback = null
        } else {
            phoneStateListener?.let {
                try { telephonyManager?.listen(it, android.telephony.PhoneStateListener.LISTEN_NONE) } catch (_: Exception) {}
            }
            phoneStateListener = null
        }
    }

    // ── Equalizer ────────────────────────────────────────────────────────

    private fun applyEqBands(gains: List<Double>) {
        try {
            if (equalizer == null) equalizer = android.media.audiofx.Equalizer(0, 0).apply { enabled = true }
            val eq    = equalizer ?: return
            val range = eq.getBandLevelRange()
            gains.take(eq.numberOfBands.toInt()).forEachIndexed { i, gainDb ->
                val mb = (gainDb * 100).toInt().toShort().coerceIn(range[0], range[1])
                eq.setBandLevel(i.toShort(), mb)
            }
        } catch (e: Exception) { Log.w("Equalizer", "applyEqBands failed: ${e.message}") }
    }

    // ── PiP ──────────────────────────────────────────────────────────────

    private fun isPipSupported() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun enterPipMode(width: Int, height: Int, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                enterPictureInPictureMode(
                    PictureInPictureParams.Builder().setAspectRatio(Rational(width, height)).build())
                result.success(true)
            } catch (e: Exception) { result.error("PIP_ERROR", e.message, null) }
        } else result.error("PIP_UNSUPPORTED", "PiP requires Android 8.0+", null)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Only auto-enter PiP when Flutter has signalled that video is actively
        // playing. Using isMusicActive was wrong — it reflects audio focus, not
        // video playback, so muted or silent videos never triggered PiP.
        if (isPipSupported() && isVideoPlaying) {
            try {
                enterPictureInPictureMode(
                    PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)).build())
            } catch (_: Exception) {}
        }
    }

    // Fix #11: pause the player when the app goes to background so the
    // MediaKit surface is not rendering to a detached surface. Resume on
    // foreground. We signal Flutter via the existing PiP channel which
    // MediaKitEngine already listens to for PiP state changes.
    override fun onPause() {
        super.onPause()
        // Only pause if NOT entering PiP (PiP keeps the surface alive).
        if (!isInPictureInPictureMode) {
            try {
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, pipChannel).invokeMethod("playerPause", null)
                }
            } catch (_: Exception) {}
        }
    }

    override fun onResume() {
        super.onResume()
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, pipChannel).invokeMethod("playerResume", null)
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        // Fix #10: cancel the IO coroutine scope so any in-progress trim/extract
        // operations are properly cleaned up and do not leak threads.
        ioScope.cancel()
        unregisterMediaObserver()
        unregisterPhoneListener()
        equalizer?.release()
        super.onDestroy()
    }
}
