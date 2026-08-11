// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artisan_profile_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArtisanProfileAdapter extends TypeAdapter<ArtisanProfile> {
  @override
  final int typeId = 26;

  @override
  ArtisanProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArtisanProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      profession: fields[2] as String,
      professionUrdu: fields[3] as String,
      location: fields[4] as String,
      latitude: fields[5] as double?,
      longitude: fields[6] as double?,
      experience: fields[7] as int,
      rate: fields[8] as String?,
      availability: fields[9] as String,
      phone: fields[10] as String,
      showPhone: fields[11] as bool,
      description: fields[12] as String,
      profileImage: fields[13] as String?,
      workImages: (fields[14] as List).cast<String>(),
      rating: fields[15] as double,
      totalReviews: fields[16] as int,
      isVerified: fields[17] as bool,
      verificationStatus: fields[18] as String,
      isActive: fields[19] as bool,
      createdAt: fields[20] as DateTime,
      updatedAt: fields[21] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ArtisanProfile obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.profession)
      ..writeByte(3)
      ..write(obj.professionUrdu)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.latitude)
      ..writeByte(6)
      ..write(obj.longitude)
      ..writeByte(7)
      ..write(obj.experience)
      ..writeByte(8)
      ..write(obj.rate)
      ..writeByte(9)
      ..write(obj.availability)
      ..writeByte(10)
      ..write(obj.phone)
      ..writeByte(11)
      ..write(obj.showPhone)
      ..writeByte(12)
      ..write(obj.description)
      ..writeByte(13)
      ..write(obj.profileImage)
      ..writeByte(14)
      ..write(obj.workImages)
      ..writeByte(15)
      ..write(obj.rating)
      ..writeByte(16)
      ..write(obj.totalReviews)
      ..writeByte(17)
      ..write(obj.isVerified)
      ..writeByte(18)
      ..write(obj.verificationStatus)
      ..writeByte(19)
      ..write(obj.isActive)
      ..writeByte(20)
      ..write(obj.createdAt)
      ..writeByte(21)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtisanProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
