// lib/core/models/contract_model.dart

class ContractPayment {
  final String id;
  final double amount;
  final DateTime date;
  final String note;

  const ContractPayment({
    required this.id,
    required this.amount,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory ContractPayment.fromMap(Map<dynamic, dynamic> map) => ContractPayment(
        id: map['id']?.toString() ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        date: map['date'] != null
            ? (DateTime.tryParse(map['date'].toString()) ?? DateTime.now())
            : DateTime.now(),
        note: map['note']?.toString() ?? '',
      );
}

class ContractLaborPayment {
  final String id;
  final String workerName;
  final double amount;
  final DateTime date;
  final String note;
  final String? workerId;
  final String? workerPayrollPaymentId;

  const ContractLaborPayment({
    required this.id,
    required this.workerName,
    required this.amount,
    required this.date,
    required this.note,
    this.workerId,
    this.workerPayrollPaymentId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'workerName': workerName,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'workerId': workerId,
        'workerPayrollPaymentId': workerPayrollPaymentId,
      };

  factory ContractLaborPayment.fromMap(Map<dynamic, dynamic> map) =>
      ContractLaborPayment(
        id: map['id']?.toString() ?? '',
        workerName: map['workerName']?.toString() ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        date: map['date'] != null
            ? (DateTime.tryParse(map['date'].toString()) ?? DateTime.now())
            : DateTime.now(),
        note: map['note']?.toString() ?? '',
        workerId: map['workerId']?.toString(),
        workerPayrollPaymentId: map['workerPayrollPaymentId']?.toString(),
      );
}

class ContractDocument {
  final String id;
  final String ownerId;
  final String storagePath;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final DateTime uploadedAt;

  const ContractDocument({
    required this.id,
    required this.ownerId,
    required this.storagePath,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'storagePath': storagePath,
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': sizeBytes,
        'uploadedAt': uploadedAt.toIso8601String(),
      };

  factory ContractDocument.fromMap(Map<dynamic, dynamic> map) =>
      ContractDocument(
        id: map['id']?.toString() ?? '',
        ownerId: map['ownerId']?.toString() ?? '',
        storagePath: map['storagePath']?.toString() ?? '',
        fileName: map['fileName']?.toString() ?? '',
        contentType: map['contentType']?.toString() ?? '',
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        uploadedAt: map['uploadedAt'] != null
            ? (DateTime.tryParse(map['uploadedAt'].toString()) ??
                DateTime.now())
            : DateTime.now(),
      );
}

class ContractModel {
  final String id;
  final String partyId;
  final String partyName;
  final String title;
  final String description;
  final double totalAmount;
  final bool
      isIncoming; // true = Taking contract (Receivable), false = Giving contract (Payable)
  final DateTime startDate;
  final DateTime? targetDate;
  final String status; // 'active', 'completed'
  final List<ContractPayment> payments;
  final List<ContractLaborPayment> laborPayments;
  final List<ContractDocument> documents;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContractModel({
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.title,
    this.description = '',
    required this.totalAmount,
    this.isIncoming = true,
    required this.startDate,
    this.targetDate,
    this.status = 'active',
    this.payments = const [],
    this.laborPayments = const [],
    this.documents = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalPaid => payments.fold(0.0, (sum, p) => sum + p.amount);

  double get totalLaborPaid =>
      laborPayments.fold(0.0, (sum, p) => sum + p.amount);

  double get remainingBalance =>
      (totalAmount - totalPaid).clamp(0.0, double.infinity).toDouble();

  double get netProfit => isIncoming ? (totalPaid - totalLaborPaid) : 0.0;

  ContractModel copyWith({
    String? partyId,
    String? partyName,
    String? title,
    String? description,
    double? totalAmount,
    bool? isIncoming,
    DateTime? startDate,
    DateTime? targetDate,
    String? status,
    List<ContractPayment>? payments,
    List<ContractLaborPayment>? laborPayments,
    List<ContractDocument>? documents,
    DateTime? updatedAt,
  }) =>
      ContractModel(
        id: id,
        partyId: partyId ?? this.partyId,
        partyName: partyName ?? this.partyName,
        title: title ?? this.title,
        description: description ?? this.description,
        totalAmount: totalAmount ?? this.totalAmount,
        isIncoming: isIncoming ?? this.isIncoming,
        startDate: startDate ?? this.startDate,
        targetDate: targetDate ?? this.targetDate,
        status: status ?? this.status,
        payments: payments ?? this.payments,
        laborPayments: laborPayments ?? this.laborPayments,
        documents: documents ?? this.documents,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'partyId': partyId,
        'partyName': partyName,
        'title': title,
        'description': description,
        'totalAmount': totalAmount,
        'isIncoming': isIncoming,
        'startDate': startDate.toIso8601String(),
        'targetDate': targetDate?.toIso8601String(),
        'status': status,
        'payments': payments.map((p) => p.toMap()).toList(),
        'laborPayments': laborPayments.map((p) => p.toMap()).toList(),
        'documents': documents.map((document) => document.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ContractModel.fromMap(Map<dynamic, dynamic> map) => ContractModel(
        id: map['id']?.toString() ?? '',
        partyId: map['partyId']?.toString() ?? '',
        partyName: map['partyName']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        description: map['description']?.toString() ?? '',
        totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
        isIncoming: map['isIncoming'] == true ||
            map['isIncoming'] == 1 ||
            map['isIncoming'] == 'true',
        startDate: map['startDate'] != null
            ? (DateTime.tryParse(map['startDate'].toString()) ?? DateTime.now())
            : DateTime.now(),
        targetDate: map['targetDate'] != null
            ? DateTime.tryParse(map['targetDate'].toString())
            : null,
        status: map['status']?.toString() ?? 'active',
        payments: (map['payments'] as List<dynamic>? ?? [])
            .map((p) => p is Map ? ContractPayment.fromMap(p) : null)
            .whereType<ContractPayment>()
            .toList(),
        laborPayments: (map['laborPayments'] as List<dynamic>? ?? [])
            .map((p) => p is Map ? ContractLaborPayment.fromMap(p) : null)
            .whereType<ContractLaborPayment>()
            .toList(),
        documents: (map['documents'] as List<dynamic>? ?? [])
            .map((document) =>
                document is Map ? ContractDocument.fromMap(document) : null)
            .whereType<ContractDocument>()
            .toList(),
        createdAt: map['createdAt'] != null
            ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null
            ? (DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now())
            : DateTime.now(),
      );
}
