// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artisan_work_order_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArtisanWorkOrderAdapter extends TypeAdapter<ArtisanWorkOrder> {
  @override
  final int typeId = 27;

  @override
  ArtisanWorkOrder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArtisanWorkOrder(
      id: fields[0] as String,
      artisanId: fields[1] as String,
      customerId: fields[2] as String,
      customerName: fields[3] as String,
      customerPhone: fields[4] as String,
      workDescription: fields[5] as String,
      workImages: fields[6] as String?,
      status: fields[7] as String,
      createdAt: fields[8] as DateTime,
      completedAt: fields[9] as DateTime?,
      ratedAt: fields[10] as DateTime?,
      rating: fields[11] as double?,
      review: fields[12] as String?,
      amount: fields[13] as double?,
      location: fields[14] as String?,
      isRated: fields[15] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ArtisanWorkOrder obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.artisanId)
      ..writeByte(2)
      ..write(obj.customerId)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.customerPhone)
      ..writeByte(5)
      ..write(obj.workDescription)
      ..writeByte(6)
      ..write(obj.workImages)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.completedAt)
      ..writeByte(10)
      ..write(obj.ratedAt)
      ..writeByte(11)
      ..write(obj.rating)
      ..writeByte(12)
      ..write(obj.review)
      ..writeByte(13)
      ..write(obj.amount)
      ..writeByte(14)
      ..write(obj.location)
      ..writeByte(15)
      ..write(obj.isRated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtisanWorkOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
