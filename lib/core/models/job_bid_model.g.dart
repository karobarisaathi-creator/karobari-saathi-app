// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_bid_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JobBidAdapter extends TypeAdapter<JobBid> {
  @override
  final int typeId = 32;

  @override
  JobBid read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JobBid(
      id: fields[0] as String,
      jobId: fields[1] as String,
      artisanId: fields[2] as String,
      artisanName: fields[3] as String,
      artisanPhone: fields[4] as String,
      amount: fields[5] as double,
      message: fields[6] as String,
      estimatedDays: fields[7] as int,
      createdAt: fields[8] as DateTime,
      status: fields[9] as String,
      artisanRating: fields[10] as double,
      artisanExperience: fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, JobBid obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.jobId)
      ..writeByte(2)
      ..write(obj.artisanId)
      ..writeByte(3)
      ..write(obj.artisanName)
      ..writeByte(4)
      ..write(obj.artisanPhone)
      ..writeByte(5)
      ..write(obj.amount)
      ..writeByte(6)
      ..write(obj.message)
      ..writeByte(7)
      ..write(obj.estimatedDays)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.artisanRating)
      ..writeByte(11)
      ..write(obj.artisanExperience);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobBidAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
