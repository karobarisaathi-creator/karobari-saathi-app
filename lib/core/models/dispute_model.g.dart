// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dispute_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DisputeAdapter extends TypeAdapter<Dispute> {
  @override
  final int typeId = 28;

  @override
  Dispute read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dispute(
      id: fields[0] as String,
      workOrderId: fields[1] as String,
      raisedBy: fields[2] as String,
      reason: fields[3] as String,
      description: fields[4] as String,
      status: fields[5] as String,
      createdAt: fields[6] as DateTime,
      resolvedAt: fields[7] as DateTime?,
      resolution: fields[8] as String?,
      messages: (fields[9] as List).cast<DisputeMessage>(),
      attachments: (fields[10] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Dispute obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.workOrderId)
      ..writeByte(2)
      ..write(obj.raisedBy)
      ..writeByte(3)
      ..write(obj.reason)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.resolvedAt)
      ..writeByte(8)
      ..write(obj.resolution)
      ..writeByte(9)
      ..write(obj.messages)
      ..writeByte(10)
      ..write(obj.attachments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisputeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DisputeMessageAdapter extends TypeAdapter<DisputeMessage> {
  @override
  final int typeId = 29;

  @override
  DisputeMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DisputeMessage(
      senderId: fields[0] as String,
      message: fields[1] as String,
      timestamp: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DisputeMessage obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.senderId)
      ..writeByte(1)
      ..write(obj.message)
      ..writeByte(2)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisputeMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
