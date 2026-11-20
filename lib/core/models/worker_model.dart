// lib/core/models/worker_model.dart

class WorkerModel {
  final String id;
  final String name;
  final String phone;
  final String skill;
  final DateTime createdAt;

  WorkerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.skill,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'skill': skill,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WorkerModel.fromMap(Map<dynamic, dynamic> map) {
    return WorkerModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      skill: map['skill']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  WorkerModel copyWith({
    String? name,
    String? phone,
    String? skill,
  }) {
    return WorkerModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      skill: skill ?? this.skill,
      createdAt: createdAt,
    );
  }
}
