// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profession_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfessionAdapter extends TypeAdapter<Profession> {
  @override
  final int typeId = 4;

  @override
  Profession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Profession(
      id: fields[0] as String,
      name: fields[1] as String,
      categories: (fields[2] as List).cast<String>(),
      isActive: fields[3] as bool,
      totalIncome: fields[4] as double,
      totalExpense: fields[5] as double,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
      description: fields[8] as String?,
      totalProduction: fields[9] as double,
      productionUnit: fields[10] as String,
      season: fields[11] as String,
      targetProduction: fields[12] as double,
      budgetLimits: (fields[13] as Map?)?.cast<String, double>(),
      seasonKey: fields[14] as String,
      benchmarkCostPerUnit: fields[15] as double,
      categoryType: fields[16] as ProfessionCategory,
      customMetrics: (fields[17] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Profession obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.categories)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.totalIncome)
      ..writeByte(5)
      ..write(obj.totalExpense)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.description)
      ..writeByte(9)
      ..write(obj.totalProduction)
      ..writeByte(10)
      ..write(obj.productionUnit)
      ..writeByte(11)
      ..write(obj.season)
      ..writeByte(12)
      ..write(obj.targetProduction)
      ..writeByte(13)
      ..write(obj.budgetLimits)
      ..writeByte(14)
      ..write(obj.seasonKey)
      ..writeByte(15)
      ..write(obj.benchmarkCostPerUnit)
      ..writeByte(16)
      ..write(obj.categoryType)
      ..writeByte(17)
      ..write(obj.customMetrics);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProfessionCategoryAdapter extends TypeAdapter<ProfessionCategory> {
  @override
  final int typeId = 10;

  @override
  ProfessionCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ProfessionCategory.agriculture;
      case 1:
        return ProfessionCategory.manufacturing;
      case 2:
        return ProfessionCategory.services;
      case 3:
        return ProfessionCategory.retail;
      case 4:
        return ProfessionCategory.construction;
      case 5:
        return ProfessionCategory.education;
      case 6:
        return ProfessionCategory.healthcare;
      case 7:
        return ProfessionCategory.transportation;
      case 8:
        return ProfessionCategory.technology;
      case 9:
        return ProfessionCategory.general;
      default:
        return ProfessionCategory.agriculture;
    }
  }

  @override
  void write(BinaryWriter writer, ProfessionCategory obj) {
    switch (obj) {
      case ProfessionCategory.agriculture:
        writer.writeByte(0);
        break;
      case ProfessionCategory.manufacturing:
        writer.writeByte(1);
        break;
      case ProfessionCategory.services:
        writer.writeByte(2);
        break;
      case ProfessionCategory.retail:
        writer.writeByte(3);
        break;
      case ProfessionCategory.construction:
        writer.writeByte(4);
        break;
      case ProfessionCategory.education:
        writer.writeByte(5);
        break;
      case ProfessionCategory.healthcare:
        writer.writeByte(6);
        break;
      case ProfessionCategory.transportation:
        writer.writeByte(7);
        break;
      case ProfessionCategory.technology:
        writer.writeByte(8);
        break;
      case ProfessionCategory.general:
        writer.writeByte(9);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessionCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
