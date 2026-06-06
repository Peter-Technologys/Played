import 'dart:io';
import 'package:hive/hive.dart';

part 'media_item.g.dart';

@HiveType(typeId: 0)
class MediaItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String fileName;

  @HiveField(3)
  final String filePath;

  @HiveField(4)
  final bool isVideo;

  @HiveField(5)
  final Duration? duration;

  @HiveField(6)
  DateTime? lastPlayedAt;

  @HiveField(7)
  final DateTime addedAt;

  @HiveField(8)
  final int fileSizeBytes;

  @HiveField(9)
  final String? thumbnailPath;

  @HiveField(10)
  final String? albumArtPath;

  @HiveField(11)
  final String? artist;

  @HiveField(12)
  final String? album;

  MediaItem({
    required this.id,
    required this.title,
    required this.fileName,
    required this.filePath,
    required this.isVideo,
    this.duration,
    this.lastPlayedAt,
    required this.addedAt,
    required this.fileSizeBytes,
    this.thumbnailPath,
    this.albumArtPath,
    this.artist,
    this.album,
  });

  /// Returns the underlying [File] object for this media item.
  File get file => File(filePath);

  String get formattedSize {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDuration {
    if (duration == null) return '--:--';
    final h = duration!.inHours;
    final m = duration!.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration!.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
