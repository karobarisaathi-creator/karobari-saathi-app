// lib/features/contracts/contracts_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/models/contract_model.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'add_edit_contract_screen.dart';
import 'contract_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════
// مقامی رنگ — AppTheme تھیم فائل سے ماخوذ
// ═══════════════════════════════════════════════════════════════
class _C {
  static const bg = AppTheme.backgroundColor;
  static const card = AppTheme.lightColor;
  static const border = Color(0xFFD1D5DB);
  static const accent = AppTheme.themeColor;
  static final accentSoft = AppTheme.themeColor.withValues(alpha: 0.1);
  static const textPrimary = AppTheme.darkColor;
  static const textSecondary = AppTheme.textSecondary;
  static const success = AppTheme.incomeColor;
  static const danger = AppTheme.expenseColor;
}

class ContractsListScreen extends StatefulWidget {
  const ContractsListScreen({super.key});

  @override
  State<ContractsListScreen> createState() => _ContractsListScreenState();
}

class _ContractsListScreenState extends State<ContractsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final contractService = Provider.of<ContractService>(context);
    final contracts = contractService.contracts;

    final ongoingContracts =
        contracts.where((c) => c.status != 'completed').toList();
    final completedContracts =
        contracts.where((c) => c.status == 'completed').toList();

    return Directionality(
      textDirection: languageService.textDirection,
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: ScreenAppBar(
          title: isUrdu ? 'ٹھیکے' : 'Contracts',
          isUrdu: isUrdu,
          showBackButton: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Sliding Button Toggle Strip
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.slateColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // Tab 0: Ongoing ("جاری ٹھیکہ")
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _tabController.animateTo(0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabController.index == 0
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _tabController.index == 0
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.12),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: UrduAwareText(
                                isUrdu ? 'جاری ٹھیکہ' : 'Ongoing',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: fontFamily,
                                  color: _tabController.index == 0
                                      ? AppTheme.themeColor
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Tab 1: Completed ("مکمل ٹھیکہ")
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _tabController.animateTo(1);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabController.index == 1
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _tabController.index == 1
                                  ? [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.12),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: UrduAwareText(
                                isUrdu ? 'مکمل ٹھیکہ' : 'Completed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: fontFamily,
                                  color: _tabController.index == 1
                                      ? AppTheme.incomeColor
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: contractService.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _C.accent))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildContractsList(
                              ongoingContracts, isUrdu, fontFamily),
                          _buildContractsList(
                              completedContracts, isUrdu, fontFamily),
                        ],
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'contractsAdd',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddEditContractScreen(),
              ),
            );
          },
          backgroundColor: AppTheme.slateColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: UrduAwareText(
            isUrdu ? 'نیا ٹھیکہ' : 'New Contract',
            style: TextStyle(
              fontFamily: fontFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContractsList(
      List<ContractModel> list, bool isUrdu, String? fontFamily) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _C.accentSoft,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(PhosphorIcons.fileText(), size: 40, color: _C.accent),
            ),
            const SizedBox(height: 16),
            UrduAwareText(
              isUrdu ? 'کوئی ٹھیکہ موجود نہیں' : 'No contracts found',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _C.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final contract = list[i];
        final progress = contract.totalAmount > 0
            ? (contract.totalPaid / contract.totalAmount).clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContractDetailScreen(contractId: contract.id),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: contract.isIncoming
                            ? _C.success.withValues(alpha: 0.12)
                            : _C.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            contract.isIncoming
                                ? PhosphorIcons.arrowDownLeft()
                                : PhosphorIcons.arrowUpRight(),
                            size: 12,
                            color: contract.isIncoming ? _C.success : _C.danger,
                          ),
                          const SizedBox(width: 4),
                          UrduAwareText(
                            contract.isIncoming
                                ? (isUrdu ? 'ٹھیکہ لیا' : 'Incoming')
                                : (isUrdu ? 'ٹھیکہ دیا' : 'Outgoing'),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  contract.isIncoming ? _C.success : _C.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    UrduAwareText(
                      Formatters.formatAmountWithCurrency(contract.totalAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _C.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                UrduAwareText(
                  contract.title,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _C.textPrimary,
                  ),
                ),
                if (contract.partyName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  UrduAwareText(
                    '👤 ${contract.partyName}',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: UrduAwareText(
                        isUrdu
                            ? 'ادا شدہ: ${Formatters.formatAmountWithCurrency(contract.totalPaid)}'
                            : 'Paid: ${Formatters.formatAmountWithCurrency(contract.totalPaid)}',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _C.success,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    UrduAwareText(
                      isUrdu
                          ? 'بقیہ: ${Formatters.formatAmountWithCurrency(contract.remainingBalance)}'
                          : 'Due: ${Formatters.formatAmountWithCurrency(contract.remainingBalance)}',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: _C.border,
                    valueColor: AlwaysStoppedAnimation(
                      contract.status == 'completed' ? _C.success : _C.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
