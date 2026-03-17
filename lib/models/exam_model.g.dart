// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExamAdapter extends TypeAdapter<Exam> {
  @override
  final int typeId = 7;

  @override
  Exam read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exam(
      id: fields[0] as int,
      title: fields[1] as String,
      examType: fields[2] as String,
      startDate: fields[3] as DateTime,
      endDate: fields[4] as DateTime,
      duration: fields[5] as int,
      userTimeLimit: fields[6] as int?,
      passingScore: fields[7] as int,
      maxAttempts: fields[8] as int,
      autoSubmit: fields[9] as bool,
      showResultsImmediately: fields[10] as bool,
      courseName: fields[11] as String,
      courseId: fields[12] as int,
      categoryId: fields[13] as int,
      categoryName: fields[14] as String,
      categoryStatus: fields[15] as String,
      attemptsTaken: fields[16] as int,
      lastAttemptStatus: fields[17] as String?,
      questionCount: fields[18] as int,
      status: fields[19] as String,
      message: fields[20] as String,
      canTakeExam: fields[21] as bool,
      requiresPayment: fields[22] as bool,
      hasAccess: fields[23] as bool,
      actualDuration: fields[24] as int,
      timingType: fields[25] as String,
      hasPendingPayment: fields[26] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Exam obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.examType)
      ..writeByte(3)
      ..write(obj.startDate)
      ..writeByte(4)
      ..write(obj.endDate)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.userTimeLimit)
      ..writeByte(7)
      ..write(obj.passingScore)
      ..writeByte(8)
      ..write(obj.maxAttempts)
      ..writeByte(9)
      ..write(obj.autoSubmit)
      ..writeByte(10)
      ..write(obj.showResultsImmediately)
      ..writeByte(11)
      ..write(obj.courseName)
      ..writeByte(12)
      ..write(obj.courseId)
      ..writeByte(13)
      ..write(obj.categoryId)
      ..writeByte(14)
      ..write(obj.categoryName)
      ..writeByte(15)
      ..write(obj.categoryStatus)
      ..writeByte(16)
      ..write(obj.attemptsTaken)
      ..writeByte(17)
      ..write(obj.lastAttemptStatus)
      ..writeByte(18)
      ..write(obj.questionCount)
      ..writeByte(19)
      ..write(obj.status)
      ..writeByte(20)
      ..write(obj.message)
      ..writeByte(21)
      ..write(obj.canTakeExam)
      ..writeByte(22)
      ..write(obj.requiresPayment)
      ..writeByte(23)
      ..write(obj.hasAccess)
      ..writeByte(24)
      ..write(obj.actualDuration)
      ..writeByte(25)
      ..write(obj.timingType)
      ..writeByte(26)
      ..write(obj.hasPendingPayment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
