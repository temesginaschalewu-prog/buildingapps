// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 2;

  @override
  Course read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Course(
      id: fields[0] as int,
      name: fields[1] as String,
      categoryId: fields[2] as int,
      description: fields[3] as String?,
      chapterCount: fields[4] as int,
      access: fields[5] as String?,
      message: fields[6] as String?,
      hasPendingPayment: fields[7] as bool,
      requiresPayment: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.chapterCount)
      ..writeByte(5)
      ..write(obj.access)
      ..writeByte(6)
      ..write(obj.message)
      ..writeByte(7)
      ..write(obj.hasPendingPayment)
      ..writeByte(8)
      ..write(obj.requiresPayment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
