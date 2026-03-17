// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_result_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExamResultAdapter extends TypeAdapter<ExamResult> {
  @override
  final int typeId = 8;

  @override
  ExamResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExamResult(
      id: fields[0] as int,
      examId: fields[1] as int,
      userId: fields[2] as int,
      score: fields[3] as double,
      totalQuestions: fields[4] as int,
      correctAnswers: fields[5] as int,
      timeTaken: fields[6] as int,
      startedAt: fields[7] as DateTime,
      completedAt: fields[8] as DateTime?,
      status: fields[9] as String,
      examCode: fields[10] as String?,
      answerDetails: (fields[11] as List?)?.cast<dynamic>(),
      title: fields[12] as String,
      examType: fields[13] as String,
      duration: fields[14] as int,
      passingScore: fields[15] as int,
      courseName: fields[16] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ExamResult obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.examId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.score)
      ..writeByte(4)
      ..write(obj.totalQuestions)
      ..writeByte(5)
      ..write(obj.correctAnswers)
      ..writeByte(6)
      ..write(obj.timeTaken)
      ..writeByte(7)
      ..write(obj.startedAt)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.examCode)
      ..writeByte(11)
      ..write(obj.answerDetails)
      ..writeByte(12)
      ..write(obj.title)
      ..writeByte(13)
      ..write(obj.examType)
      ..writeByte(14)
      ..write(obj.duration)
      ..writeByte(15)
      ..write(obj.passingScore)
      ..writeByte(16)
      ..write(obj.courseName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
