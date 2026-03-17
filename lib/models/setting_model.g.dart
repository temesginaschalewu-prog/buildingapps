// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingAdapter extends TypeAdapter<Setting> {
  @override
  final int typeId = 17;

  @override
  Setting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Setting(
      id: fields[0] as int,
      settingKey: fields[1] as String,
      settingValue: fields[2] as String?,
      displayName: fields[3] as String,
      category: fields[4] as String,
      dataType: fields[5] as String,
      isPublic: fields[6] as bool,
      displayOrder: fields[7] as int,
      description: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Setting obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.settingKey)
      ..writeByte(2)
      ..write(obj.settingValue)
      ..writeByte(3)
      ..write(obj.displayName)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.dataType)
      ..writeByte(6)
      ..write(obj.isPublic)
      ..writeByte(7)
      ..write(obj.displayOrder)
      ..writeByte(8)
      ..write(obj.description)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
