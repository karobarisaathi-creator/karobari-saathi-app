import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/contract_model.dart';
import 'package:account_app/core/models/worker_payroll_model.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/worker_payroll_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';

class WorkerAttendanceScreen extends StatefulWidget {
  final Account worker;

  const WorkerAttendanceScreen({super.key, required this.worker});

  @override
  State<WorkerAttendanceScreen> createState() => _WorkerAttendanceScreenState();
}

class _WorkerAttendanceScreenState extends State<WorkerAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  WorkerPayrollPeriod _period = WorkerPayrollPeriod.monthly;
  bool _isSaving = false;
  bool _ledgerReconcileStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ledgerReconcileStarted) return;
    _ledgerReconcileStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileLedger();
    });
  }

  Future<void> _reconcileLedger() async {
    try {
      await Provider.of<WorkerPayrollService>(context, listen: false)
          .reconcileWorkerLedger(
        workerId: widget.worker.id,
        databaseService: Provider.of<DatabaseService>(context, listen: false),
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        Provider.of<LanguageService>(context, listen: false).isUrdu
            ? 'اجرت کھاتے میں درج نہیں ہو سکی'
            : 'Could not sync earned wages to the worker ledger',
        subtitle: error.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = Provider.of<LanguageService>(context);
    final isUrdu = language.isUrdu;
    final service = Provider.of<WorkerPayrollService>(context);

    return Directionality(
      textDirection: language.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: UrduAwareText(
            isUrdu ? 'حاضری اور اجرت' : 'Attendance & Payroll',
            style: const TextStyle(
              color: AppTheme.darkColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: AppTheme.backgroundColor,
          foregroundColor: AppTheme.darkColor,
          elevation: 0,
        ),
        body: service.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.goldColor))
            : _buildContent(service, isUrdu),
      ),
    );
  }

  Widget _buildContent(WorkerPayrollService service, bool isUrdu) {
    final dateRecord = service.getAttendance(widget.worker.id, _selectedDate);
    final rate = service.getRateForDate(widget.worker.id, _selectedDate);
    final range = _periodRange(_selectedDate, _period);
    final workerAttendance = service.getAttendanceForWorker(widget.worker.id);
    final workerRates = service.getRatesForWorker(widget.worker.id);
    final workerPayments = service.getPaymentsForWorker(widget.worker.id);
    final periodAttendance = workerAttendance
        .where((record) => _withinRange(record.date, range.$1, range.$2));
    final periodPayments = workerPayments
        .where((payment) => _withinRange(payment.date, range.$1, range.$2));
    final periodEarned = WorkerPayrollCalculator.totalEarned(
      periodAttendance,
      workerRates,
      from: range.$1,
      through: range.$2,
    );
    final presentCount = periodAttendance
        .where((record) => record.status == WorkerAttendanceStatus.present)
        .length;
    final totalEarned =
        WorkerPayrollCalculator.totalEarned(workerAttendance, workerRates);
    final totalPaid =
        workerPayments.fold(0.0, (total, payment) => total + payment.amount);
    final outstanding = totalEarned - totalPaid;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _workerHeader(
          service: service,
          rate: rate,
          isUrdu: isUrdu,
          periodEarned: periodEarned,
          periodPaid: periodPayments.fold(
              0.0, (total, payment) => total + payment.amount),
          outstanding: outstanding,
          presentCount: presentCount,
        ),
        const SizedBox(height: 8),
        _sectionCard(
          title: isUrdu ? 'روزانہ حاضری' : 'Daily attendance',
          icon: PhosphorIcons.calendarCheck(),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _changeDate(-1),
                    icon: Icon(PhosphorIcons.caretLeft()),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: Center(
                        child: UrduAwareText(
                          Formatters.formatDate(_selectedDate),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _selectedDate.isBefore(DateTime.now()) &&
                            !_sameDay(_selectedDate, DateTime.now())
                        ? () => _changeDate(1)
                        : null,
                    icon: Icon(PhosphorIcons.caretRight()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _attendanceChoice(
                      isUrdu ? 'حاضر' : 'Present',
                      WorkerAttendanceStatus.present,
                      _pendingStatus ?? dateRecord?.status,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _attendanceChoice(
                      isUrdu ? 'غیر حاضر' : 'Absent',
                      WorkerAttendanceStatus.absent,
                      _pendingStatus ?? dateRecord?.status,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppButton(
                text: isUrdu ? 'حاضری محفوظ کریں' : 'Save attendance',
                icon: PhosphorIcons.floppyDisk(),
                size: AppButtonSize.large,
                isFullWidth: true,
                color: AppTheme.goldColor,
                isLoading: _isSaving,
                onPressed: !_hasAttendanceChanged(dateRecord)
                    ? null
                    : () => _saveAttendance(
                          service,
                          _pendingStatus ?? dateRecord!.status,
                          isUrdu,
                        ),
              ),
              if (rate == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: UrduAwareText(
                    isUrdu
                        ? 'اجرت کا حساب شروع کرنے کے لیے پہلے شرح مقرر کریں'
                        : 'Set a wage rate to calculate earnings',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _historySection(
          isUrdu: isUrdu,
          service: service,
          attendance: periodAttendance.toList(),
          payments: periodPayments.toList(),
          rates: workerRates,
          rangeStart: range.$1,
          rangeEnd: range.$2,
        ),
      ],
    );
  }

  Widget _workerHeader({
    required WorkerPayrollService service,
    required WorkerWageRate? rate,
    required bool isUrdu,
    required double periodEarned,
    required double periodPaid,
    required double outstanding,
    required int presentCount,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.goldColor, Color(0xFFB77B18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileInfoWidget(
              name: widget.worker.name,
              phone: widget.worker.phone,
              profileImage: widget.worker.profileImage,
              category: widget.worker.category,
              address: widget.worker.address,
              textColor: Colors.white,
              subtitleColor: Colors.white70,
              addressColor: Colors.white70,
              categoryColor: Colors.white70,
              customSize: 44,
              suffix: Icon(
                PhosphorIcons.identificationCard(),
                color: Colors.white70,
                size: 22,
              ),
            ),
            const Divider(color: Colors.white24, height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UrduAwareText(
                        isUrdu ? 'اجرت کی شرح' : 'Wage rate',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      UrduAwareText(
                        rate == null
                            ? (isUrdu ? 'اجرت مقرر نہیں' : 'No wage rate set')
                            : '${Formatters.formatAmountWithCurrency(rate.amount)} / ${_rateLabel(rate.type, isUrdu)} • ${isUrdu ? 'لاگو از' : 'From'} ${Formatters.formatDate(rate.effectiveFrom)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 38,
                  width: 1,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UrduAwareText(
                        isUrdu ? 'کل حاضری' : 'Total attendance',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      UrduAwareText(
                        '$presentCount ${isUrdu ? 'دن (حاضر)' : 'days (present)'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 20),
            Row(
              children: [
                Expanded(
                  child: _headerMetricItem(
                    title: isUrdu ? 'واجب اجرت' : 'Earned',
                    value: Formatters.formatAmountWithCurrency(periodEarned),
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                Expanded(
                  child: _headerMetricItem(
                    title: isUrdu ? 'ادا شدہ' : 'Paid',
                    value: Formatters.formatAmountWithCurrency(periodPaid),
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                Expanded(
                  child: _headerMetricItem(
                    title: outstanding < 0
                        ? (isUrdu ? 'ایڈوانس' : 'Advance')
                        : (isUrdu ? 'بقایا' : 'Due'),
                    value:
                        Formatters.formatAmountWithCurrency(outstanding.abs()),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: isUrdu ? 'شرح مقرر کریں' : 'Set rate',
                    icon: PhosphorIcons.pencilSimple(),
                    size: AppButtonSize.small,
                    variant: AppButtonVariant.outlined,
                    borderColor: Colors.white,
                    textColor: Colors.black,
                    isFullWidth: true,
                    onPressed: () => _showWageRateDialog(service, rate, isUrdu),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    text: isUrdu ? 'اجرت ادا کریں' : 'Record wage payment',
                    icon: PhosphorIcons.handCoins(),
                    size: AppButtonSize.small,
                    color: AppTheme.themeColor,
                    isFullWidth: true,
                    onPressed: () => _showPaymentDialog(isUrdu),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _headerMetricItem({
    required String title,
    required String value,
  }) =>
      Column(
        children: [
          UrduAwareText(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          UrduAwareText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.lightColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.goldColor),
                const SizedBox(width: 8),
                UrduAwareText(
                  title,
                  style: const TextStyle(
                    color: AppTheme.darkColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _attendanceChoice(
    String title,
    WorkerAttendanceStatus choice,
    WorkerAttendanceStatus? selected,
  ) {
    final isSelected = choice == selected;
    final color = choice == WorkerAttendanceStatus.present
        ? AppTheme.incomeColor
        : AppTheme.expenseColor;
    return AppButton(
      text: title,
      icon: choice == WorkerAttendanceStatus.present
          ? PhosphorIcons.checkCircle()
          : PhosphorIcons.xCircle(),
      variant:
          isSelected ? AppButtonVariant.primary : AppButtonVariant.outlined,
      size: AppButtonSize.small,
      isFullWidth: true,
      color: color,
      onPressed: () => setState(() {
        _pendingStatus = choice;
      }),
    );
  }

  WorkerAttendanceStatus? _pendingStatus;

  bool _hasAttendanceChanged(WorkerAttendanceRecord? dateRecord) {
    if (_pendingStatus == null) return false;
    if (dateRecord == null) return true;
    return _pendingStatus != dateRecord.status;
  }

  Future<void> _saveAttendance(
    WorkerPayrollService service,
    WorkerAttendanceStatus initialStatus,
    bool isUrdu,
  ) async {
    setState(() => _isSaving = true);
    try {
      await service.saveAttendance(
        workerId: widget.worker.id,
        date: _selectedDate,
        status: _pendingStatus ?? initialStatus,
        databaseService: Provider.of<DatabaseService>(context, listen: false),
      );
      if (!mounted) return;
      setState(() => _pendingStatus = null);
      AppToast.success(
          context, isUrdu ? 'حاضری محفوظ ہو گئی' : 'Attendance saved');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        isUrdu ? 'حاضری محفوظ نہیں ہو سکی' : 'Could not save attendance',
        subtitle: error.toString(),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _historySection({
    required bool isUrdu,
    required WorkerPayrollService service,
    required List<WorkerAttendanceRecord> attendance,
    required List<WorkerWagePayment> payments,
    required List<WorkerWageRate> rates,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    attendance.sort((a, b) => b.date.compareTo(a.date));
    payments.sort((a, b) => b.date.compareTo(a.date));
    return _sectionCard(
      title: isUrdu ? 'ریکارڈ اور ادائیگیاں' : 'Records & payments',
      icon: PhosphorIcons.clockCounterClockwise(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0;
                            i < WorkerPayrollPeriod.values.length;
                            i++) ...[
                          if (i > 0)
                            Container(
                                width: 1, color: const Color(0xFFE2E8F0)),
                          Material(
                            color: WorkerPayrollPeriod.values[i] == _period
                                ? AppTheme.goldColor
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(
                                () => _period = WorkerPayrollPeriod.values[i],
                              ),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                alignment: Alignment.center,
                                child: UrduAwareText(
                                  _periodLabel(
                                      WorkerPayrollPeriod.values[i], isUrdu),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        WorkerPayrollPeriod.values[i] == _period
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                    color:
                                        WorkerPayrollPeriod.values[i] == _period
                                            ? Colors.white
                                            : AppTheme.darkColor,
                                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          UrduAwareText(
            '${Formatters.formatDate(rangeStart)} – ${Formatters.formatDate(rangeEnd)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          if (attendance.isEmpty && payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: UrduAwareText(
                  isUrdu
                      ? 'اس مدت کا کوئی ریکارڈ نہیں'
                      : 'No records for this period',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ...attendance.map((record) {
            final earned = WorkerPayrollCalculator.earningFor(record, rates);
            final present = record.status == WorkerAttendanceStatus.present;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                present ? PhosphorIcons.checkCircle() : PhosphorIcons.xCircle(),
                color: present ? AppTheme.incomeColor : AppTheme.expenseColor,
              ),
              title: UrduAwareText(
                  '${Formatters.formatDate(record.date)} · ${present ? (isUrdu ? 'حاضر' : 'Present') : (isUrdu ? 'غیر حاضر' : 'Absent')}'),
              trailing: UrduAwareText(
                Formatters.formatAmountWithCurrency(earned),
                style: TextStyle(
                  color: present ? AppTheme.darkColor : AppTheme.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              dense: true,
            );
          }),
          ...payments.map((payment) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(PhosphorIcons.handCoins(), color: AppTheme.themeColor),
                title: UrduAwareText(
                  payment.note.isEmpty
                      ? (isUrdu ? 'اجرت کی ادائیگی' : 'Wage payment')
                      : payment.note,
                ),
                subtitle: UrduAwareText(Formatters.formatDate(payment.date)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UrduAwareText(
                      Formatters.formatAmountWithCurrency(payment.amount),
                      style: const TextStyle(
                        color: AppTheme.incomeColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      tooltip: isUrdu ? 'ترمیم کریں' : 'Edit',
                      onPressed: () => _showPaymentDialog(
                        isUrdu,
                        paymentToEdit: payment,
                      ),
                      icon: Icon(PhosphorIcons.pencilSimple(),
                          size: 17, color: AppTheme.themeColor),
                    ),
                    IconButton(
                      tooltip: isUrdu ? 'حذف کریں' : 'Delete',
                      onPressed: () =>
                          _confirmDeletePayment(service, payment, isUrdu),
                      icon: Icon(PhosphorIcons.trash(),
                          size: 17, color: AppTheme.expenseColor),
                    ),
                  ],
                ),
                dense: true,
              )),
        ],
      ),
    );
  }

  Future<void> _showWageRateDialog(
    WorkerPayrollService service,
    WorkerWageRate? currentRate,
    bool isUrdu,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _WorkerWageRateDialog(
        isUrdu: isUrdu,
        currentRate: currentRate,
        initialDate: _selectedDate,
        onSave: (type, amount, effectiveFrom) => service.setWageRate(
          workerId: widget.worker.id,
          type: type,
          amount: amount,
          effectiveFrom: effectiveFrom,
          databaseService: Provider.of<DatabaseService>(context, listen: false),
        ),
      ),
    );
    if (saved == true && mounted) {
      AppToast.success(
          context, isUrdu ? 'اجرت کی شرح محفوظ ہو گئی' : 'Wage rate saved');
    }
  }

  Future<void> _showPaymentDialog(
    bool isUrdu, {
    WorkerWagePayment? paymentToEdit,
  }) async {
    final contractService =
        Provider.of<ContractService>(context, listen: false);
    final eligibleContracts = contractService.contracts
        .where((contract) => contract.isIncoming)
        .toList();
    final initialContractId = paymentToEdit == null
        ? (eligibleContracts.length == 1 ? eligibleContracts.single.id : null)
        : contractService.contractIdForPayrollPayment(paymentToEdit.id);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => WorkerWagePaymentDialog(
        isUrdu: isUrdu,
        paymentToEdit: paymentToEdit,
        contracts: eligibleContracts,
        initialContractId: initialContractId,
        onSave: (amount, note, contractId) async {
          final service =
              Provider.of<WorkerPayrollService>(context, listen: false);
          final databaseService =
              Provider.of<DatabaseService>(context, listen: false);
          if (paymentToEdit == null) {
            await service.addWagePayment(
              workerId: widget.worker.id,
              amount: amount,
              note: note,
              contractId: contractId,
              contractService: contractService,
              databaseService: databaseService,
            );
          } else {
            await service.editWagePayment(
              payment: paymentToEdit,
              amount: amount,
              note: note,
              contractId: contractId,
              contractService: contractService,
              databaseService: databaseService,
            );
          }
        },
      ),
    );
    if (saved == true && mounted) {
      AppToast.success(
        context,
        paymentToEdit == null
            ? (isUrdu ? 'ادائیگی محفوظ ہو گئی' : 'Payment recorded')
            : (isUrdu ? 'ادائیگی اپڈیٹ ہو گئی' : 'Payment updated'),
      );
    }
  }

  Future<void> _confirmDeletePayment(
    WorkerPayrollService service,
    WorkerWagePayment payment,
    bool isUrdu,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: UrduAwareText(isUrdu ? 'ادائیگی حذف کریں؟' : 'Delete payment?'),
        actions: [
          AppButton(
            text: isUrdu ? 'نہیں' : 'Cancel',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppButton(
            text: isUrdu ? 'حذف کریں' : 'Delete',
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
            color: AppTheme.expenseColor,
            onPressed: () async {
              try {
                await service.deleteWagePayment(
                  payment: payment,
                  contractService:
                      Provider.of<ContractService>(context, listen: false),
                  databaseService:
                      Provider.of<DatabaseService>(context, listen: false),
                );
              } catch (error) {
                if (!mounted) return;
                AppToast.error(
                  context,
                  isUrdu
                      ? 'ادائیگی حذف نہیں ہو سکی'
                      : 'Could not delete payment',
                  subtitle: error.toString(),
                );
                return;
              }
              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              AppToast.success(
                  context, isUrdu ? 'ادائیگی حذف ہو گئی' : 'Payment deleted');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _selectDate(date));
  }

  void _changeDate(int days) {
    setState(() => _selectDate(_selectedDate.add(Duration(days: days))));
  }

  void _selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _pendingStatus = null;
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  bool _withinRange(DateTime date, DateTime start, DateTime end) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return !normalizedDate.isBefore(start) && !normalizedDate.isAfter(end);
  }

  (DateTime, DateTime) _periodRange(DateTime date, WorkerPayrollPeriod period) {
    final day = DateTime(date.year, date.month, date.day);
    switch (period) {
      case WorkerPayrollPeriod.daily:
        return (day, day);
      case WorkerPayrollPeriod.weekly:
        final start = day.subtract(Duration(days: day.weekday - 1));
        return (start, start.add(const Duration(days: 6)));
      case WorkerPayrollPeriod.monthly:
        final start = DateTime(day.year, day.month);
        return (start, DateTime(day.year, day.month + 1, 0));
    }
  }

  String _rateLabel(WorkerWageType? type, bool isUrdu) {
    if (type == WorkerWageType.monthly) {
      return isUrdu ? 'ماہانہ' : 'monthly';
    }
    return isUrdu ? 'روزانہ' : 'daily';
  }

  String _periodLabel(WorkerPayrollPeriod period, bool isUrdu) {
    switch (period) {
      case WorkerPayrollPeriod.daily:
        return isUrdu ? 'روزانہ' : 'Daily';
      case WorkerPayrollPeriod.weekly:
        return isUrdu ? 'ہفتہ وار' : 'Weekly';
      case WorkerPayrollPeriod.monthly:
        return isUrdu ? 'ماہانہ' : 'Monthly';
    }
  }
}

class WorkerWagePaymentDialog extends StatefulWidget {
  final bool isUrdu;
  final WorkerWagePayment? paymentToEdit;
  final List<ContractModel> contracts;
  final String? initialContractId;
  final Future<void> Function(
    double amount,
    String note,
    String? contractId,
  ) onSave;

  const WorkerWagePaymentDialog({
    super.key,
    required this.isUrdu,
    required this.paymentToEdit,
    this.contracts = const [],
    this.initialContractId,
    required this.onSave,
  });

  @override
  State<WorkerWagePaymentDialog> createState() =>
      _WorkerWagePaymentDialogState();
}

class _WorkerWagePaymentDialogState extends State<WorkerWagePaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  String? _contractId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.paymentToEdit?.amount.toString() ?? '');
    _noteController =
        TextEditingController(text: widget.paymentToEdit?.note ?? '');
    _contractId = widget.initialContractId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = Formatters.tryParseAmount(_amountController.text,
            allowDecimals: true) ??
        double.tryParse(_amountController.text) ??
        0;
    if (amount <= 0) {
      AppToast.warning(
        context,
        widget.isUrdu ? 'درست رقم درج کریں' : 'Enter a valid amount',
      );
      return;
    }
    if (widget.contracts.isNotEmpty && _contractId == null) {
      AppToast.warning(
        context,
        widget.isUrdu ? 'ٹھیکہ منتخب کریں' : 'Select a contract',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(amount, _noteController.text, _contractId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        widget.isUrdu ? 'ادائیگی محفوظ نہیں ہو سکی' : 'Could not save payment',
        subtitle: error.toString(),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = widget.isUrdu;
    return AlertDialog(
      title: UrduAwareText(
        widget.paymentToEdit == null
            ? (isUrdu ? 'اجرت ادا کریں' : 'Record wage payment')
            : (isUrdu ? 'اجرت کی ادائیگی میں ترمیم' : 'Edit wage payment'),
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.contracts.isNotEmpty) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: UrduAwareText(
                    isUrdu ? 'متعلقہ ٹھیکہ' : 'Related contract',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: IntrinsicHeight(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0;
                                i < widget.contracts.length;
                                i++) ...[
                              if (i > 0)
                                Container(
                                    width: 1,
                                    color: const Color(0xFFE2E8F0)),
                              Material(
                                color: widget.contracts[i].id == _contractId
                                    ? AppTheme.goldColor
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: _isSaving
                                      ? null
                                      : () => setState(
                                            () => _contractId =
                                                widget.contracts[i].id,
                                          ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    alignment: Alignment.center,
                                    child: UrduAwareText(
                                      widget.contracts[i].title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            widget.contracts[i].id == _contractId
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                        color: widget.contracts[i].id == _contractId
                                            ? Colors.white
                                            : AppTheme.darkColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        controller: _amountController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'ادا شدہ رقم' : 'Amount paid',
                          labelStyle: TextStyle(
                            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                            color: AppTheme.textSecondary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        controller: _noteController,
                        enabled: !_isSaving,
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'نوٹ (اختیاری)' : 'Note (optional)',
                          labelStyle: TextStyle(
                            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                            color: AppTheme.textSecondary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: isUrdu ? 'منسوخ' : 'Cancel',
                      variant: AppButtonVariant.outlined,
                      size: AppButtonSize.large,
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: isUrdu ? 'محفوظ کریں' : 'Save payment',
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.large,
                      color: AppTheme.goldColor,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: const [],
    );
  }
}

class _WorkerWageRateDialog extends StatefulWidget {
  final bool isUrdu;
  final WorkerWageRate? currentRate;
  final DateTime initialDate;
  final Future<void> Function(
    WorkerWageType type,
    double amount,
    DateTime effectiveFrom,
  ) onSave;

  const _WorkerWageRateDialog({
    required this.isUrdu,
    required this.currentRate,
    required this.initialDate,
    required this.onSave,
  });

  @override
  State<_WorkerWageRateDialog> createState() => _WorkerWageRateDialogState();
}

class _WorkerWageRateDialogState extends State<_WorkerWageRateDialog> {
  late final TextEditingController _amountController;
  late WorkerWageType _type;
  late DateTime _effectiveDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.currentRate?.amount.toString() ?? '');
    _type = widget.currentRate?.type ?? WorkerWageType.daily;
    _effectiveDate = widget.initialDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectEffectiveDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() => _effectiveDate = date);
    }
  }

  Future<void> _submit() async {
    final amount = Formatters.tryParseAmount(_amountController.text,
            allowDecimals: true) ??
        double.tryParse(_amountController.text) ??
        0;
    if (amount <= 0) {
      AppToast.warning(
        context,
        widget.isUrdu ? 'درست رقم درج کریں' : 'Enter a valid amount',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(_type, amount, _effectiveDate);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        widget.isUrdu ? 'شرح محفوظ نہیں ہو سکی' : 'Could not save wage rate',
        subtitle: error.toString(),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = widget.isUrdu;
    return AlertDialog(
      title: UrduAwareText(isUrdu ? 'اجرت کی شرح مقرر کریں' : 'Set wage rate'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _isSaving
                                  ? null
                                  : () => setState(
                                        () => _type = WorkerWageType.daily,
                                      ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _type == WorkerWageType.daily
                                      ? AppTheme.goldColor
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: UrduAwareText(
                                  isUrdu ? 'روزانہ' : 'Daily',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _type == WorkerWageType.daily
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    color: _type == WorkerWageType.daily
                                        ? Colors.white
                                        : AppTheme.darkColor,
                                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: _isSaving
                                  ? null
                                  : () => setState(
                                        () => _type = WorkerWageType.monthly,
                                      ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _type == WorkerWageType.monthly
                                      ? AppTheme.goldColor
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: UrduAwareText(
                                  isUrdu ? 'ماہانہ' : 'Monthly',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _type == WorkerWageType.monthly
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    color: _type == WorkerWageType.monthly
                                        ? Colors.white
                                        : AppTheme.darkColor,
                                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: TextField(
                        controller: _amountController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'رقم' : 'Amount',
                          labelStyle: TextStyle(
                            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                            color: AppTheme.textSecondary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSaving ? null : _selectEffectiveDate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.calendarBlank(),
                                  size: 18, color: AppTheme.themeColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: UrduAwareText(
                                  '${isUrdu ? 'لاگو ہونے کی تاریخ' : 'Effective date'}: ${Formatters.formatDate(_effectiveDate)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkColor,
                                    fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: isUrdu ? 'منسوخ' : 'Cancel',
                      variant: AppButtonVariant.outlined,
                      size: AppButtonSize.large,
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: isUrdu ? 'محفوظ کریں' : 'Save',
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.large,
                      color: AppTheme.goldColor,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: const [],
    );
  }
}
