// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = 0;

  @override
  Account read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Account(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String,
      address: fields[3] as String?,
      category: fields[4] as String,
      initialBalance: fields[5] as double,
      balanceType: fields[6] as String,
      balance: fields[7] as double,
      isShared: fields[8] == null ? false : fields[8] as bool,
      sharedWith: (fields[9] as List).cast<String>(),
      profileImage: fields[10] as String?,
      createdAt: fields[11] as DateTime,
      updatedAt: fields[12] as DateTime,
      isActive: fields[13] == null ? true : fields[13] as bool,
      isVerified: fields[14] == null ? false : fields[14] as bool,
      storeName: fields[15] as String?,
      storeImage: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.initialBalance)
      ..writeByte(6)
      ..write(obj.balanceType)
      ..writeByte(7)
      ..write(obj.balance)
      ..writeByte(8)
      ..write(obj.isShared)
      ..writeByte(9)
      ..write(obj.sharedWith)
      ..writeByte(10)
      ..write(obj.profileImage)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.isActive)
      ..writeByte(14)
      ..write(obj.isVerified)
      ..writeByte(15)
      ..write(obj.storeName)
      ..writeByte(16)
      ..write(obj.storeImage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
