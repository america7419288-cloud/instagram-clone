// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatUserAdapter extends TypeAdapter<ChatUser> {
  @override
  final typeId = 0;

  @override
  ChatUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatUser(
      id: fields[0] as String,
      username: fields[1] as String,
      fullName: fields[2] as String?,
      profilePicUrl: fields[3] as String?,
      isVerified: fields[4] == null ? false : fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChatUser obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.fullName)
      ..writeByte(3)
      ..write(obj.profilePicUrl)
      ..writeByte(4)
      ..write(obj.isVerified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
