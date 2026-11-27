// lib/features/workers/workers_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/worker_service.dart';
import 'package:account_app/core/services/worker_payroll_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';
import 'package:account_app/features/quick_bill/widgets/customer_picker_sheet.dart';

import 'worker_attendance_screen.dart';

class WorkersListScreen extends StatefulWidget {
  final bool isEmbedded;

  const WorkersListScreen({super.key, this.isEmbedded = false});

  @override
  State<WorkersListScreen> createState() => _WorkersListScreenState();
}

class _WorkersListScreenState extends State<WorkersListScreen> {
  List<Account> _workers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAllWorkers();
      }
    });
  }

  Future<void> _loadAllWorkers() async {
    if (!context.mounted) return;
    setState(() => _isLoading = true);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final contractService = Provider.of<ContractService>(
      context,
      listen: false,
    );
    final workerService = Provider.of<WorkerService>(context, listen: false);
    final payrollService = Provider.of<WorkerPayrollService>(
      context,
      listen: false,
    );
    final List<Account> combined = [];

    try {
      combined.addAll(
        await workerService.ensureWorkerAccounts(
          dbService,
          payrollService: payrollService,
          contractService: contractService,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.error(
        context,
        Provider.of<LanguageService>(context, listen: false).isUrdu
            ? 'مزدور لوڈ نہیں ہو سکے'
            : 'Could not load workers',
        subtitle: error.toString(),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _workers = combined;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final Widget bodyContent = SafeArea(
      child: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.slateColor,
                    ),
                  )
                : _workers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.slateColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Icon(
                                PhosphorIcons.users(),
                                size: 32,
                                color: AppTheme.slateColor,
                              ),
                            ),
                            const SizedBox(height: 14),
                            UrduAwareText(
                              isUrdu
                                  ? 'ابھی تک کوئی مزدور شامل نہیں کیا گیا'
                                  : 'No workers found',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.slateColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () =>
                                  _showAddWorkerPicker(context, isUrdu),
                              icon: Icon(PhosphorIcons.userPlus(), size: 16),
                              label: UrduAwareText(
                                isUrdu ? 'نیا مزدور شامل کریں' : 'Add Worker',
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _workers.length,
                        itemBuilder: (context, index) {
                          final worker = _workers[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.lightColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD1D5DB),
                                width: 1.1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    Stack(
                                      children: [
                                        PartyCard(
                                          party: worker,
                                          showCard: false,
                                          margin: EdgeInsets.zero,
                                          onView: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PartyDetailScreen(
                                                  party: worker,
                                                ),
                                              ),
                                            );
                                            _loadAllWorkers();
                                          },
                                          onMessage: () {},
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: PopupMenuButton<String>(
                                            icon: Icon(
                                              PhosphorIcons.dotsThreeVertical(),
                                              size: 18,
                                              color: AppTheme.textSecondary,
                                            ),
                                            onSelected: (val) async {
                                              if (val == 'remove') {
                                                await Provider.of<
                                                    WorkerService>(
                                                  context,
                                                  listen: false,
                                                ).hideFromDirectory(worker.id);
                                                if (!context.mounted) {
                                                  return;
                                                }
                                                AppToast.success(
                                                  context,
                                                  isUrdu
                                                      ? 'مزدور کو لسٹ سے ہٹا دیا گیا'
                                                      : 'Worker removed from directory',
                                                );
                                                _loadAllWorkers();
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              PopupMenuItem(
                                                value: 'remove',
                                                child: UrduAwareText(
                                                  isUrdu
                                                      ? 'مزدور کی لسٹ سے نکالیں'
                                                      : 'Remove from Workers List',
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.expenseColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        10,
                                      ),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _openAttendance(worker),
                                          icon: Icon(
                                            PhosphorIcons.calendarCheck(),
                                            size: 17,
                                            color: AppTheme.slateColor,
                                          ),
                                          label: UrduAwareText(
                                            isUrdu
                                                ? 'حاضری اور اجرت'
                                                : 'Attendance & wages',
                                            style: const TextStyle(
                                              color: AppTheme.slateColor,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
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
    );

    if (widget.isEmbedded) {
      return Directionality(
        textDirection: languageService.textDirection,
        child: ColoredBox(color: AppTheme.backgroundColor, child: bodyContent),
      );
    }

    return Directionality(
      textDirection: languageService.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: ScreenAppBar(
          title: isUrdu ? 'مزدوروں کی فہرست' : 'Workers Directory',
          isUrdu: isUrdu,
          actions: [
            IconButton(
              icon: Icon(PhosphorIcons.userPlus(), color: AppTheme.slateColor),
              onPressed: () => _showAddWorkerPicker(context, isUrdu),
            ),
          ],
        ),
        body: bodyContent,
      ),
    );
  }

  Future<void> _openAttendance(Account worker) async {
    final databaseService = Provider.of<DatabaseService>(
      context,
      listen: false,
    );
    try {
      var workerAccount = databaseService.getAccount(worker.id);
      if (workerAccount == null) {
        for (final account in databaseService.accounts) {
          if (account.name.trim().toLowerCase() ==
              worker.name.trim().toLowerCase()) {
            workerAccount = account;
            break;
          }
        }
      }
      if (workerAccount == null) {
        workerAccount = worker.copyWith(
          accountType: 'worker',
          balanceType: 'Payable',
          initialBalance: 0,
          balance: 0,
        );
        await databaseService.addAccount(workerAccount);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkerAttendanceScreen(worker: workerAccount!),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        Provider.of<LanguageService>(context, listen: false).isUrdu
            ? 'مزدور کا کھاتہ تیار نہیں ہو سکا'
            : 'Could not prepare worker account',
        subtitle: error.toString(),
      );
    }
  }

  Future<void> _showAddWorkerPicker(BuildContext context, bool isUrdu) async {
    final result = await showCustomerPickerSheet(
      context,
      excludedAccountIds: _workers.map((worker) => worker.id).toSet(),
    );
    if (!context.mounted) return;
    if (result?.account != null) {
      final account = result!.account!;
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await Provider.of<WorkerService>(
        context,
        listen: false,
      ).markAccountAsWorker(account, dbService);
      await _loadAllWorkers();
    }
  }

  void _showAddWorkerOptions(
    BuildContext context,
    bool isUrdu,
    String? fontFamily,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.lightColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              isUrdu ? 'نیا مزدور شامل کرنے کا طریقہ' : 'Add Worker Method',
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.darkColor,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.slateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIcons.userPlus(),
                  color: AppTheme.slateColor,
                ),
              ),
              title: UrduAwareText(
                isUrdu ? 'نیا مزدور درج کریں (مینول)' : 'Manual Entry',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AddPartyScreen(initialCategory: 'worker'),
                  ),
                );
                _loadAllWorkers();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIcons.usersThree(),
                  color: AppTheme.themeColor,
                ),
              ),
              title: UrduAwareText(
                isUrdu
                    ? 'موجودہ پارٹیوں میں سے چنیں'
                    : 'Select from Existing Parties',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showPartyListPicker(context, isUrdu, fontFamily);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPartyListPicker(
    BuildContext context,
    bool isUrdu,
    String? fontFamily,
  ) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    final existingIds = _workers.map((w) => w.id).toSet();
    final existingNames =
        _workers.map((w) => w.name.trim().toLowerCase()).toSet();

    final accounts = dbService.accounts.where((a) {
      if (existingIds.contains(a.id)) return false;
      if (existingNames.contains(a.name.trim().toLowerCase())) return false;
      return true;
    }).toList();

    if (accounts.isEmpty) {
      AppToast.warning(
        context,
        isUrdu ? 'کوئی اور پارٹی موجود نہیں ہے' : 'No other parties available',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.lightColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: UrduAwareText(
          isUrdu
              ? 'موجودہ پارٹیوں میں سے منتخب کریں'
              : 'Select from Existing Parties',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.darkColor,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.55,
          child: ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (_, index) {
              final acc = accounts[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ProfileInfoWidget(
                        name: acc.name,
                        phone: acc.phone,
                        profileImage: acc.profileImage,
                        category: acc.profession?.trim().isNotEmpty == true
                            ? acc.profession!.trim()
                            : acc.accountType,
                        address: acc.address,
                        isLarge: false,
                        isCategoryInline: true,
                        categoryColor: Colors.white,
                        isVerticalCategory: false,
                        customSize: 40,
                        borderRadius: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.slateColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await Provider.of<WorkerService>(
                          context,
                          listen: false,
                        ).markAccountAsWorker(acc, dbService);
                        if (!context.mounted) return;
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        AppToast.success(
                          context,
                          isUrdu
                              ? 'مزدور کامیابی سے شامل ہو گیا'
                              : 'Worker added successfully',
                        );
                        _loadAllWorkers();
                      },
                      child: UrduAwareText(
                        isUrdu ? 'منتخب کریں' : 'Select',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
