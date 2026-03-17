// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chatbot_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatbotConversationAdapter extends TypeAdapter<ChatbotConversation> {
  @override
  final int typeId = 13;

  @override
  ChatbotConversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatbotConversation(
      id: fields[0] as int,
      title: fields[1] as String,
      createdAt: fields[2] as DateTime,
      updatedAt: fields[3] as DateTime,
      lastMessage: fields[4] as String?,
      lastMessageRole: fields[5] as String?,
      messageCount: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ChatbotConversation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt)
      ..writeByte(4)
      ..write(obj.lastMessage)
      ..writeByte(5)
      ..write(obj.lastMessageRole)
      ..writeByte(6)
      ..write(obj.messageCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatbotConversationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatbotMessageAdapter extends TypeAdapter<ChatbotMessage> {
  @override
  final int typeId = 14;

  @override
  ChatbotMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatbotMessage(
      id: fields[0] as int,
      role: fields[1] as String,
      content: fields[2] as String,
      timestamp: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChatbotMessage obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatbotMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatbotUsageStatsAdapter extends TypeAdapter<ChatbotUsageStats> {
  @override
  final int typeId = 20;

  @override
  ChatbotUsageStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatbotUsageStats(
      remaining: fields[0] as int,
      limit: fields[1] as int,
      used: fields[2] as int,
      totalMessages: fields[3] as int,
      totalConversations: fields[4] as int,
      weeklyUsage: (fields[5] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatbotUsageStats obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.remaining)
      ..writeByte(1)
      ..write(obj.limit)
      ..writeByte(2)
      ..write(obj.used)
      ..writeByte(3)
      ..write(obj.totalMessages)
      ..writeByte(4)
      ..write(obj.totalConversations)
      ..writeByte(5)
      ..write(obj.weeklyUsage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatbotUsageStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
