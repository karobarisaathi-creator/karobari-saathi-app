// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppNotificationAdapter extends TypeAdapter<AppNotification> {
  @override
  final int typeId = 5;

  @override
  AppNotification read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppNotification(
      id: fields[0] as String,
      title: fields[1] as String,
      message: fields[2] as String,
      type: fields[3] as NotificationType,
      isRead: fields[4] as bool,
      timestamp: fields[5] as DateTime,
      data: (fields[6] as Map?)?.cast<String, dynamic>(),
      relatedAccountId: fields[7] as String?,
      relatedTransactionId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppNotification obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.message)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.isRead)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.data)
      ..writeByte(7)
      ..write(obj.relatedAccountId)
      ..writeByte(8)
      ..write(obj.relatedTransactionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotificationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationTypeAdapter extends TypeAdapter<NotificationType> {
  @override
  final int typeId = 6;

  @override
  NotificationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NotificationType.transaction;
      case 1:
        return NotificationType.share;
      case 2:
        return NotificationType.reminder;
      case 3:
        return NotificationType.report;
      case 4:
        return NotificationType.general;
      case 5:
        return NotificationType.system;
      case 6:
        return NotificationType.price_drop;
      default:
        return NotificationType.transaction;
    }
  }

  @override
  void write(BinaryWriter writer, NotificationType obj) {
    switch (obj) {
      case NotificationType.transaction:
        writer.writeByte(0);
        break;
      case NotificationType.share:
        writer.writeByte(1);
        break;
      case NotificationType.reminder:
        writer.writeByte(2);
        break;
      case NotificationType.report:
        writer.writeByte(3);
        break;
      case NotificationType.general:
        writer.writeByte(4);
        break;
      case NotificationType.system:
        writer.writeByte(5);
        break;
      case NotificationType.price_drop:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
