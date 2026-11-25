// lib/features/contracts/bulk_attendance_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/worker_payroll_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/worker_payroll_service.dart';
import 'package:account_app/core/services/worker_service.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';

class BulkAttendanceScreen extends StatefulWidget {
  const BulkAttendanceScreen({super.key});

  @override
  State<BulkAttendanceScreen> createState() => _BulkAttendanceScreenState();
}

class _BulkAttendanceScreenState extends State<BulkAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Account> _workers = [];
  final Map<String, WorkerAttendanceStatus> _attendanceMap = {};
  final Map<String, WorkerAttendanceStatus?> _initialAttendanceMap = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkersAndAttendance();
    });
  }

  bool get _hasAttendanceChanges {
    if (_workers.isEmpty) return false;
    for (final worker in _workers) {
      if (_attendanceMap[worker.id] != _initialAttendanceMap[worker.id]) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadWorkersAndAttendance() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final workerService = Provider.of<WorkerService>(context, listen: false);
      final payrollService =
          Provider.of<WorkerPayrollService>(context, listen: false);
      final contractService =
          Provider.of<ContractService>(context, listen: false);

      final combined = await workerService.ensureWorkerAccounts(
        dbService,
        payrollService: payrollService,
        contractService: contractService,
      );
      _attendanceMap.clear();
      _initialAttendanceMap.clear();
      for (final worker in combined) {
        final record = payrollService.getAttendance(worker.id, _selectedDate);
        final status = record?.status ?? WorkerAttendanceStatus.present;
        _attendanceMap[worker.id] = status;
        _initialAttendanceMap[worker.id] = record?.status;
      }

      if (mounted) {
        setState(() {
          _workers = combined;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.error(
        context,
        'Could not load workers',
        subtitle: error.toString(),
      );
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadWorkersAndAttendance();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = DateTime(date.year, date.month, date.day);
      });
      _loadWorkersAndAttendance();
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final payrollService =
          Provider.of<WorkerPayrollService>(context, listen: false);

      for (final worker in _workers) {
        final status =
            _attendanceMap[worker.id] ?? WorkerAttendanceStatus.present;
        await payrollService.saveAttendance(
          workerId: worker.id,
          date: _selectedDate,
          status: status,
          databaseService: dbService,
        );
      }

      if (!mounted) return;
      AppToast.success(
        context,
        Provider.of<LanguageService>(context, listen: false).isUrdu
            ? 'تمام مزدوروں کی حاضری محفوظ ہو گئی'
            : 'All workers attendance saved',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        Provider.of<LanguageService>(context, listen: false).isUrdu
            ? 'حاضری محفوظ نہیں ہو سکی'
            : 'Could not save attendance',
        subtitle: error.toString(),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = Provider.of<LanguageService>(context);
    final isUrdu = language.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return Directionality(
      textDirection: language.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: ScreenAppBar(
          title: isUrdu ? 'متعدد مزدوروں کی حاضری' : 'Bulk Attendance',
          isUrdu: isUrdu,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: Row(
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.darkColor,
                              fontFamily: fontFamily,
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
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.slateColor),
                      )
                    : _workers.isEmpty
                        ? Center(
                            child: UrduAwareText(
                              isUrdu
                                  ? 'کوئی مزدور موجود نہیں'
                                  : 'No workers found',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                            itemCount: _workers.length,
                            itemBuilder: (context, index) {
                              final worker = _workers[index];
                              final currentStatus = _attendanceMap[worker.id] ??
                                  WorkerAttendanceStatus.present;
                              final isPresent = currentStatus ==
                                  WorkerAttendanceStatus.present;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFD1D5DB),
                                      width: 1.1),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ProfileInfoWidget(
                                        name: worker.name,
                                        phone: worker.phone,
                                        profileImage: worker.profileImage,
                                        category: worker.category,
                                        address: worker.address,
                                        isLarge: false,
                                        customSize: 36,
                                        borderRadius: 8,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: AppButton(
                                            text: isUrdu ? 'حاضر' : 'Present',
                                            size: AppButtonSize.small,
                                            variant: isPresent
                                                ? AppButtonVariant.primary
                                                : AppButtonVariant.outlined,
                                            color: AppTheme.incomeColor,
                                            onPressed: () => setState(() {
                                              _attendanceMap[worker.id] =
                                                  WorkerAttendanceStatus
                                                      .present;
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        SizedBox(
                                          width: 85,
                                          child: AppButton(
                                            text:
                                                isUrdu ? 'غیر حاضر' : 'Absent',
                                            size: AppButtonSize.small,
                                            variant: !isPresent
                                                ? AppButtonVariant.primary
                                                : AppButtonVariant.outlined,
                                            color: AppTheme.expenseColor,
                                            onPressed: () => setState(() {
                                              _attendanceMap[worker.id] =
                                                  WorkerAttendanceStatus.absent;
                                            }),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _workers.isEmpty
            ? null
            : Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: SafeArea(
                  child: AppButton(
                    text: isUrdu
                        ? 'تمام مزدوروں کی حاضری محفوظ کریں'
                        : 'Save All Attendance',
                    icon: PhosphorIcons.floppyDisk(),
                    size: AppButtonSize.large,
                    isFullWidth: true,
                    color: AppTheme.slateColor,
                    isLoading: _isSaving,
                    onPressed: !_hasAttendanceChanges ? null : _saveAll,
                  ),
                ),
              ),
      ),
    );
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
