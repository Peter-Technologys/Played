package com.petersmartlink.otya_media_tools

import android.content.ContentValues
import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.math.min

class OtyaMediaToolsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val busy = AtomicBoolean(false)
    private val cancelled = AtomicBoolean(false)
    @Volatile private var activeTask: Future<*>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        cancelled.set(true)
        activeTask?.cancel(true)
        executor.shutdownNow()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "trimVideo" -> runOperation(result) {
                val path = call.argument<String>("path").orEmpty()
                val startMs = (call.argument<Number>("startMs")?.toLong() ?: 0L).coerceAtLeast(0L)
                val endMs = call.argument<Number>("endMs")?.toLong() ?: 30_000L
                trimVideo(path, startMs, endMs)
            }
            "extractAudio" -> runOperation(result) {
                extractAudio(call.argument<String>("path").orEmpty())
            }
            "cancel" -> {
                cancelled.set(true)
                activeTask?.cancel(true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun runOperation(result: MethodChannel.Result, block: () -> String) {
        if (!busy.compareAndSet(false, true)) {
            result.error("BUSY", "Another media tool is already running.", null)
            return
        }
        cancelled.set(false)
        activeTask = executor.submit {
            try {
                val output = block()
                main.post { result.success(output) }
            } catch (failure: MediaToolFailure) {
                main.post { result.error(failure.code, failure.message, null) }
            } catch (_: InterruptedException) {
                main.post { result.error("CANCELLED", "Operation cancelled.", null) }
            } catch (error: Throwable) {
                val message = error.message?.take(240).orEmpty()
                main.post {
                    result.error(
                        "MEDIA_TOOL_FAILED",
                        if (message.isBlank()) "OTYA could not process this file." else "OTYA could not process this file: $message",
                        null,
                    )
                }
            } finally {
                activeTask = null
                busy.set(false)
            }
        }
    }

    private fun trimVideo(inputPath: String, startMs: Long, endMs: Long): String {
        if (inputPath.isBlank()) throw MediaToolFailure("TRIM_FILE_UNREADABLE", "Choose a readable local video and try again.")
        if (endMs <= startMs) throw MediaToolFailure("TRIM_RANGE_INVALID", "The trim end must be after the start.")
        checkCancelled()

        val temp = File.createTempFile("otya_trim_v2_", ".mp4", context.cacheDir)
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var started = false
        try {
            setDataSource(extractor, inputPath)
            if (extractor.trackCount <= 0) throw MediaToolFailure("TRIM_FILE_UNREADABLE", "OTYA could not read media tracks from this file.")

            muxer = MediaMuxer(temp.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            readRotation(inputPath)?.let { rotation -> if (rotation in setOf(90, 180, 270)) muxer.setOrientationHint(rotation) }

            val tracks = mutableListOf<Track>()
            var hasVideo = false
            var requiredBuffer = DEFAULT_BUFFER_BYTES
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME).orEmpty()
                if (!mime.startsWith("video/") && !mime.startsWith("audio/")) continue
                val target = try {
                    muxer.addTrack(format)
                } catch (_: IllegalArgumentException) {
                    throw MediaToolFailure(
                        "TRIM_UNSUPPORTED_FORMAT",
                        "This video uses a $mime track that Android cannot save into an MP4 clip without re-encoding.",
                    )
                }
                val declared = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    runCatching { format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE) }.getOrDefault(0)
                } else 0
                if (declared > MAX_BUFFER_BYTES) {
                    throw MediaToolFailure("TRIM_SAMPLE_TOO_LARGE", "This file needs unusually large media samples that the local trimmer cannot safely process.")
                }
                requiredBuffer = max(requiredBuffer, declared.coerceAtLeast(0))
                hasVideo = hasVideo || mime.startsWith("video/")
                tracks += Track(index, target, mime)
            }
            if (!hasVideo) throw MediaToolFailure("TRIM_NO_VIDEO", "The selected file does not contain a video track.")
            if (tracks.isEmpty()) throw MediaToolFailure("TRIM_UNSUPPORTED_FORMAT", "No MP4-compatible audio or video tracks were found.")

            muxer.start()
            started = true
            val requestedStartUs = startMs * 1_000L
            val requestedDurationUs = (endMs - startMs) * 1_000L
            val originUs = findPlayableOrigin(extractor, tracks, requestedStartUs)
            val endUs = originUs + requestedDurationUs
            val bufferSize = min(MAX_BUFFER_BYTES, max(DEFAULT_BUFFER_BYTES, requiredBuffer))
            val buffer = ByteBuffer.allocateDirect(bufferSize)
            val info = MediaCodec.BufferInfo()
            var videoSamples = 0
            var totalSamples = 0

            for (track in tracks) {
                checkCancelled()
                unselectAll(extractor)
                extractor.selectTrack(track.source)
                extractor.seekTo(
                    originUs,
                    if (track.mime.startsWith("video/")) MediaExtractor.SEEK_TO_PREVIOUS_SYNC else MediaExtractor.SEEK_TO_CLOSEST_SYNC,
                )
                while (true) {
                    checkCancelled()
                    buffer.clear()
                    val size = try {
                        extractor.readSampleData(buffer, 0)
                    } catch (_: RuntimeException) {
                        throw MediaToolFailure("TRIM_SAMPLE_TOO_LARGE", "A media sample in this file is too large for safe local trimming.")
                    }
                    if (size < 0) break
                    if (size > buffer.capacity()) throw MediaToolFailure("TRIM_SAMPLE_TOO_LARGE", "A media sample in this file is too large for safe local trimming.")
                    val pts = extractor.sampleTime
                    if (pts < 0 || pts > endUs) break
                    if (pts < originUs) {
                        if (!extractor.advance()) break
                        continue
                    }
                    info.offset = 0
                    info.size = size
                    info.presentationTimeUs = pts - originUs
                    info.flags = extractor.sampleFlags
                    try {
                        muxer.writeSampleData(track.target, buffer, info)
                    } catch (_: IllegalStateException) {
                        throw MediaToolFailure("TRIM_MUX_FAILED", "Android could not write this codec combination into a new MP4 clip.")
                    }
                    totalSamples += 1
                    if (track.mime.startsWith("video/")) videoSamples += 1
                    if (!extractor.advance()) break
                }
            }

            if (totalSamples == 0 || videoSamples == 0) throw MediaToolFailure("TRIM_EMPTY_RANGE", "No playable video samples were found in that time range.")
            muxer.stop()
            started = false
            return publishGeneratedMedia(
                temp,
                "OTYA_trim_${System.currentTimeMillis()}.mp4",
                "video/mp4",
                true,
            )
        } catch (failure: MediaToolFailure) {
            throw failure
        } catch (error: SecurityException) {
            throw MediaToolFailure("TRIM_FILE_UNREADABLE", "OTYA does not have permission to read this video.")
        } catch (error: IllegalArgumentException) {
            throw MediaToolFailure("TRIM_UNSUPPORTED_FORMAT", "This video format cannot be trimmed locally on this Android device.")
        } catch (error: IllegalStateException) {
            throw MediaToolFailure("TRIM_MUX_FAILED", "Android could not create a valid MP4 clip from this file.")
        } finally {
            if (started) runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            runCatching { extractor.release() }
            if (temp.exists()) temp.delete()
        }
    }

    private fun extractAudio(inputPath: String): String {
        if (inputPath.isBlank()) throw MediaToolFailure("EXTRACT_FILE_UNREADABLE", "Choose a readable local video and try again.")
        checkCancelled()
        val temp = File.createTempFile("otya_audio_v2_", ".m4a", context.cacheDir)
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var started = false
        try {
            setDataSource(extractor, inputPath)
            var sourceTrack = -1
            var audioFormat: MediaFormat? = null
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                if (format.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                    sourceTrack = index
                    audioFormat = format
                    break
                }
            }
            if (sourceTrack < 0 || audioFormat == null) throw MediaToolFailure("EXTRACT_NO_AUDIO", "This video does not contain an audio track.")
            val mime = audioFormat.getString(MediaFormat.KEY_MIME).orEmpty()
            val declared = if (audioFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) runCatching { audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE) }.getOrDefault(0) else 0
            if (declared > MAX_BUFFER_BYTES) throw MediaToolFailure("EXTRACT_SAMPLE_TOO_LARGE", "This audio track uses unusually large samples.")

            muxer = MediaMuxer(temp.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val target = try { muxer.addTrack(audioFormat) } catch (_: IllegalArgumentException) {
                throw MediaToolFailure("EXTRACT_UNSUPPORTED_FORMAT", "The $mime audio track cannot be saved as M4A without re-encoding.")
            }
            extractor.selectTrack(sourceTrack)
            muxer.start(); started = true
            val buffer = ByteBuffer.allocateDirect(max(DEFAULT_BUFFER_BYTES, declared.coerceAtLeast(0)))
            val info = MediaCodec.BufferInfo()
            var firstPts = -1L
            var samples = 0
            while (true) {
                checkCancelled(); buffer.clear()
                val size = try { extractor.readSampleData(buffer, 0) } catch (_: RuntimeException) {
                    throw MediaToolFailure("EXTRACT_SAMPLE_TOO_LARGE", "An audio sample is too large for safe local extraction.")
                }
                if (size < 0) break
                if (size > buffer.capacity()) throw MediaToolFailure("EXTRACT_SAMPLE_TOO_LARGE", "An audio sample is too large for safe local extraction.")
                val pts = extractor.sampleTime
                if (pts < 0) break
                if (firstPts < 0) firstPts = pts
                info.offset = 0; info.size = size; info.presentationTimeUs = pts - firstPts; info.flags = extractor.sampleFlags
                muxer.writeSampleData(target, buffer, info)
                samples += 1
                if (!extractor.advance()) break
            }
            if (samples == 0) throw MediaToolFailure("EXTRACT_EMPTY", "OTYA could not find playable audio samples in this file.")
            muxer.stop(); started = false
            return publishGeneratedMedia(temp, "OTYA_audio_${System.currentTimeMillis()}.m4a", "audio/mp4", false)
        } finally {
            if (started) runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            runCatching { extractor.release() }
            if (temp.exists()) temp.delete()
        }
    }

    private fun findPlayableOrigin(extractor: MediaExtractor, tracks: List<Track>, requestedStartUs: Long): Long {
        val video = tracks.firstOrNull { it.mime.startsWith("video/") } ?: return requestedStartUs
        unselectAll(extractor)
        extractor.selectTrack(video.source)
        extractor.seekTo(requestedStartUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        val sample = extractor.sampleTime
        return if (sample >= 0) sample else requestedStartUs
    }

    private fun unselectAll(extractor: MediaExtractor) {
        for (index in 0 until extractor.trackCount) runCatching { extractor.unselectTrack(index) }
    }

    private fun setDataSource(extractor: MediaExtractor, path: String) {
        if (path.startsWith("content://")) extractor.setDataSource(context, Uri.parse(path), null)
        else extractor.setDataSource(path)
    }

    private fun readRotation(path: String): Int? {
        val retriever = MediaMetadataRetriever()
        return try {
            if (path.startsWith("content://")) retriever.setDataSource(context, Uri.parse(path)) else retriever.setDataSource(path)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull()
        } catch (_: Exception) { null } finally { runCatching { retriever.release() } }
    }

    private fun publishGeneratedMedia(temp: File, displayName: String, mimeType: String, video: Boolean): String {
        if (!temp.exists() || temp.length() <= 0L) throw MediaToolFailure("MEDIA_OUTPUT_EMPTY", "Android created an empty media result.")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (video) MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY) else MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val directory = if (video) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_MUSIC
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$directory/OTYA")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(collection, values)
                ?: throw MediaToolFailure("MEDIA_SAVE_FAILED", "Android could not create a destination for the processed file.")
            try {
                context.contentResolver.openOutputStream(uri, "w")?.use { output -> temp.inputStream().use { it.copyTo(output) } }
                    ?: throw MediaToolFailure("MEDIA_SAVE_FAILED", "Android could not open the destination file.")
                values.clear(); values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                context.contentResolver.update(uri, values, null, null)
                return mediaPathForUri(uri) ?: uri.toString()
            } catch (error: Throwable) {
                runCatching { context.contentResolver.delete(uri, null, null) }
                if (error is MediaToolFailure) throw error
                throw MediaToolFailure("MEDIA_SAVE_FAILED", "OTYA created the media but Android could not save it to your library.")
            }
        }

        @Suppress("DEPRECATION")
        val base = Environment.getExternalStoragePublicDirectory(if (video) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_MUSIC)
        val directory = File(base, "OTYA").apply { mkdirs() }
        val output = uniqueFile(directory, displayName)
        try { temp.copyTo(output, overwrite = false) } catch (_: Exception) {
            throw MediaToolFailure("MEDIA_SAVE_FAILED", "OTYA created the media but Android could not save it to your library.")
        }
        MediaScannerConnection.scanFile(context, arrayOf(output.absolutePath), arrayOf(mimeType), null)
        return output.absolutePath
    }

    private fun mediaPathForUri(uri: Uri): String? = try {
        context.contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val column = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
            if (column >= 0) cursor.getString(column) else null
        }
    } catch (_: Exception) { null }

    private fun uniqueFile(directory: File, name: String): File {
        val direct = File(directory, name)
        if (!direct.exists()) return direct
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val extension = if (dot > 0) name.substring(dot) else ""
        for (index in 2..999) {
            val candidate = File(directory, "$base ($index)$extension")
            if (!candidate.exists()) return candidate
        }
        return File(directory, "${base}_${System.currentTimeMillis()}$extension")
    }

    private fun checkCancelled() {
        if (cancelled.get() || Thread.currentThread().isInterrupted) throw InterruptedException("cancelled")
    }

    private data class Track(val source: Int, val target: Int, val mime: String)
    private class MediaToolFailure(val code: String, override val message: String) : RuntimeException(message)

    companion object {
        private const val CHANNEL = "com.otyaplayer.app/media_tools_v2"
        private const val DEFAULT_BUFFER_BYTES = 8 * 1024 * 1024
        private const val MAX_BUFFER_BYTES = 32 * 1024 * 1024
    }
}
