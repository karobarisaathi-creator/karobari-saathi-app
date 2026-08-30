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
      artisanName: fields[26] as String?,
      customerId: fields[2] as String,
      customerName: fields[3] as String,
      customerPhone: fields[4] as String,
      workDescription: fields[5] as String,
      workImages: (fields[6] as List?)?.cast<String>(),
      status: fields[7] as String,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[29] as DateTime?,
      completedAt: fields[9] as DateTime?,
      ratedAt: fields[10] as DateTime?,
      rating: fields[11] as double?,
      review: fields[12] as String?,
      amount: fields[13] as double?,
      location: fields[14] as String?,
      isRated: fields[15] as bool,
      customerAgreed: fields[16] as bool,
      artisanAgreed: fields[17] as bool,
      agreedAt: fields[18] as DateTime?,
      contractTerms: fields[19] as String?,
      paymentTerms: fields[20] as String?,
      cancellationPolicy: fields[21] as String?,
      customerAcceptedTerms: fields[22] as bool,
      artisanAcceptedTerms: fields[23] as bool,
      disputeStatus: fields[24] as String?,
      lockedScope: fields[25] as String?,
      lastMessageSenderId: fields[27] as String?,
      isLastMessageRead: fields[28] as bool,
      items: (fields[30] as List?)?.cast<TransactionItem>(),
      laborFee: fields[31] as double,
      title: fields[32] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ArtisanWorkOrder obj) {
    writer
      ..writeByte(33)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(32)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.artisanId)
      ..writeByte(26)
      ..write(obj.artisanName)
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
      ..writeByte(29)
      ..write(obj.updatedAt)
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
      ..write(obj.isRated)
      ..writeByte(16)
      ..write(obj.customerAgreed)
      ..writeByte(17)
      ..write(obj.artisanAgreed)
      ..writeByte(18)
      ..write(obj.agreedAt)
      ..writeByte(19)
      ..write(obj.contractTerms)
      ..writeByte(20)
      ..write(obj.paymentTerms)
      ..writeByte(21)
      ..write(obj.cancellationPolicy)
      ..writeByte(22)
      ..write(obj.customerAcceptedTerms)
      ..writeByte(23)
      ..write(obj.artisanAcceptedTerms)
      ..writeByte(24)
      ..write(obj.disputeStatus)
      ..writeByte(25)
      ..write(obj.lockedScope)
      ..writeByte(27)
      ..write(obj.lastMessageSenderId)
      ..writeByte(28)
      ..write(obj.isLastMessageRead)
      ..writeByte(30)
      ..write(obj.items)
      ..writeByte(31)
      ..write(obj.laborFee);
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
