// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_post_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JobPostAdapter extends TypeAdapter<JobPost> {
  @override
  final int typeId = 31;

  @override
  JobPost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JobPost(
      id: fields[0] as String,
      customerId: fields[1] as String,
      customerName: fields[2] as String,
      customerPhone: fields[3] as String,
      customerPhotoUrl: fields[15] as String?,
      title: fields[4] as String,
      description: fields[5] as String,
      location: fields[6] as String,
      category: fields[7] as String,
      estimatedBudget: fields[8] as double?,
      deadline: fields[9] as DateTime,
      images: (fields[10] as List).cast<String>(),
      status: fields[11] as String,
      createdAt: fields[12] as DateTime,
      selectedBidId: fields[13] as String?,
      bidCount: fields[14] as int,
    );
  }

  @override
  void write(BinaryWriter writer, JobPost obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.customerName)
      ..writeByte(3)
      ..write(obj.customerPhone)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.location)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.estimatedBudget)
      ..writeByte(9)
      ..write(obj.deadline)
      ..writeByte(10)
      ..write(obj.images)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.selectedBidId)
      ..writeByte(14)
      ..write(obj.bidCount)
      ..writeByte(15)
      ..write(obj.customerPhotoUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobPostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
