// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_account_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SharedAccountAdapter extends TypeAdapter<SharedAccount> {
  @override
  final int typeId = 7;

  @override
  SharedAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SharedAccount(
      id: fields[0] as String,
      accountId: fields[1] as String,
      ownerId: fields[2] as String,
      sharedWith: fields[3] as String,
      sharedWithPhone: fields[4] as String,
      permissions: (fields[5] as List).cast<String>(),
      sharedAt: fields[6] as DateTime,
      isActive: fields[7] as bool,
      accountName: fields[8] as String?,
      currentBalance: fields[9] as double?,
      lastViewedAt: fields[10] as DateTime?,
      photoUrl: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SharedAccount obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.accountId)
      ..writeByte(2)
      ..write(obj.ownerId)
      ..writeByte(3)
      ..write(obj.sharedWith)
      ..writeByte(4)
      ..write(obj.sharedWithPhone)
      ..writeByte(5)
      ..write(obj.permissions)
      ..writeByte(6)
      ..write(obj.sharedAt)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.accountName)
      ..writeByte(9)
      ..write(obj.currentBalance)
      ..writeByte(10)
      ..write(obj.lastViewedAt)
      ..writeByte(11)
      ..write(obj.photoUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
