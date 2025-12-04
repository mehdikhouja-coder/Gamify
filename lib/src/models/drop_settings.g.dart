// GENERATED CODE - placeholder manual adapter
// Normally build_runner would generate this; implementing minimal adapter manually.

part of 'drop_settings.dart';

class DropSettingsAdapter extends TypeAdapter<DropSettings> {
  @override
  final int typeId = 5;

  @override
  DropSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return DropSettings(
      chanceCap: (fields[0] as double?) ?? 0.50,
      commonWeight: (fields[1] as double?) ?? 80.0,
      rareWeight: (fields[2] as double?) ?? 18.0,
      epicWeight: (fields[3] as double?) ?? 2.0,
      scarcityBoost: (fields[4] as double?) ?? 1.5,
    );
  }

  @override
  void write(BinaryWriter writer, DropSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.chanceCap)
      ..writeByte(1)
      ..write(obj.commonWeight)
      ..writeByte(2)
      ..write(obj.rareWeight)
      ..writeByte(3)
      ..write(obj.epicWeight)
      ..writeByte(4)
      ..write(obj.scarcityBoost);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DropSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
