// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parent_link_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ParentLinkAdapter extends TypeAdapter<ParentLink> {
  @override
  final int typeId = 18;

  @override
  ParentLink read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ParentLink(
      id: fields[0] as int,
      userId: fields[1] as int,
      token: fields[2] as String,
      parentTelegramUsername: fields[3] as String?,
      parentTelegramId: fields[4] as int?,
      tokenExpiresAt: fields[5] as DateTime,
      linkedAt: fields[6] as DateTime?,
      unlinkedAt: fields[7] as DateTime?,
      status: fields[8] as String,
      username: fields[9] as String?,
      accountStatus: fields[10] as String?,
      parentName: fields[11] as String?,
      serverTime: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ParentLink obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.token)
      ..writeByte(3)
      ..write(obj.parentTelegramUsername)
      ..writeByte(4)
      ..write(obj.parentTelegramId)
      ..writeByte(5)
      ..write(obj.tokenExpiresAt)
      ..writeByte(6)
      ..write(obj.linkedAt)
      ..writeByte(7)
      ..write(obj.unlinkedAt)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.username)
      ..writeByte(10)
      ..write(obj.accountStatus)
      ..writeByte(11)
      ..write(obj.parentName)
      ..writeByte(12)
      ..write(obj.serverTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParentLinkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
