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
      categories: (fields[7] as List).cast<String>(),
      estimatedBudget: fields[8] as double?,
      deadline: fields[9] as DateTime?,
      images: (fields[10] as List).cast<String>(),
      status: fields[11] as String,
      createdAt: fields[12] as DateTime,
      clarifications: (fields[16] as List).cast<String>(),
      detailedScope: fields[17] as String?,
      scopeOfWork: fields[18] as String?,
      exclusions: fields[19] as String?,
      isComplex: fields[20] as bool?,
      estimatedDays: fields[21] as int?,
      requiresHeightWork: fields[22] as bool?,
      requiresSpecialTools: fields[23] as bool?,
      latitude: fields[24] as double?,
      longitude: fields[25] as double?,
      timeIn: fields[26] as String?,
      timeOut: fields[27] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, JobPost obj) {
    writer
      ..writeByte(26)
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
      ..write(obj.categories)
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
      ..writeByte(15)
      ..write(obj.customerPhotoUrl)
      ..writeByte(16)
      ..write(obj.clarifications)
      ..writeByte(17)
      ..write(obj.detailedScope)
      ..writeByte(18)
      ..write(obj.scopeOfWork)
      ..writeByte(19)
      ..write(obj.exclusions)
      ..writeByte(20)
      ..write(obj.isComplex)
      ..writeByte(21)
      ..write(obj.estimatedDays)
      ..writeByte(22)
      ..write(obj.requiresHeightWork)
      ..writeByte(23)
      ..write(obj.requiresSpecialTools)
      ..writeByte(24)
      ..write(obj.latitude)
      ..writeByte(25)
      ..write(obj.longitude)
      ..writeByte(26)
      ..write(obj.timeIn)
      ..writeByte(27)
      ..write(obj.timeOut);
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
