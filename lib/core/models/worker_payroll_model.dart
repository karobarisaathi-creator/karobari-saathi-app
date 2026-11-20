enum WorkerWageType { daily, monthly }

enum WorkerAttendanceStatus { present, absent }

enum WorkerPayrollPeriod { daily, weekly, monthly }

class WorkerAttendanceRecord {
  final String id;
  final String workerId;
  final DateTime date;
  final WorkerAttendanceStatus status;
  final String note;

  const WorkerAttendanceRecord({
    required this.id,
    required this.workerId,
    required this.date,
    required this.status,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'kind': 'attendance',
        'id': id,
        'workerId': workerId,
        'date': date.toIso8601String(),
        'status': status.name,
        'note': note,
      };

  factory WorkerAttendanceRecord.fromMap(Map<dynamic, dynamic> map) =>
      WorkerAttendanceRecord(
        id: map['id']?.toString() ?? '',
        workerId: map['workerId']?.toString() ?? '',
        date: DateTime.tryParse(map['date']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        status: WorkerAttendanceStatus.values.firstWhere(
          (status) => status.name == map['status']?.toString(),
          orElse: () => WorkerAttendanceStatus.absent,
        ),
        note: map['note']?.toString() ?? '',
      );
}

class WorkerWageRate {
  final String id;
  final String workerId;
  final WorkerWageType type;
  final double amount;
  final DateTime effectiveFrom;

  const WorkerWageRate({
    required this.id,
    required this.workerId,
    required this.type,
    required this.amount,
    required this.effectiveFrom,
  });

  Map<String, dynamic> toMap() => {
        'kind': 'rate',
        'id': id,
        'workerId': workerId,
        'type': type.name,
        'amount': amount,
        'effectiveFrom': effectiveFrom.toIso8601String(),
      };

  factory WorkerWageRate.fromMap(Map<dynamic, dynamic> map) => WorkerWageRate(
        id: map['id']?.toString() ?? '',
        workerId: map['workerId']?.toString() ?? '',
        type: WorkerWageType.values.firstWhere(
          (type) => type.name == map['type']?.toString(),
          orElse: () => WorkerWageType.daily,
        ),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        effectiveFrom:
            DateTime.tryParse(map['effectiveFrom']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class WorkerWagePayment {
  final String id;
  final String workerId;
  final double amount;
  final DateTime date;
  final String note;

  const WorkerWagePayment({
    required this.id,
    required this.workerId,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'kind': 'payment',
        'id': id,
        'workerId': workerId,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory WorkerWagePayment.fromMap(Map<dynamic, dynamic> map) =>
      WorkerWagePayment(
        id: map['id']?.toString() ?? '',
        workerId: map['workerId']?.toString() ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse(map['date']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        note: map['note']?.toString() ?? '',
      );
}

class WorkerPayrollCalculator {
  static WorkerWageRate? rateForDate(
    List<WorkerWageRate> rates,
    DateTime date,
  ) {
    final day = DateTime(date.year, date.month, date.day);
    WorkerWageRate? result;
    for (final rate in rates) {
      final effectiveDate = DateTime(
        rate.effectiveFrom.year,
        rate.effectiveFrom.month,
        rate.effectiveFrom.day,
      );
      if (!effectiveDate.isAfter(day) &&
          (result == null ||
              rate.effectiveFrom.isAfter(result.effectiveFrom))) {
        result = rate;
      }
    }
    return result;
  }

  static double earningFor(
    WorkerAttendanceRecord attendance,
    List<WorkerWageRate> rates,
  ) {
    if (attendance.status != WorkerAttendanceStatus.present) return 0;
    final rate = rateForDate(rates, attendance.date);
    if (rate == null) return 0;
    if (rate.type == WorkerWageType.daily) return rate.amount;
    final daysInMonth =
        DateTime(attendance.date.year, attendance.date.month + 1, 0).day;
    return rate.amount / daysInMonth;
  }

  static double totalEarned(
    Iterable<WorkerAttendanceRecord> attendance,
    List<WorkerWageRate> rates, {
    DateTime? from,
    DateTime? through,
  }) {
    return attendance
        .where((record) =>
            (from == null || !record.date.isBefore(from)) &&
            (through == null || !record.date.isAfter(through)))
        .fold(0.0, (total, record) => total + earningFor(record, rates));
  }
}
