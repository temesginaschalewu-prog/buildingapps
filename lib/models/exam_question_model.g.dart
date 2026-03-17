// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_question_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExamQuestionAdapter extends TypeAdapter<ExamQuestion> {
  @override
  final int typeId = 19;

  @override
  ExamQuestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExamQuestion(
      id: fields[0] as int,
      examId: fields[1] as int,
      questionId: fields[2] as int,
      displayOrder: fields[3] as int,
      marks: fields[4] as int,
      questionText: fields[5] as String,
      optionA: fields[6] as String?,
      optionB: fields[7] as String?,
      optionC: fields[8] as String?,
      optionD: fields[9] as String?,
      optionE: fields[10] as String?,
      optionF: fields[11] as String?,
      difficulty: fields[12] as String,
      hasAnswer: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ExamQuestion obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.examId)
      ..writeByte(2)
      ..write(obj.questionId)
      ..writeByte(3)
      ..write(obj.displayOrder)
      ..writeByte(4)
      ..write(obj.marks)
      ..writeByte(5)
      ..write(obj.questionText)
      ..writeByte(6)
      ..write(obj.optionA)
      ..writeByte(7)
      ..write(obj.optionB)
      ..writeByte(8)
      ..write(obj.optionC)
      ..writeByte(9)
      ..write(obj.optionD)
      ..writeByte(10)
      ..write(obj.optionE)
      ..writeByte(11)
      ..write(obj.optionF)
      ..writeByte(12)
      ..write(obj.difficulty)
      ..writeByte(13)
      ..write(obj.hasAnswer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamQuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
