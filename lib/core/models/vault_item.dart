import 'package:hive/hive.dart';

part 'vault_item.g.dart';

@HiveType(typeId: 3)
class VaultItem extends HiveObject {
  @HiveField(0)
  final String mediaId;

  @HiveField(1)
  final String originalPath;

  @HiveField(2)
  final String encryptedPath;

  @HiveField(3)
  final DateTime lockedAt;

  @HiveField(4)
  final String mediaType; // 'video' | 'audio'

  VaultItem({
    required this.mediaId,
    required this.originalPath,
    required this.encryptedPath,
    required this.lockedAt,
    required this.mediaType,
  });

  Map<String, dynamic> toJson() => {
        'mediaId': mediaId,
        'originalPath': originalPath,
        'encryptedPath': encryptedPath,
        'lockedAt': lockedAt.toIso8601String(),
        'mediaType': mediaType,
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
        mediaId: json['mediaId'] as String,
        originalPath: json['originalPath'] as String,
        encryptedPath: json['encryptedPath'] as String,
        lockedAt: DateTime.parse(json['lockedAt'] as String),
        mediaType: json['mediaType'] as String,
      );
}
