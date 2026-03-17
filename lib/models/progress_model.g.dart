// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProgressAdapter extends TypeAdapter<UserProgress> {
  @override
  final int typeId = 12;

  @override
  UserProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProgress(
      chapterId: fields[0] as int,
      completed: fields[1] as bool,
      videoProgress: fields[2] as int,
      notesViewed: fields[3] as bool,
      questionsAttempted: fields[4] as int,
      questionsCorrect: fields[5] as int,
      lastAccessed: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProgress obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.chapterId)
      ..writeByte(1)
      ..write(obj.completed)
      ..writeByte(2)
      ..write(obj.videoProgress)
      ..writeByte(3)
      ..write(obj.notesViewed)
      ..writeByte(4)
      ..write(obj.questionsAttempted)
      ..writeByte(5)
      ..write(obj.questionsCorrect)
      ..writeByte(6)
      ..write(obj.lastAccessed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
