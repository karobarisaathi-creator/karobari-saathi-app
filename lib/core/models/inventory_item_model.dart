import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'inventory_item_model.g.dart';

@HiveType(typeId: 21)
class InventoryItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String unit;

  @HiveField(3)
  final double defaultRate;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime updatedAt;

  @HiveField(6)
  final String? description;

  @HiveField(7)
  final List<String> imagePaths;

  @HiveField(8)
  final double rating;

  @HiveField(9)
  bool? isFavorite;

  @HiveField(10)
  final String? accountId;

  @HiveField(11)
  final String? category;

  @HiveField(12)
  final String? sku;

  @HiveField(13)
  final double stockQuantity;

  @HiveField(14)
  final String? stockStatus; 

  @HiveField(15)
  int likes;

  @HiveField(16)
  final String? condition; 

  @HiveField(17)
  final String? location; 

  @HiveField(18)
  final bool? isNegotiable;

  @HiveField(19)
  final String? warranty; 

  @HiveField(20)
  final String? brand; 

  // ========== MOBILE SPECIFIC ==========
  @HiveField(21)
  final String? ram;
  @HiveField(22)
  final String? storage;
  @HiveField(23)
  final String? processor;
  @HiveField(24)
  final String? ptaStatus;
  @HiveField(25)
  final String? batteryHealth;
  @HiveField(26)
  final String? screenCondition;
  @HiveField(27)
  final String? bodyCondition;
  @HiveField(28)
  final String? accessories;

  // ========== VEHICLE SPECIFIC ==========
  @HiveField(29)
  final String? engine;
  @HiveField(30)
  final String? mileage;
  @HiveField(31)
  final String? fuelType;
  @HiveField(32)
  final String? transmission;
  @HiveField(33)
  final String? registration;
  @HiveField(34)
  final String? accidentHistory;
  @HiveField(35)
  final String? ownerCount;

  // ========== REAL ESTATE SPECIFIC ==========
  @HiveField(36)
  final String? area;
  @HiveField(37)
  final String? bedrooms;
  @HiveField(38)
  final String? bathrooms;
  @HiveField(39)
  final String? propertyType;

  // ========== LIVESTOCK SPECIFIC ==========
  @HiveField(40)
  final String? breed;
  @HiveField(41)
  final String? age;
  @HiveField(42)
  final String? weight;
  @HiveField(43)
  final String? milkCapacity;
  @HiveField(44)
  final String? vaccination;

  // ========== ELECTRONICS SPECIFIC ==========
  @HiveField(45)
  final String? model;
  @HiveField(46)
  final String? power;
  @HiveField(47)
  final String? warrantyType;

  // ========== CLOTHING SPECIFIC ==========
  @HiveField(48)
  final String? size;
  @HiveField(49)
  final String? fabric;

  // ========== FURNITURE SPECIFIC ==========
  @HiveField(50)
  final String? material;
  @HiveField(51)
  final String? dimensions;
  @HiveField(52)
  final String? assembly;

  // ========== AGRICULTURE SPECIFIC ==========
  @HiveField(53)
  final String? cropType;
  @HiveField(54)
  final String? season;
  @HiveField(55)
  final String? quality;

  // ========== FOOD SPECIFIC ==========
  @HiveField(56)
  final String? foodWeight;
  @HiveField(57)
  final String? expiryDate;
  @HiveField(58)
  final String? storageType;
  @HiveField(59)
  final String? halal;

  // ========== MEDICAL SPECIFIC ==========
  @HiveField(60)
  final String? strength;
  @HiveField(61)
  final String? medicineQuantity;
  @HiveField(62)
  final String? prescriptionRequired;

  // ========== STATIONERY SPECIFIC ==========
  @HiveField(63)
  final String? stationeryMaterial;
  @HiveField(64)
  final String? stationerySize;

  // ========== SERVICES SPECIFIC ==========
  @HiveField(65)
  final String? serviceType;
  @HiveField(66)
  final String? experience;
  @HiveField(67)
  final String? availability;

  // ========== HARDWARE SPECIFIC ==========
  @HiveField(68)
  final String? hardwareMaterial;
  @HiveField(69)
  final String? hardwareSize;

  // ========== CONSTRUCTION SPECIFIC ==========
  @HiveField(70)
  final String? grade;
  @HiveField(71)
  final String? constructionUnit;

  // ========== TRANSPORT SPECIFIC ==========
  @HiveField(72)
  final String? capacity;
  @HiveField(73)
  final String? routes;

  // ========== RAW MATERIAL SPECIFIC ==========
  @HiveField(74)
  final String? origin;
  @HiveField(75)
  final String? specifications;

  // ========== ASSETS SPECIFIC ==========
  @HiveField(76)
  final String? assetModel;
  @HiveField(77)
  final String? serialNumber;
  @HiveField(78)
  final String? depreciation;

  @HiveField(79)
  final double? latitude;

  @HiveField(80)
  final double? longitude;

  @HiveField(81, defaultValue: false)
  final bool isFeatured;

  @HiveField(82, defaultValue: 0)
  int views;

  @HiveField(83, defaultValue: 0)
  int shares;

  @HiveField(84)
  final DateTime? adExpiryDate;

  InventoryItem({
    required this.id, required this.name, required this.unit, required this.defaultRate,
    required this.createdAt, required this.updatedAt, this.description,
    this.imagePaths = const [], this.rating = 0, this.isFavorite = false,
    this.accountId, this.category, this.sku, this.stockQuantity = 0,
    this.stockStatus = 'Full', this.likes = 0, this.condition = 'New',
    this.location = '', this.isNegotiable = false, this.warranty = '', this.brand = '',
    this.ram, this.storage, this.processor, this.ptaStatus, this.batteryHealth,
    this.screenCondition, this.bodyCondition, this.accessories,
    this.engine, this.mileage, this.fuelType, this.transmission, this.registration,
    this.accidentHistory, this.ownerCount,
    this.area, this.bedrooms, this.bathrooms, this.propertyType,
    this.breed, this.age, this.weight, this.milkCapacity, this.vaccination,
    this.model, this.power, this.warrantyType,
    this.size, this.fabric,
    this.material, this.dimensions, this.assembly,
    this.cropType, this.season, this.quality,
    this.foodWeight, this.expiryDate, this.storageType, this.halal,
    this.strength, this.medicineQuantity, this.prescriptionRequired,
    this.stationeryMaterial, this.stationerySize,
    this.serviceType, this.experience, this.availability,
    this.hardwareMaterial, this.hardwareSize,
    this.grade, this.constructionUnit,
    this.capacity, this.routes,
    this.origin, this.specifications,
    this.assetModel, this.serialNumber, this.depreciation,
    this.latitude, this.longitude,
    this.isFeatured = false,
    this.views = 0,
    this.shares = 0,
    this.adExpiryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'name': name, 'unit': unit, 'defaultRate': defaultRate,
      'createdAt': createdAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String(),
      'description': description, 'imagePaths': imagePaths, 'rating': rating,
      'isFavorite': isFavorite, 'accountId': accountId, 'category': category,
      'sku': sku, 'stockQuantity': stockQuantity, 'stockStatus': stockStatus,
      'likes': likes, 'condition': condition, 'location': location,
      'isNegotiable': isNegotiable, 'warranty': warranty, 'brand': brand,
      'ram': ram, 'storage': storage, 'processor': processor, 'ptaStatus': ptaStatus,
      'batteryHealth': batteryHealth, 'screenCondition': screenCondition,
      'bodyCondition': bodyCondition, 'accessories': accessories,
      'engine': engine, 'mileage': mileage, 'fuelType': fuelType,
      'transmission': transmission, 'registration': registration,
      'accidentHistory': accidentHistory, 'ownerCount': ownerCount,
      'area': area, 'bedrooms': bedrooms, 'bathrooms': bathrooms, 'propertyType': propertyType,
      'breed': breed, 'age': age, 'weight': weight, 'milkCapacity': milkCapacity, 'vaccination': vaccination,
      'model': model, 'power': power, 'warrantyType': warrantyType,
      'size': size, 'fabric': fabric, 'material': material, 'dimensions': dimensions, 'assembly': assembly,
      'cropType': cropType, 'season': season, 'quality': quality,
      'foodWeight': foodWeight, 'expiryDate': expiryDate, 'storageType': storageType, 'halal': halal,
      'strength': strength, 'medicineQuantity': medicineQuantity, 'prescriptionRequired': prescriptionRequired,
      'stationeryMaterial': stationeryMaterial, 'stationerySize': stationerySize,
      'serviceType': serviceType, 'experience': experience, 'availability': availability,
      'hardwareMaterial': hardwareMaterial, 'hardwareSize': hardwareSize,
      'grade': grade, 'constructionUnit': constructionUnit,
      'capacity': capacity, 'routes': routes,
      'origin': origin, 'specifications': specifications,
      'assetModel': assetModel, 'serialNumber': serialNumber, 'depreciation': depreciation,
      'latitude': latitude, 'longitude': longitude,
      'isFeatured': isFeatured,
      'views': views,
      'shares': shares,
      'adExpiryDate': adExpiryDate?.toIso8601String(),
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic d) => d is Timestamp ? d.toDate() : DateTime.tryParse(d?.toString() ?? '') ?? DateTime.now();
    return InventoryItem(
      id: map['id']?.toString() ?? '', name: map['name']?.toString() ?? '', unit: map['unit']?.toString() ?? '',
      defaultRate: (map['defaultRate'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate(map['createdAt']), updatedAt: parseDate(map['updatedAt']),
      description: map['description']?.toString(), imagePaths: List<String>.from(map['imagePaths'] ?? []),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0, isFavorite: map['isFavorite'] ?? false,
      accountId: map['accountId'], category: map['category'], sku: map['sku'],
      stockQuantity: (map['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      stockStatus: map['stockStatus'] ?? 'Full', likes: map['likes']?.toInt() ?? 0,
      condition: map['condition'], location: map['location'], isNegotiable: map['isNegotiable'] ?? false,
      warranty: map['warranty'], brand: map['brand'],
      ram: map['ram'], storage: map['storage'], processor: map['processor'], ptaStatus: map['ptaStatus'],
      batteryHealth: map['batteryHealth'], screenCondition: map['screenCondition'],
      bodyCondition: map['bodyCondition'], accessories: map['accessories'],
      engine: map['engine'], mileage: map['mileage'], fuelType: map['fuelType'],
      transmission: map['transmission'], registration: map['registration'],
      accidentHistory: map['accidentHistory'], ownerCount: map['ownerCount'],
      area: map['area'], bedrooms: map['bedrooms'], bathrooms: map['bathrooms'], propertyType: map['propertyType'],
      breed: map['breed'], age: map['age'], weight: map['weight'], milkCapacity: map['milkCapacity'], vaccination: map['vaccination'],
      model: map['model'], power: map['power'], warrantyType: map['warrantyType'],
      size: map['size'], fabric: map['fabric'], material: map['material'], dimensions: map['dimensions'], assembly: map['assembly'],
      cropType: map['cropType'], season: map['season'], quality: map['quality'],
      foodWeight: map['foodWeight'], expiryDate: map['expiryDate'], storageType: map['storageType'], halal: map['halal'],
      strength: map['strength'], medicineQuantity: map['medicineQuantity'], prescriptionRequired: map['prescriptionRequired'],
      stationeryMaterial: map['stationeryMaterial'], stationerySize: map['stationerySize'],
      serviceType: map['serviceType'], experience: map['experience'], availability: map['availability'],
      hardwareMaterial: map['hardwareMaterial'], hardwareSize: map['hardwareSize'],
      grade: map['grade'], constructionUnit: map['constructionUnit'],
      capacity: map['capacity'], routes: map['routes'],
      origin: map['origin'], specifications: map['specifications'],
      assetModel: map['assetModel'], serialNumber: map['serialNumber'], depreciation: map['depreciation'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isFeatured: map['isFeatured'] ?? false,
      views: map['views']?.toInt() ?? 0,
      shares: map['shares']?.toInt() ?? 0,
      adExpiryDate: map['adExpiryDate'] != null ? parseDate(map['adExpiryDate']) : null,
    );
  }
}
