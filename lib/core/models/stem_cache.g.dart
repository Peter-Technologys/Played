// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
part of 'stem_cache.dart';

class StemCacheAdapter extends TypeAdapter<StemCache> {
  @override
  final int typeId = 2;

  @override
  StemCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StemCache(
      sourceMediaId: fields[0] as String,
      sourceTitle: fields[1] as String,
      vocalPath: fields[2] as String,
      instrumentalPath: fields[3] as String,
      cachedAt: fields[4] as DateTime,
      splitEngine: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, StemCache obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.sourceMediaId)
      ..writeByte(1)
      ..write(obj.sourceTitle)
      ..writeByte(2)
      ..write(obj.vocalPath)
      ..writeByte(3)
      ..write(obj.instrumentalPath)
      ..writeByte(4)
      ..write(obj.cachedAt)
      ..writeByte(5)
      ..write(obj.splitEngine);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StemCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
