// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VideoQualityAdapter extends TypeAdapter<VideoQuality> {
  @override
  final int typeId = 4;

  @override
  VideoQuality read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VideoQuality(
      label: fields[0] as String,
      url: fields[1] as String,
      height: fields[2] as int,
      isAvailable: fields[3] as bool,
      estimatedSize: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, VideoQuality obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.label)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.height)
      ..writeByte(3)
      ..write(obj.isAvailable)
      ..writeByte(4)
      ..write(obj.estimatedSize);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoQualityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VideoAdapter extends TypeAdapter<Video> {
  @override
  final int typeId = 4;

  @override
  Video read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Video(
      id: fields[0] as int,
      title: fields[1] as String,
      chapterId: fields[2] as int,
      filePath: fields[3] as String,
      fileSize: fields[4] as int,
      duration: fields[5] as int,
      thumbnailUrl: fields[6] as String?,
      releaseDate: fields[7] as DateTime?,
      viewCount: fields[8] as int,
      createdAt: fields[9] as DateTime,
      qualities: (fields[10] as Map?)?.cast<String, VideoQuality>(),
      hasQualities: fields[11] as bool,
      processingStatus: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Video obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.chapterId)
      ..writeByte(3)
      ..write(obj.filePath)
      ..writeByte(4)
      ..write(obj.fileSize)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.thumbnailUrl)
      ..writeByte(7)
      ..write(obj.releaseDate)
      ..writeByte(8)
      ..write(obj.viewCount)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.qualities)
      ..writeByte(11)
      ..write(obj.hasQualities)
      ..writeByte(12)
      ..write(obj.processingStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
