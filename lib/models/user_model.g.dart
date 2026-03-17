// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 0;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: fields[0] as int,
      username: fields[1] as String,
      email: fields[2] as String?,
      phone: fields[3] as String?,
      profileImage: fields[4] as String?,
      schoolId: fields[5] as int?,
      accountStatus: fields[6] as String,
      primaryDeviceId: fields[7] as String?,
      tvDeviceId: fields[8] as String?,
      parentLinked: fields[9] as bool,
      parentTelegramUsername: fields[10] as String?,
      parentLinkDate: fields[11] as DateTime?,
      streakCount: fields[12] as int,
      lastStreakDate: fields[13] as DateTime?,
      totalStudyTime: fields[14] as int,
      adminNotes: fields[15] as String?,
      createdAt: fields[16] as DateTime,
      updatedAt: fields[17] as DateTime,
      subscriptions: (fields[18] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.profileImage)
      ..writeByte(5)
      ..write(obj.schoolId)
      ..writeByte(6)
      ..write(obj.accountStatus)
      ..writeByte(7)
      ..write(obj.primaryDeviceId)
      ..writeByte(8)
      ..write(obj.tvDeviceId)
      ..writeByte(9)
      ..write(obj.parentLinked)
      ..writeByte(10)
      ..write(obj.parentTelegramUsername)
      ..writeByte(11)
      ..write(obj.parentLinkDate)
      ..writeByte(12)
      ..write(obj.streakCount)
      ..writeByte(13)
      ..write(obj.lastStreakDate)
      ..writeByte(14)
      ..write(obj.totalStudyTime)
      ..writeByte(15)
      ..write(obj.adminNotes)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.updatedAt)
      ..writeByte(18)
      ..write(obj.subscriptions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
