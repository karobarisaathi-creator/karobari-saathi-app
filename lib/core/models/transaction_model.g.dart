// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 1;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      accountId: fields[1] as String,
      amount: fields[2] as double,
      type: fields[3] as String,
      category: fields[4] as String,
      description: fields[5] as String,
      date: fields[6] as DateTime,
      billImage: fields[7] as String?,
      quantity: fields[8] as int,
      rate: fields[9] as double,
      receivedAmount: fields[10] as double,
      pendingAmount: fields[11] as double,
      referenceNumber: fields[12] as String?,
      paymentMethod: fields[13] as String,
      isPending: fields[14] as bool,
      createdAt: fields[15] as DateTime,
      updatedAt: fields[16] as DateTime,
      professionId: fields[17] as String?,
      professionName: fields[18] as String?,
      partnershipId: fields[19] as String?,
      voiceNote: fields[20] as String?,
      items: (fields[21] as List).cast<TransactionItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.accountId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.billImage)
      ..writeByte(8)
      ..write(obj.quantity)
      ..writeByte(9)
      ..write(obj.rate)
      ..writeByte(10)
      ..write(obj.receivedAmount)
      ..writeByte(11)
      ..write(obj.pendingAmount)
      ..writeByte(12)
      ..write(obj.referenceNumber)
      ..writeByte(13)
      ..write(obj.paymentMethod)
      ..writeByte(14)
      ..write(obj.isPending)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.updatedAt)
      ..writeByte(17)
      ..write(obj.professionId)
      ..writeByte(18)
      ..write(obj.professionName)
      ..writeByte(19)
      ..write(obj.partnershipId)
      ..writeByte(20)
      ..write(obj.voiceNote)
      ..writeByte(21)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
