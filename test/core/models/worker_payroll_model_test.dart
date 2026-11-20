import 'package:flutter_test/flutter_test.dart';
import 'package:account_app/core/models/worker_payroll_model.dart';

void main() {
  group('WorkerPayrollCalculator', () {
    final dailyRate = WorkerWageRate(
      id: 'daily',
      workerId: 'worker',
      type: WorkerWageType.daily,
      amount: 1000,
      effectiveFrom: DateTime(2026, 1, 1),
    );

    test('calculates daily wage for present attendance only', () {
      final attendance = [
        WorkerAttendanceRecord(
          id: 'present',
          workerId: 'worker',
          date: DateTime(2026, 1, 2),
          status: WorkerAttendanceStatus.present,
        ),
        WorkerAttendanceRecord(
          id: 'absent',
          workerId: 'worker',
          date: DateTime(2026, 1, 3),
          status: WorkerAttendanceStatus.absent,
        ),
      ];

      expect(
        WorkerPayrollCalculator.totalEarned(attendance, [dailyRate]),
        1000,
      );
    });

    test(
        'uses the applicable rate and prorates monthly salary by calendar days',
        () {
      final monthlyRate = WorkerWageRate(
        id: 'monthly',
        workerId: 'worker',
        type: WorkerWageType.monthly,
        amount: 31000,
        effectiveFrom: DateTime(2026, 1, 15),
      );
      final beforeRateChange = WorkerAttendanceRecord(
        id: 'old',
        workerId: 'worker',
        date: DateTime(2026, 1, 14),
        status: WorkerAttendanceStatus.present,
      );
      final afterRateChange = WorkerAttendanceRecord(
        id: 'new',
        workerId: 'worker',
        date: DateTime(2026, 1, 15),
        status: WorkerAttendanceStatus.present,
      );

      expect(
        WorkerPayrollCalculator.earningFor(beforeRateChange, [
          dailyRate,
          monthlyRate,
        ]),
        1000,
      );
      expect(
        WorkerPayrollCalculator.earningFor(afterRateChange, [
          dailyRate,
          monthlyRate,
        ]),
        1000,
      );
    });

    test('filters earnings by inclusive date range', () {
      final attendance = List.generate(
        3,
        (index) => WorkerAttendanceRecord(
          id: '$index',
          workerId: 'worker',
          date: DateTime(2026, 1, index + 1),
          status: WorkerAttendanceStatus.present,
        ),
      );

      expect(
        WorkerPayrollCalculator.totalEarned(
          attendance,
          [dailyRate],
          from: DateTime(2026, 1, 2),
          through: DateTime(2026, 1, 2),
        ),
        1000,
      );
    });
  });
}
