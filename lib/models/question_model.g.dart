// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuestionAdapter extends TypeAdapter<Question> {
  @override
  final int typeId = 6;

  @override
  Question read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Question(
      id: fields[0] as int,
      questionType: fields[1] as String,
      chapterId: fields[2] as int?,
      examId: fields[3] as int?,
      questionText: fields[4] as String,
      optionA: fields[5] as String?,
      optionB: fields[6] as String?,
      optionC: fields[7] as String?,
      optionD: fields[8] as String?,
      optionE: fields[9] as String?,
      optionF: fields[10] as String?,
      correctOption: fields[11] as String,
      explanation: fields[12] as String?,
      difficulty: fields[13] as String,
      hasAnswer: fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Question obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.questionType)
      ..writeByte(2)
      ..write(obj.chapterId)
      ..writeByte(3)
      ..write(obj.examId)
      ..writeByte(4)
      ..write(obj.questionText)
      ..writeByte(5)
      ..write(obj.optionA)
      ..writeByte(6)
      ..write(obj.optionB)
      ..writeByte(7)
      ..write(obj.optionC)
      ..writeByte(8)
      ..write(obj.optionD)
      ..writeByte(9)
      ..write(obj.optionE)
      ..writeByte(10)
      ..write(obj.optionF)
      ..writeByte(11)
      ..write(obj.correctOption)
      ..writeByte(12)
      ..write(obj.explanation)
      ..writeByte(13)
      ..write(obj.difficulty)
      ..writeByte(14)
      ..write(obj.hasAnswer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
