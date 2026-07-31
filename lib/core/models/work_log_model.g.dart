// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkLogAdapter extends TypeAdapter<WorkLog> {
  @override
  final int typeId = 25;

  @override
  WorkLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkLog(
      id: fields[0] as String,
      accountId: fields[1] as String,
      professionId: fields[2] as String?,
      description: fields[3] as String,
      quantity: fields[4] as double,
      multiplier: fields[5] as int,
      rate: fields[6] as double,
      totalAmount: fields[7] as double,
      date: fields[8] as DateTime,
      unitName: fields[9] as String,
      accountName: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkLog obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.accountId)
      ..writeByte(2)
      ..write(obj.professionId)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.multiplier)
      ..writeByte(6)
      ..write(obj.rate)
      ..writeByte(7)
      ..write(obj.totalAmount)
      ..writeByte(8)
      ..write(obj.date)
      ..writeByte(9)
      ..write(obj.unitName)
      ..writeByte(10)
      ..write(obj.accountName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
