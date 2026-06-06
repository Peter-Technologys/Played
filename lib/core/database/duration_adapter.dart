import 'package:hive/hive.dart';

/// Custom Hive TypeAdapter for [Duration].
/// Stores duration as total milliseconds (int).
/// TypeId 10 — reserved for Duration.
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 10;

  @override
  Duration read(BinaryReader reader) {
    final ms = reader.readInt();
    return Duration(milliseconds: ms);
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMilliseconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DurationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
