// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
part of 'vault_item.dart';

class VaultItemAdapter extends TypeAdapter<VaultItem> {
  @override
  final int typeId = 3;

  @override
  VaultItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VaultItem(
      mediaId: fields[0] as String,
      originalPath: fields[1] as String,
      encryptedPath: fields[2] as String,
      lockedAt: fields[3] as DateTime,
      mediaType: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, VaultItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.mediaId)
      ..writeByte(1)
      ..write(obj.originalPath)
      ..writeByte(2)
      ..write(obj.encryptedPath)
      ..writeByte(3)
      ..write(obj.lockedAt)
      ..writeByte(4)
      ..write(obj.mediaType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
