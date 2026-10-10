import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/models/transaction_item_model.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String accountId;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final String category;

  @HiveField(5)
  final String description;

  @HiveField(6)
  final DateTime date;

  @HiveField(7)
  final String? billImage;

  @HiveField(8)
  final int quantity;

  @HiveField(9)
  final double rate;

  @HiveField(10)
  final double receivedAmount;

  @HiveField(11)
  final double pendingAmount;

  @HiveField(12)
  final String? referenceNumber;

  @HiveField(13)
  final String paymentMethod;

  @HiveField(14)
  final bool isPending;

  @HiveField(15)
  final DateTime createdAt;

  @HiveField(16)
  final DateTime updatedAt;

  @HiveField(17)
  final String? professionId;

  @HiveField(18)
  final String? professionName;

  @HiveField(19)
  final String? partnershipId;

  @HiveField(20)
  final String? voiceNote;

  @HiveField(21)
  final List<TransactionItem> items;

  @HiveField(22)
  final double subtotal;

  @HiveField(23, defaultValue: 0.0)
  final double discountAmount;

  @HiveField(24)
  final double? discountPercent;

  @HiveField(25)
  final String? discountReason;

  Transaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.date,
    this.billImage,
    this.quantity = 1,
    this.rate = 0.0,
    this.receivedAmount = 0.0,
    this.pendingAmount = 0.0,
    this.referenceNumber,
    this.paymentMethod = 'cash',
    this.isPending = false,
    required this.createdAt,
    required this.updatedAt,
    this.professionId,
    this.professionName,
    this.partnershipId,
    this.voiceNote,
    this.items = const [],
    double? subtotal,
    this.discountAmount = 0.0,
    this.discountPercent,
    this.discountReason,
  }) : subtotal = subtotal ?? amount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'amount': amount,
      'type': type,
      'category': category,
      'description': description,
      'date': date.toIso8601String(),
      'billImage': billImage,
      'quantity': quantity,
      'rate': rate,
      'receivedAmount': receivedAmount,
      'pendingAmount': pendingAmount,
      'referenceNumber': referenceNumber,
      'paymentMethod': paymentMethod,
      'isPending': isPending,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'professionId': professionId,
      'professionName': professionName,
      'partnershipId': partnershipId,
      'voiceNote': voiceNote,
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'discountPercent': discountPercent,
      'discountReason': discountReason,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic dateVal) {
      if (dateVal == null) return DateTime.now();
      if (dateVal is Timestamp) return dateVal.toDate();
      if (dateVal is String) return DateTime.parse(dateVal);
      return DateTime.now();
    }

    return Transaction(
      id: map['id'],
      accountId: map['accountId'],
      amount: map['amount']?.toDouble() ?? 0.0,
      type: map['type'],
      category: map['category'],
      description: map['description'],
      date: parseDate(map['date']),
      billImage: map['billImage'],
      quantity: map['quantity']?.toInt() ?? 1,
      rate: map['rate']?.toDouble() ?? 0.0,
      receivedAmount: map['receivedAmount']?.toDouble() ?? 0.0,
      pendingAmount: map['pendingAmount']?.toDouble() ?? 0.0,
      referenceNumber: map['referenceNumber'],
      paymentMethod: map['paymentMethod'] ?? 'cash',
      isPending: map['isPending'] ?? false,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      professionId: map['professionId'],
      professionName: map['professionName'],
      partnershipId: map['partnershipId'],
      voiceNote: map['voiceNote'],
      items: map['items'] != null
          ? List<TransactionItem>.from(map['items']?.map((x) => TransactionItem.fromMap(x)))
          : [],
      subtotal: map['subtotal']?.toDouble() ??
          map['amount']?.toDouble() ??
          0.0,
      discountAmount: map['discountAmount']?.toDouble() ?? 0.0,
      discountPercent: map['discountPercent']?.toDouble(),
      discountReason: map['discountReason'],
    );
  }

  double get totalAmount => quantity * rate;
  bool get isFullyPaid => receivedAmount >= amount;
  bool get isQuickBill {
    final normalizedDescription = description.trim().toLowerCase();
    return normalizedDescription == 'quick bill' ||
        normalizedDescription == 'فوری بل' ||
        normalizedDescription.contains('فوری بل') ||
        normalizedDescription.contains('quick bill');
  }

  double get accountBalanceAmount {
    if (!isQuickBill ||
        (receivedAmount == 0 && pendingAmount == 0 && amount != 0)) {
      return amount;
    }
    return pendingAmount;
  }

  String get formattedDate => DateFormat('dd/MM/yyyy').format(date);
  String get formattedTime => DateFormat('hh:mm a').format(date);

  /// پیشے کے لیے یہ آمدن ہے یا خرچ؟
  String get professionSide {
    if (category.startsWith('INC:')) return 'income';
    if (category.startsWith('EXP:')) return 'expense';
    if (category == 'income') return 'income';
    if (category == 'expense') return 'expense';
    // Fallback to ledger type
    return type;
  }
}
