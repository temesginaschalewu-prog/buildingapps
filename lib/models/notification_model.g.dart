// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotificationAdapter extends TypeAdapter<Notification> {
  @override
  final int typeId = 11;

  @override
  Notification read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Notification(
      logId: fields[0] as int,
      notificationId: fields[1] as int?,
      title: fields[2] as String,
      message: fields[3] as String,
      deliveryStatus: fields[4] as String,
      isRead: fields[5] as bool,
      receivedAt: fields[6] as DateTime,
      sentAt: fields[7] as DateTime?,
      readAt: fields[8] as DateTime?,
      deliveredAt: fields[9] as DateTime?,
      sentBy: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Notification obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.logId)
      ..writeByte(1)
      ..write(obj.notificationId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.message)
      ..writeByte(4)
      ..write(obj.deliveryStatus)
      ..writeByte(5)
      ..write(obj.isRead)
      ..writeByte(6)
      ..write(obj.receivedAt)
      ..writeByte(7)
      ..write(obj.sentAt)
      ..writeByte(8)
      ..write(obj.readAt)
      ..writeByte(9)
      ..write(obj.deliveredAt)
      ..writeByte(10)
      ..write(obj.sentBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
