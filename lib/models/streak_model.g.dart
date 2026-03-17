// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StreakAdapter extends TypeAdapter<Streak> {
  @override
  final int typeId = 15;

  @override
  Streak read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Streak(
      currentStreak: fields[0] as int,
      weekStreak: fields[1] as int,
      hasStreakToday: fields[2] as bool,
      streakLevel: fields[3] as String,
      longestStreak: fields[4] as String,
      history: (fields[5] as List).cast<DateTime>(),
    );
  }

  @override
  void write(BinaryWriter writer, Streak obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.currentStreak)
      ..writeByte(1)
      ..write(obj.weekStreak)
      ..writeByte(2)
      ..write(obj.hasStreakToday)
      ..writeByte(3)
      ..write(obj.streakLevel)
      ..writeByte(4)
      ..write(obj.longestStreak)
      ..writeByte(5)
      ..write(obj.history);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
