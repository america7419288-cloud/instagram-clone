// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final typeId = 1;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      id: fields[0] as String,
      conversationId: fields[1] as String,
      senderId: fields[2] as String,
      content: fields[3] as String,
      messageType: fields[4] == null ? 'text' : fields[4] as String,
      createdAt: fields[5] as DateTime,
      isRead: fields[6] == null ? false : fields[6] as bool,
      isDeleted: fields[7] == null ? false : fields[7] as bool,
      mediaUrl: fields[8] as String?,
      sender: fields[9] as ChatUser?,
      isSending: fields[10] == null ? false : fields[10] as bool,
      hasError: fields[11] == null ? false : fields[11] as bool,
      tempId: fields[12] as String?,
      postId: fields[13] as String?,
      reelId: fields[14] as String?,
      storyId: fields[15] as String?,
      reactions: (fields[16] as Map?)?.cast<String, int>(),
      replyToId: fields[17] as String?,
      replyToMessage: fields[18] as Message?,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.messageType)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.isRead)
      ..writeByte(7)
      ..write(obj.isDeleted)
      ..writeByte(8)
      ..write(obj.mediaUrl)
      ..writeByte(9)
      ..write(obj.sender)
      ..writeByte(10)
      ..write(obj.isSending)
      ..writeByte(11)
      ..write(obj.hasError)
      ..writeByte(12)
      ..write(obj.tempId)
      ..writeByte(13)
      ..write(obj.postId)
      ..writeByte(14)
      ..write(obj.reelId)
      ..writeByte(15)
      ..write(obj.storyId)
      ..writeByte(16)
      ..write(obj.reactions)
      ..writeByte(17)
      ..write(obj.replyToId)
      ..writeByte(18)
      ..write(obj.replyToMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
