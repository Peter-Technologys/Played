import 'package:hive/hive.dart';

part 'stem_cache.g.dart';

@HiveType(typeId: 2)
class StemCache extends HiveObject {
  @HiveField(0)
  final String sourceMediaId;

  @HiveField(1)
  final String sourceTitle;

  @HiveField(2)
  final String vocalPath;

  @HiveField(3)
  final String instrumentalPath;

  @HiveField(4)
  final DateTime cachedAt;

  @HiveField(5)
  final String splitEngine; // 'spleeter' | 'demucs'

  StemCache({
    required this.sourceMediaId,
    required this.sourceTitle,
    required this.vocalPath,
    required this.instrumentalPath,
    required this.cachedAt,
    required this.splitEngine,
  });
}
