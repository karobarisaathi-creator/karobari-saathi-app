// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryItemAdapter extends TypeAdapter<InventoryItem> {
  @override
  final int typeId = 21;

  @override
  InventoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryItem(
      id: fields[0] as String,
      name: fields[1] as String,
      unit: fields[2] as String,
      defaultRate: fields[3] as double,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      description: fields[6] as String?,
      imagePaths: (fields[7] as List).cast<String>(),
      rating: fields[8] as double,
      isFavorite: fields[9] as bool,
      accountId: fields[10] as String?,
      category: fields[11] as String?,
      sku: fields[12] as String?,
      stockQuantity: fields[13] as double,
      stockStatus: fields[14] as String?,
      likes: fields[15] as int,
      condition: fields[16] as String?,
      location: fields[17] as String?,
      isNegotiable: fields[18] as bool,
      warranty: fields[19] as String?,
      brand: fields[20] as String?,
      ram: fields[21] as String?,
      storage: fields[22] as String?,
      processor: fields[23] as String?,
      ptaStatus: fields[24] as String?,
      batteryHealth: fields[25] as String?,
      screenCondition: fields[26] as String?,
      bodyCondition: fields[27] as String?,
      accessories: fields[28] as String?,
      engine: fields[29] as String?,
      mileage: fields[30] as String?,
      fuelType: fields[31] as String?,
      transmission: fields[32] as String?,
      registration: fields[33] as String?,
      accidentHistory: fields[34] as String?,
      ownerCount: fields[35] as String?,
      area: fields[36] as String?,
      bedrooms: fields[37] as String?,
      bathrooms: fields[38] as String?,
      propertyType: fields[39] as String?,
      breed: fields[40] as String?,
      age: fields[41] as String?,
      weight: fields[42] as String?,
      milkCapacity: fields[43] as String?,
      vaccination: fields[44] as String?,
      model: fields[45] as String?,
      power: fields[46] as String?,
      warrantyType: fields[47] as String?,
      size: fields[48] as String?,
      fabric: fields[49] as String?,
      material: fields[50] as String?,
      dimensions: fields[51] as String?,
      assembly: fields[52] as String?,
      cropType: fields[53] as String?,
      season: fields[54] as String?,
      quality: fields[55] as String?,
      foodWeight: fields[56] as String?,
      expiryDate: fields[57] as String?,
      storageType: fields[58] as String?,
      halal: fields[59] as String?,
      strength: fields[60] as String?,
      medicineQuantity: fields[61] as String?,
      prescriptionRequired: fields[62] as String?,
      stationeryMaterial: fields[63] as String?,
      stationerySize: fields[64] as String?,
      serviceType: fields[65] as String?,
      experience: fields[66] as String?,
      availability: fields[67] as String?,
      hardwareMaterial: fields[68] as String?,
      hardwareSize: fields[69] as String?,
      grade: fields[70] as String?,
      constructionUnit: fields[71] as String?,
      capacity: fields[72] as String?,
      routes: fields[73] as String?,
      origin: fields[74] as String?,
      specifications: fields[75] as String?,
      assetModel: fields[76] as String?,
      serialNumber: fields[77] as String?,
      depreciation: fields[78] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryItem obj) {
    writer
      ..writeByte(79)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.defaultRate)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.imagePaths)
      ..writeByte(8)
      ..write(obj.rating)
      ..writeByte(9)
      ..write(obj.isFavorite)
      ..writeByte(10)
      ..write(obj.accountId)
      ..writeByte(11)
      ..write(obj.category)
      ..writeByte(12)
      ..write(obj.sku)
      ..writeByte(13)
      ..write(obj.stockQuantity)
      ..writeByte(14)
      ..write(obj.stockStatus)
      ..writeByte(15)
      ..write(obj.likes)
      ..writeByte(16)
      ..write(obj.condition)
      ..writeByte(17)
      ..write(obj.location)
      ..writeByte(18)
      ..write(obj.isNegotiable)
      ..writeByte(19)
      ..write(obj.warranty)
      ..writeByte(20)
      ..write(obj.brand)
      ..writeByte(21)
      ..write(obj.ram)
      ..writeByte(22)
      ..write(obj.storage)
      ..writeByte(23)
      ..write(obj.processor)
      ..writeByte(24)
      ..write(obj.ptaStatus)
      ..writeByte(25)
      ..write(obj.batteryHealth)
      ..writeByte(26)
      ..write(obj.screenCondition)
      ..writeByte(27)
      ..write(obj.bodyCondition)
      ..writeByte(28)
      ..write(obj.accessories)
      ..writeByte(29)
      ..write(obj.engine)
      ..writeByte(30)
      ..write(obj.mileage)
      ..writeByte(31)
      ..write(obj.fuelType)
      ..writeByte(32)
      ..write(obj.transmission)
      ..writeByte(33)
      ..write(obj.registration)
      ..writeByte(34)
      ..write(obj.accidentHistory)
      ..writeByte(35)
      ..write(obj.ownerCount)
      ..writeByte(36)
      ..write(obj.area)
      ..writeByte(37)
      ..write(obj.bedrooms)
      ..writeByte(38)
      ..write(obj.bathrooms)
      ..writeByte(39)
      ..write(obj.propertyType)
      ..writeByte(40)
      ..write(obj.breed)
      ..writeByte(41)
      ..write(obj.age)
      ..writeByte(42)
      ..write(obj.weight)
      ..writeByte(43)
      ..write(obj.milkCapacity)
      ..writeByte(44)
      ..write(obj.vaccination)
      ..writeByte(45)
      ..write(obj.model)
      ..writeByte(46)
      ..write(obj.power)
      ..writeByte(47)
      ..write(obj.warrantyType)
      ..writeByte(48)
      ..write(obj.size)
      ..writeByte(49)
      ..write(obj.fabric)
      ..writeByte(50)
      ..write(obj.material)
      ..writeByte(51)
      ..write(obj.dimensions)
      ..writeByte(52)
      ..write(obj.assembly)
      ..writeByte(53)
      ..write(obj.cropType)
      ..writeByte(54)
      ..write(obj.season)
      ..writeByte(55)
      ..write(obj.quality)
      ..writeByte(56)
      ..write(obj.foodWeight)
      ..writeByte(57)
      ..write(obj.expiryDate)
      ..writeByte(58)
      ..write(obj.storageType)
      ..writeByte(59)
      ..write(obj.halal)
      ..writeByte(60)
      ..write(obj.strength)
      ..writeByte(61)
      ..write(obj.medicineQuantity)
      ..writeByte(62)
      ..write(obj.prescriptionRequired)
      ..writeByte(63)
      ..write(obj.stationeryMaterial)
      ..writeByte(64)
      ..write(obj.stationerySize)
      ..writeByte(65)
      ..write(obj.serviceType)
      ..writeByte(66)
      ..write(obj.experience)
      ..writeByte(67)
      ..write(obj.availability)
      ..writeByte(68)
      ..write(obj.hardwareMaterial)
      ..writeByte(69)
      ..write(obj.hardwareSize)
      ..writeByte(70)
      ..write(obj.grade)
      ..writeByte(71)
      ..write(obj.constructionUnit)
      ..writeByte(72)
      ..write(obj.capacity)
      ..writeByte(73)
      ..write(obj.routes)
      ..writeByte(74)
      ..write(obj.origin)
      ..writeByte(75)
      ..write(obj.specifications)
      ..writeByte(76)
      ..write(obj.assetModel)
      ..writeByte(77)
      ..write(obj.serialNumber)
      ..writeByte(78)
      ..write(obj.depreciation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
