// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
part of 'media_item.dart';

class MediaItemAdapter extends TypeAdapter<MediaItem> {
  @override
  final int typeId = 0;

  @override
  MediaItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaItem(
      id: fields[0] as String,
      title: fields[1] as String,
      fileName: fields[2] as String,
      filePath: fields[3] as String,
      isVideo: fields[4] as bool,
      duration: fields[5] as Duration?,
      lastPlayedAt: fields[6] as DateTime?,
      addedAt: fields[7] as DateTime,
      fileSizeBytes: fields[8] as int,
      thumbnailPath: fields[9] as String?,
      albumArtPath: fields[10] as String?,
      artist: fields[11] as String?,
      album: fields[12] as String?,
      mediaStoreId: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaItem obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.fileName)
      ..writeByte(3)
      ..write(obj.filePath)
      ..writeByte(4)
      ..write(obj.isVideo)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.lastPlayedAt)
      ..writeByte(7)
      ..write(obj.addedAt)
      ..writeByte(8)
      ..write(obj.fileSizeBytes)
      ..writeByte(9)
      ..write(obj.thumbnailPath)
      ..writeByte(10)
      ..write(obj.albumArtPath)
      ..writeByte(11)
      ..write(obj.artist)
      ..writeByte(12)
      ..write(obj.album)
      ..writeByte(13)
      ..write(obj.mediaStoreId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
