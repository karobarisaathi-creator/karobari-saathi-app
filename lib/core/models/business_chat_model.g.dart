// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_chat_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BusinessChatMessageAdapter extends TypeAdapter<BusinessChatMessage> {
  @override
  final int typeId = 35;

  @override
  BusinessChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessChatMessage(
      id: fields[0] as String,
      senderId: fields[1] as String,
      receiverId: fields[2] as String,
      message: fields[3] as String,
      messageType: fields[4] as String,
      fileUrl: fields[5] as String?,
      fileName: fields[6] as String?,
      fileSize: fields[7] as String?,
      isRead: fields[8] as bool,
      isDelivered: fields[9] as bool,
      timestamp: fields[10] as DateTime,
      editedAt: fields[11] as DateTime?,
      orderId: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessChatMessage obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.senderId)
      ..writeByte(2)
      ..write(obj.receiverId)
      ..writeByte(3)
      ..write(obj.message)
      ..writeByte(4)
      ..write(obj.messageType)
      ..writeByte(5)
      ..write(obj.fileUrl)
      ..writeByte(6)
      ..write(obj.fileName)
      ..writeByte(7)
      ..write(obj.fileSize)
      ..writeByte(8)
      ..write(obj.isRead)
      ..writeByte(9)
      ..write(obj.isDelivered)
      ..writeByte(10)
      ..write(obj.timestamp)
      ..writeByte(11)
      ..write(obj.editedAt)
      ..writeByte(12)
      ..write(obj.orderId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BusinessChatRoomAdapter extends TypeAdapter<BusinessChatRoom> {
  @override
  final int typeId = 36;

  @override
  BusinessChatRoom read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessChatRoom(
      id: fields[0] as String,
      participants: (fields[1] as List).cast<String>(),
      lastMessage: fields[2] as String?,
      lastMessageTime: fields[3] as DateTime?,
      lastSenderId: fields[4] as String?,
      unreadCount: fields[5] as int,
      isActive: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessChatRoom obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.participants)
      ..writeByte(2)
      ..write(obj.lastMessage)
      ..writeByte(3)
      ..write(obj.lastMessageTime)
      ..writeByte(4)
      ..write(obj.lastSenderId)
      ..writeByte(5)
      ..write(obj.unreadCount)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessChatRoomAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
