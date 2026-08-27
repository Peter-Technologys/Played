from pathlib import Path

video = Path('lib/features/video/presentation/video_tab_screen.dart')
text = video.read_text()
old = "'id': widget.item.id,"
new = "'id': widget.item.mediaStoreId ?? widget.item.id,"
count = text.count(old)
if count < 3:
    raise SystemExit(f'expected >=3 thumbnail id call sites, found {count}')
text = text.replace(old, new)
video.write_text(text)

kt = Path('android/app/src/main/kotlin/com/otyaplayer/app/MainActivity.kt')
text = kt.read_text()
old = '''    private fun getVideoThumbnail(videoPath: String, videoId: String): String? {
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
'''
new = '''    private fun getVideoThumbnail(videoPath: String, videoId: String): String? {
        val cacheKey = (videoId.ifBlank { videoPath }).hashCode().toUInt().toString(16)
        val thumbDir = File(cacheDir, "video_thumbs").also { it.mkdirs() }
        val thumbFile = File(thumbDir, "$cacheKey.jpg")
        if (thumbFile.exists() && thumbFile.length() > 0L) return thumbFile.absolutePath

        var bitmap: Bitmap? = null
        val numericId = videoId.toLongOrNull()
        if (numericId != null) {
            bitmap = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val uri = ContentUris.withAppendedId(
                        MediaStore.Video.Media.EXTERNAL_CONTENT_URI, numericId)
                    contentResolver.loadThumbnail(uri, Size(320, 180), null)
                } else {
                    @Suppress("DEPRECATION")
                    MediaStore.Video.Thumbnails.getThumbnail(
                        contentResolver, numericId,
                        MediaStore.Video.Thumbnails.MINI_KIND, null)
                }
            } catch (_: Exception) { null }
        }

        if (bitmap == null && videoPath.isNotBlank()) {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(videoPath)
                bitmap = retriever.getFrameAtTime(
                    1_000_000L,
                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                ) ?: retriever.frameAtTime
            } catch (_: Exception) {
                bitmap = null
            } finally {
                try { retriever.release() } catch (_: Exception) {}
            }
        }

        return try {
            bitmap?.let {
                FileOutputStream(thumbFile).use { out ->
                    it.compress(Bitmap.CompressFormat.JPEG, 82, out)
                }
                if (thumbFile.length() > 0L) thumbFile.absolutePath else null
            }
        } catch (_: Exception) { null }
    }
'''
if old not in text:
    raise SystemExit('native thumbnail function did not match expected source')
kt.write_text(text.replace(old, new))
