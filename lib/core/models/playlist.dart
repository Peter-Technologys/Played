import 'package:hive/hive.dart';

part 'playlist.g.dart';

@HiveType(typeId: 1)
class Playlist extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> mediaIds;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  String? coverMediaId;

  Playlist({
    required this.id,
    required this.name,
    required this.mediaIds,
    required this.createdAt,
    required this.updatedAt,
    this.coverMediaId,
  });

  int get trackCount => mediaIds.length;
}
