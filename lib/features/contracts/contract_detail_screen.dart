// lib/features/contracts/contract_detail_screen.dart

import 'package:account_app/features/accounts/add_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/image_gallery_viewer.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/contract_document_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/models/contract_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import '../../core/models/account_model.dart';
import 'add_edit_contract_screen.dart';
import 'package:account_app/core/models/category_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/features/professions/add_project_transaction_screen.dart';
import 'package:account_app/features/professions/categories_management_screen.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:uuid/uuid.dart';

class ContractDetailScreen extends StatefulWidget {
  final String contractId;

  const ContractDetailScreen({super.key, required this.contractId});

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _tabController.animation?.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _manageContractExpenseCategories(
    BuildContext context,
    DatabaseService db,
    bool isUrdu,
  ) async {
    const parentId = 'contract_expenses';
    final categories = db
        .getCategories()
        .where((category) => category.parentId == parentId)
        .toList();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesManagementScreen(
          categories: categories.map((category) => category.name).toList(),
          isUrdu: isUrdu,
          categoryType: ProfessionCategory.general,
          title: isUrdu ? 'ٹھیکہ خرچ کے زمرے' : 'Contract Expense Categories',
          description: isUrdu
              ? 'یہ زمرے صرف ٹھیکے کے اخراجات کے لیے ہیں، پیشوں سے الگ۔'
              : 'These categories are only for contract expenses, separate from professions.',
          useDefaultCategories: false,
          onCategoriesUpdated: (updatedNames) async {
            final currentByName = {
              for (final category in categories)
                category.name.toLowerCase(): category,
            };
            final updatedNamesLower =
                updatedNames.map((name) => name.toLowerCase()).toSet();
            for (final category in categories) {
              if (!updatedNamesLower.contains(category.name.toLowerCase())) {
                await db.deleteCategory(category.id);
              }
            }
            for (final name in updatedNames) {
              if (currentByName.containsKey(name.toLowerCase())) continue;
              final now = DateTime.now();
              await db.addCategory(
                Category(
                  id: 'contract_expense_${const Uuid().v4()}',
                  name: name,
                  type: CategoryType.expense,
                  parentId: parentId,
                  color: '#D97706',
                  icon: 'package',
                  createdAt: now,
                  updatedAt: now,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _confirmStatusChange(
    ContractModel contract,
    ContractService contractService,
    bool isUrdu,
  ) async {
    final completing = contract.status != 'completed';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: UrduAwareText(
          completing
              ? (isUrdu ? 'ٹھیکہ مکمل کریں؟' : 'Complete this contract?')
              : (isUrdu ? 'ٹھیکہ دوبارہ جاری کریں؟' : 'Reopen this contract?'),
        ),
        content: UrduAwareText(
          completing
              ? (isUrdu
                  ? 'کیا اس ٹھیکے کا کام مکمل ہو چکا ہے؟ بقایا رقم الگ رہے گی اور مکمل ہونے کے بعد بھی وصول کی جا سکے گی۔'
                  : 'Is the work complete? Any outstanding balance will remain and can still be collected.')
              : (isUrdu
                  ? 'کیا آپ اس ٹھیکے کو دوبارہ جاری کرنا چاہتے ہیں؟'
                  : 'Do you want to reopen this contract?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: UrduAwareText(isUrdu ? 'واپس' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: UrduAwareText(
              completing
                  ? (isUrdu ? 'کام مکمل ہے' : 'Mark complete')
                  : (isUrdu ? 'دوبارہ جاری کریں' : 'Reopen'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await contractService.updateContract(
        contract.copyWith(status: completing ? 'completed' : 'active'),
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        isUrdu ? 'اسٹیٹس تبدیل نہیں ہو سکا' : 'Could not update status',
        subtitle: error.toString(),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // قسط کا ڈائلاگ
  // ═══════════════════════════════════════════════════════════
  void _showAddPaymentDialog(
    BuildContext context,
    ContractModel contract,
    bool isUrdu, {
    ContractPayment? paymentToEdit,
  }) {
    if (paymentToEdit == null) {
      final party = Provider.of<DatabaseService>(context, listen: false)
          .getAccount(contract.partyId);
      if (party == null) {
        AppToast.error(
          context,
          isUrdu
              ? 'پارٹی کا کھاتہ نہیں ملا'
              : 'Contract party account not found',
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(
            account: party,
            fixedTransactionType: contract.isIncoming ? 'income' : 'expense',
            mode: AddTransactionMode.contractInstallment,
            initialContractId: contract.id,
            initialDescription: contract.title,
          ),
        ),
      );
      return;
    }

    final amountController =
        TextEditingController(text: paymentToEdit?.amount.toString() ?? '');
    final noteController =
        TextEditingController(text: paymentToEdit?.note ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.lightColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: UrduAwareText(
          paymentToEdit == null
              ? (isUrdu ? 'قسط درج کریں' : 'Add Installment')
              : (isUrdu ? 'قسط میں ترمیم کریں' : 'Edit Installment'),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.darkColor,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(
              controller: amountController,
              label: isUrdu ? 'رقم (Rs)' : 'Amount (Rs)',
              isNumber: true,
            ),
            const SizedBox(height: 12),
            _dialogField(
              controller: noteController,
              label: isUrdu ? 'نوٹ / تفصیل' : 'Note',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel',
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final amount = Formatters.tryParseAmount(
                      amountController.text.trim(),
                      allowDecimals: true) ??
                  double.tryParse(amountController.text.trim()) ??
                  0.0;
              if (amount <= 0) {
                AppToast.warning(context,
                    isUrdu ? 'درست رقم درج کریں' : 'Enter a valid amount');
                return;
              }
              final contractService =
                  Provider.of<ContractService>(context, listen: false);
              final dbService =
                  Provider.of<DatabaseService>(context, listen: false);
              try {
                if (paymentToEdit == null) {
                  await contractService.addClientPayment(
                    contractId: contract.id,
                    amount: amount,
                    note: noteController.text.trim(),
                    databaseService: dbService,
                  );
                } else {
                  await contractService.editClientPayment(
                    contractId: contract.id,
                    paymentId: paymentToEdit.id,
                    amount: amount,
                    note: noteController.text.trim(),
                    databaseService: dbService,
                  );
                }
              } catch (error) {
                if (!context.mounted) return;
                AppToast.error(
                  context,
                  isUrdu
                      ? 'قسط محفوظ نہیں ہو سکی'
                      : 'Could not save installment',
                  subtitle: error.toString(),
                );
                return;
              }
              if (!dialogContext.mounted || !context.mounted) return;
              Navigator.pop(dialogContext);
              AppToast.success(
                context,
                paymentToEdit == null
                    ? (isUrdu ? 'قسط شامل ہو گئی' : 'Installment added')
                    : (isUrdu ? 'قسط اپڈیٹ ہو گئی' : 'Installment updated'),
              );
            },
            child: UrduAwareText(
              isUrdu ? 'محفوظ کریں' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      amountController.dispose();
      noteController.dispose();
    });
  }

  void _showDescriptionDialog(BuildContext context, String rawDescription,
      bool isUrdu, String? fontFamily) {
    final lines = rawDescription
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.lightColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(PhosphorIcons.bookOpen(),
                color: AppTheme.slateColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: UrduAwareText(
                isUrdu
                    ? 'کام کی تفصیل (ریڈنگ موڈ)'
                    : 'Work Details (Reading Mode)',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.darkColor,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(lines.length, (index) {
                  final text =
                      lines[index].replaceAll(RegExp(r'^\d+[\.\-\)]\s*'), '');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          '${index + 1}.',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.slateColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: UrduAwareText(
                            text,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontFamily: fontFamily,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkColor,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.slateColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: UrduAwareText(
              isUrdu ? 'بند کریں' : 'Close',
              style: TextStyle(
                  fontFamily: fontFamily, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: AppTheme.darkColor, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.themeColor, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final contractService = Provider.of<ContractService>(context);

    final contract = contractService.contracts.firstWhere(
      (c) => c.id == widget.contractId,
      orElse: () => ContractModel(
        id: '',
        partyId: '',
        partyName: '',
        title: isUrdu ? 'ٹھیکہ نہیں ملا' : 'Contract not found',
        totalAmount: 0,
        startDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (contract.id.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Center(
              child: UrduAwareText(isUrdu ? 'ٹھیکہ موجود نہیں' : 'Not found')),
        ),
      );
    }

    final progress = contract.totalAmount > 0
        ? (contract.totalPaid / contract.totalAmount).clamp(0.0, 1.0)
        : 0.0;

    final dbService = Provider.of<DatabaseService>(context);
    final contractExpenseTransactions = dbService.transactions
        .where((transaction) =>
            transaction.contractId == contract.id &&
            transaction.type == 'expense')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final contractExpenses = contractExpenseTransactions.fold<double>(
      0,
      (total, transaction) => total + transaction.amount,
    );
    Account? partyAccount;
    if (contract.partyId.isNotEmpty) {
      partyAccount = dbService.getAccount(contract.partyId);
    }
    if (partyAccount == null && contract.partyName.isNotEmpty) {
      for (final acc in dbService.accounts) {
        if (acc.name.trim().toLowerCase() ==
            contract.partyName.trim().toLowerCase()) {
          partyAccount = acc;
          break;
        }
      }
    }

    return Directionality(
      textDirection: languageService.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: ScreenAppBar(
          title: contract.title,
          isUrdu: isUrdu,
          actions: [
            if (contract.documents.isNotEmpty)
              IconButton(
                tooltip: isUrdu ? 'معاہدے کی تصاویر' : 'Contract documents',
                icon: const Icon(Icons.attach_file_rounded,
                    color: AppTheme.themeColor),
                onPressed: () async {
                  try {
                    final documentService = ContractDocumentService();
                    final imageUrls = await Future.wait(
                      contract.documents.map(
                        documentService.getDownloadUrl,
                      ),
                    );
                    if (!context.mounted) return;
                    openFullScreenImageGallery(context, imageUrls);
                  } catch (error) {
                    if (!context.mounted) return;
                    AppToast.error(
                      context,
                      isUrdu
                          ? 'معاہدے کی تصاویر نہیں کھل سکیں'
                          : 'Could not open contract images',
                      subtitle: error.toString(),
                    );
                  }
                },
              ),
            PopupMenuButton<String>(
              icon: Icon(
                PhosphorIcons.dotsThreeVertical(),
                color: AppTheme.darkColor,
              ),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddEditContractScreen(contractToEdit: contract),
                    ),
                  );
                } else if (value == 'categories') {
                  _manageContractExpenseCategories(context, dbService, isUrdu);
                } else if (value == 'delete') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: UrduAwareText(
                        isUrdu ? 'ٹھیکہ حذف کریں؟' : 'Delete contract?',
                        style: const TextStyle(color: AppTheme.darkColor),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: UrduAwareText(
                            isUrdu ? 'نہیں' : 'No',
                            style:
                                const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await contractService.deleteContract(
                                contract.id,
                                databaseService: dbService,
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              AppToast.error(
                                context,
                                isUrdu
                                    ? 'ٹھیکہ حذف نہیں ہو سکا'
                                    : 'Could not delete contract',
                                subtitle: error.toString(),
                              );
                              return;
                            }
                            String? documentCleanupError;
                            final documentService = ContractDocumentService();
                            for (final document in contract.documents) {
                              try {
                                await documentService.deleteDocument(document);
                              } catch (error) {
                                documentCleanupError ??= error.toString();
                              }
                            }
                            if (!context.mounted || !ctx.mounted) return;
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            if (documentCleanupError == null) {
                              AppToast.success(
                                context,
                                isUrdu
                                    ? 'ٹھیکہ حذف کر دیا گیا'
                                    : 'Contract deleted',
                              );
                            } else {
                              AppToast.warning(
                                context,
                                isUrdu
                                    ? 'ٹھیکہ حذف ہو گیا مگر کچھ تصاویر کلاؤڈ سے حذف نہیں ہو سکیں'
                                    : 'Contract deleted, but some cloud images could not be removed',
                                subtitle: documentCleanupError,
                              );
                            }
                          },
                          child: UrduAwareText(
                            isUrdu ? 'ہاں' : 'Yes',
                            style:
                                const TextStyle(color: AppTheme.expenseColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.pencilSimple(),
                          size: 18, color: AppTheme.themeColor),
                      const SizedBox(width: 10),
                      UrduAwareText(
                        isUrdu ? 'ترمیم کریں' : 'Edit',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkColor,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'categories',
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.gear(),
                          size: 18, color: AppTheme.themeColor),
                      const SizedBox(width: 10),
                      UrduAwareText(
                        isUrdu ? 'خرچ کے زمرے' : 'Expense Categories',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkColor,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.trash(),
                          size: 18, color: AppTheme.expenseColor),
                      const SizedBox(width: 10),
                      UrduAwareText(
                        isUrdu ? 'حذف کریں' : 'Delete',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.expenseColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ═══ سالڈ گولڈ خلاصہ کارڈ (بغیر تفصیل کے) ═══
              Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.slateColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.slateColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Profile Info Widget (Picture, Name, Phone & Address)
                    ProfileInfoWidget(
                      name: contract.partyName.isNotEmpty
                          ? contract.partyName
                          : (isUrdu ? 'کوئی پارٹی نہیں' : 'No party'),
                      phone: partyAccount?.phone ?? '',
                      profileImage: partyAccount?.profileImage,
                      category: partyAccount?.category ??
                          (contract.isIncoming
                              ? (isUrdu ? 'مالک / کلائنٹ' : 'Client')
                              : (isUrdu ? 'ٹھیکیدار' : 'Contractor')),
                      address: partyAccount?.address ?? '',
                      textColor: Colors.white,
                      subtitleColor: Colors.white70,
                      categoryColor: Colors.white70,
                      customSize: 42,
                      borderRadius: 8,
                      suffix: GestureDetector(
                        onTap: () => _confirmStatusChange(
                            contract, contractService, isUrdu),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: UrduAwareText(
                            contract.status == 'active'
                                ? (isUrdu ? 'جاری' : 'Active')
                                : (isUrdu ? 'مکمل' : 'Done'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // کل رقم (بغیر لیبل کے)
                    UrduAwareText(
                      Formatters.formatAmountWithCurrency(contract.totalAmount),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // پروگریس بار
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ادا اور بقیہ رقم
                    Row(
                      children: [
                        Expanded(
                          child: UrduAwareText(
                            isUrdu
                                ? 'ادا: ${Formatters.formatAmountWithCurrency(contract.totalPaid)}'
                                : 'Paid: ${Formatters.formatAmountWithCurrency(contract.totalPaid)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              fontFamily: fontFamily,
                              color: Colors.white.withValues(alpha: 0.95),
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
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            fontFamily: fontFamily,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),

                    // اگر ٹھیکہ لیا ہو (isIncoming) تو مزدوری اور منافع
                    if (contract.isIncoming) ...[
                      const SizedBox(height: 10),
                      Divider(
                          color: Colors.white.withValues(alpha: 0.2),
                          height: 1),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          UrduAwareText(
                            isUrdu ? 'مزدوری:' : 'Labor:',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: fontFamily,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 6),
                          UrduAwareText(
                            Formatters.formatAmountWithCurrency(
                                contract.totalLaborPaid),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          UrduAwareText(
                            isUrdu ? 'مواد:' : 'Materials:',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: fontFamily,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 6),
                          UrduAwareText(
                            Formatters.formatAmountWithCurrency(
                                contractExpenses),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Spacer(),
                          UrduAwareText(
                            isUrdu ? 'منافع:' : 'Profit:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: fontFamily,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 6),
                          UrduAwareText(
                            Formatters.formatAmountWithCurrency(
                                contract.netProfit - contractExpenses),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ═══ ٹیبز بار + تفصیل کا بٹن (ایک لائن میں تین بٹن) ═══
              if (contract.isIncoming)
                Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.lightColor,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                    border:
                        Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      // Tab 1: قسطیں
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _tabController.animateTo(0)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: contract.isIncoming &&
                                      _tabController.index == 0
                                  ? AppTheme.slateColor
                                  : (!contract.isIncoming
                                      ? AppTheme.slateColor
                                      : Colors.transparent),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                UrduAwareText(
                                  isUrdu ? 'قسطیں' : 'Payments',
                                  style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: (contract.isIncoming &&
                                                _tabController.index == 0) ||
                                            !contract.isIncoming
                                        ? Colors.white
                                        : AppTheme.darkColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (contract.isIncoming &&
                                                _tabController.index == 0) ||
                                            !contract.isIncoming
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : AppTheme.slateColor
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: UrduAwareText(
                                    '${contract.payments.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: (contract.isIncoming &&
                                                  _tabController.index == 0) ||
                                              !contract.isIncoming
                                          ? Colors.white
                                          : AppTheme.slateColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Tab 2: مزدوری (صرف incoming کے لیے)
                      if (contract.isIncoming) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _tabController.animateTo(1)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _tabController.index == 1
                                    ? AppTheme.slateColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  UrduAwareText(
                                    isUrdu ? 'مزدوری' : 'Labor',
                                    style: TextStyle(
                                      fontFamily: fontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _tabController.index == 1
                                          ? Colors.white
                                          : AppTheme.darkColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _tabController.index == 1
                                          ? Colors.white.withValues(alpha: 0.3)
                                          : AppTheme.slateColor
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: UrduAwareText(
                                      '${contract.laborPayments.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _tabController.index == 1
                                            ? Colors.white
                                            : AppTheme.slateColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Tab 3: ٹھیکے کے اخراجات
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _tabController.animateTo(2)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _tabController.index == 2
                                  ? AppTheme.slateColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                UrduAwareText(
                                  isUrdu ? 'خرچ' : 'Expenses',
                                  style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _tabController.index == 2
                                        ? Colors.white
                                        : AppTheme.darkColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _tabController.index == 2
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : AppTheme.slateColor
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: UrduAwareText(
                                    '${contractExpenseTransactions.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _tabController.index == 2
                                          ? Colors.white
                                          : AppTheme.slateColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Button 4: کام کی تفصیل (اگر موجود ہو)
                      if (contract.description.trim().isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showDescriptionDialog(context,
                                contract.description, isUrdu, fontFamily),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.themeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(PhosphorIcons.bookOpen(),
                                      size: 14, color: AppTheme.themeColor),
                                  const SizedBox(width: 4),
                                  UrduAwareText(
                                    isUrdu ? 'تفصیل' : 'Details',
                                    style: TextStyle(
                                      fontFamily: fontFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.themeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // اگر آؤٹ گوئنگ (ٹھیکہ دیا) ہو تو قسط کا بار
              if (!contract.isIncoming)
                Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.lightColor,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                    border:
                        Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.slateColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              UrduAwareText(
                                isUrdu ? 'قسطیں' : 'Payments',
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: UrduAwareText(
                                  '${contract.payments.length}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: contract.isIncoming
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _buildClientPaymentsList(
                              contract, isUrdu, fontFamily),
                          _buildLaborPaymentsList(contract, isUrdu, fontFamily),
                          _buildContractExpensesList(
                            contract,
                            contractExpenseTransactions,
                            isUrdu,
                            fontFamily,
                          ),
                        ],
                      )
                    : _buildClientPaymentsList(contract, isUrdu, fontFamily),
              ),
            ],
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (contract.isIncoming && _tabController.index == 2)
              FloatingActionButton(
                heroTag: 'contractExpenseTab-${contract.id}',
                onPressed: () => _openContractExpenseScreen(contract),
                backgroundColor: AppTheme.expenseColor,
                shape: const CircleBorder(),
                child: Icon(
                  PhosphorIcons.plus(),
                  color: Colors.white,
                ),
              ),
            if (!contract.isIncoming || _tabController.index == 0)
              FloatingActionButton(
                heroTag: 'contractInstallment-${contract.id}',
                onPressed: () =>
                    _showAddPaymentDialog(context, contract, isUrdu),
                backgroundColor: AppTheme.slateColor,
                shape: const CircleBorder(),
                child: Icon(
                  PhosphorIcons.plus(),
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openContractExpenseScreen(ContractModel contract,
      {Transaction? transactionToEdit}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProjectTransactionScreen(
          contract: contract,
          transactionToEdit: transactionToEdit,
        ),
      ),
    );
  }

  Widget _buildContractExpensesList(
    ContractModel contract,
    List<Transaction> expenses,
    bool isUrdu,
    String? fontFamily,
  ) {
    if (expenses.isEmpty) {
      return _emptyState(
        icon: PhosphorIcons.receipt(),
        text: isUrdu
            ? 'ابھی تک کوئی خرچ درج نہیں کیا گیا'
            : 'No expenses recorded yet',
        fontFamily: fontFamily,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.lightColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            final category = expense.category.startsWith('EXP:')
                ? expense.category.substring(4)
                : expense.category;
            final description = expense.description;

            final primaryTitle =
                description.isNotEmpty ? description : category;
            final secondaryInfo =
                description.isNotEmpty && category.isNotEmpty ? category : '';

            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minVerticalPadding: 0,
                    onLongPress: () => _showExpenseOptions(
                        context, contract, expense, isUrdu, fontFamily),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.expenseColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        PhosphorIcons.receipt(),
                        size: 18,
                        color: AppTheme.expenseColor,
                      ),
                    ),
                    title: UrduAwareText(
                      primaryTitle,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.darkColor,
                      ),
                    ),
                    subtitle: secondaryInfo.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: UrduAwareText(
                              secondaryInfo,
                              style: TextStyle(
                                color: AppTheme.purpleColor,
                                fontSize: 11,
                                fontFamily: fontFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        UrduAwareText(
                          Formatters.formatAmountWithCurrency(expense.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: AppTheme.expenseColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        UrduAwareText(
                          Formatters.formatDate(expense.date),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index != expenses.length - 1)
                  const Divider(
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                    thickness: 0.5,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showExpenseOptions(
    BuildContext context,
    ContractModel contract,
    Transaction expense,
    bool isUrdu,
    String? fontFamily,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.lightColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(PhosphorIcons.pencilSimple(),
                    color: AppTheme.themeColor),
                title: UrduAwareText(
                  isUrdu ? 'ترمیم کریں' : 'Edit',
                  style: TextStyle(
                      fontFamily: fontFamily, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openContractExpenseScreen(contract,
                      transactionToEdit: expense);
                },
              ),
              ListTile(
                leading:
                    Icon(PhosphorIcons.trash(), color: AppTheme.expenseColor),
                title: UrduAwareText(
                  isUrdu ? 'حذف کریں' : 'Delete',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.expenseColor),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteContractExpense(expense, isUrdu);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentOptions(
    BuildContext context,
    ContractModel contract,
    ContractPayment p,
    bool isUrdu,
    String? fontFamily,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.lightColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(PhosphorIcons.pencilSimple(),
                    color: AppTheme.themeColor),
                title: UrduAwareText(
                  isUrdu ? 'ترمیم کریں' : 'Edit',
                  style: TextStyle(
                      fontFamily: fontFamily, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddPaymentDialog(context, contract, isUrdu,
                      paymentToEdit: p);
                },
              ),
              ListTile(
                leading:
                    Icon(PhosphorIcons.trash(), color: AppTheme.expenseColor),
                title: UrduAwareText(
                  isUrdu ? 'حذف کریں' : 'Delete',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.expenseColor),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteClientPayment(context, contract, p, isUrdu);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteContractExpense(
      Transaction expense, bool isUrdu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: UrduAwareText(
          isUrdu ? 'خرچ حذف کریں؟' : 'Delete expense?',
        ),
        content: UrduAwareText(
          isUrdu
              ? 'یہ خرچ اور اس کی رقم ٹھیکے کے حساب سے ہٹا دی جائے گی۔'
              : 'This expense will be removed from the contract totals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: UrduAwareText(
              isUrdu ? 'حذف کریں' : 'Delete',
              style: const TextStyle(color: AppTheme.expenseColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await Provider.of<DatabaseService>(context, listen: false)
          .deleteTransaction(expense.id);
      if (!mounted) return;
      AppToast.success(
        context,
        isUrdu ? 'خرچ حذف کر دیا گیا' : 'Expense deleted',
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        isUrdu ? 'خرچ حذف نہیں ہو سکا' : 'Could not delete expense',
        subtitle: error.toString(),
      );
    }
  }

  Widget _buildClientPaymentsList(
      ContractModel contract, bool isUrdu, String? fontFamily) {
    if (contract.payments.isEmpty) {
      return _emptyState(
        icon: PhosphorIcons.receipt(),
        text: contract.isIncoming
            ? (isUrdu
                ? 'ابھی تک کوئی وصولی درج نہیں کی گئی'
                : 'No receipts recorded yet')
            : (isUrdu
                ? 'ابھی تک کوئی ادائیگی درج نہیں کی گئی'
                : 'No payments recorded yet'),
        fontFamily: fontFamily,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.lightColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: contract.payments.length,
          itemBuilder: (context, i) {
            final p = contract.payments[i];
            return _buildClientPaymentItem(
              context,
              contract,
              p,
              isUrdu,
              fontFamily,
              isLast: i == contract.payments.length - 1,
            );
          },
        ),
      ),
    );
  }

  Widget _buildClientPaymentItem(
    BuildContext context,
    ContractModel contract,
    ContractPayment p,
    bool isUrdu,
    String? fontFamily, {
    bool isLast = false,
  }) {
    final hasCustomNote = p.note.isNotEmpty && p.note != 'Contract Installment';
    final primaryTitle = hasCustomNote
        ? p.note
        : (contract.isIncoming
            ? (isUrdu ? 'وصولی' : 'Receipt')
            : (isUrdu ? 'ادائیگی' : 'Payment'));

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minVerticalPadding: 0,
            onLongPress: () =>
                _showPaymentOptions(context, contract, p, isUrdu, fontFamily),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (contract.isIncoming
                        ? AppTheme.incomeColor
                        : AppTheme.themeColor)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                contract.isIncoming
                    ? PhosphorIcons.arrowDownLeft()
                    : PhosphorIcons.arrowUpRight(),
                size: 18,
                color: contract.isIncoming
                    ? AppTheme.incomeColor
                    : AppTheme.themeColor,
              ),
            ),
            title: UrduAwareText(
              primaryTitle,
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.darkColor,
              ),
            ),
            subtitle: contract.partyName.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: UrduAwareText(
                      contract.partyName,
                      style: TextStyle(
                        color: AppTheme.themeColor,
                        fontSize: 11,
                        fontFamily: fontFamily,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                UrduAwareText(
                  Formatters.formatAmountWithCurrency(p.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: contract.isIncoming
                        ? AppTheme.incomeColor
                        : AppTheme.darkColor,
                  ),
                ),
                const SizedBox(height: 2),
                UrduAwareText(
                  Formatters.formatDate(p.date),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 12, endIndent: 12, thickness: 0.5),
      ],
    );
  }

  void _confirmDeleteClientPayment(
    BuildContext context,
    ContractModel contract,
    ContractPayment payment,
    bool isUrdu,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: UrduAwareText(isUrdu ? 'قسط حذف کریں؟' : 'Delete installment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: UrduAwareText(isUrdu ? 'نہیں' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final contractService =
                  Provider.of<ContractService>(context, listen: false);
              final databaseService =
                  Provider.of<DatabaseService>(context, listen: false);
              try {
                await contractService.deleteClientPayment(
                  contractId: contract.id,
                  paymentId: payment.id,
                  databaseService: databaseService,
                );
              } catch (error) {
                if (!context.mounted) return;
                AppToast.error(
                  context,
                  isUrdu
                      ? 'قسط حذف نہیں ہو سکی'
                      : 'Could not delete installment',
                  subtitle: error.toString(),
                );
                return;
              }
              if (!dialogContext.mounted || !context.mounted) return;
              Navigator.pop(dialogContext);
              AppToast.success(context,
                  isUrdu ? 'قسط حذف کر دی گئی' : 'Installment deleted');
            },
            child: UrduAwareText(
              isUrdu ? 'ہاں' : 'Delete',
              style: const TextStyle(color: AppTheme.expenseColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaborPaymentsList(
      ContractModel contract, bool isUrdu, String? fontFamily) {
    if (contract.laborPayments.isEmpty) {
      return _emptyState(
        icon: PhosphorIcons.users(),
        text: isUrdu
            ? 'مزدوروں کو ابھی تک کوئی ادائیگی نہیں کی گئی'
            : 'No labor wages paid yet',
        fontFamily: fontFamily,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.lightColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: contract.laborPayments.length,
          itemBuilder: (context, i) {
            final p = contract.laborPayments[i];
            return _buildLaborPaymentItem(
              context,
              contract,
              p,
              isUrdu,
              fontFamily,
              isLast: i == contract.laborPayments.length - 1,
            );
          },
        ),
      ),
    );
  }

  Widget _buildLaborPaymentItem(
    BuildContext context,
    ContractModel contract,
    ContractLaborPayment p,
    bool isUrdu,
    String? fontFamily, {
    bool isLast = false,
  }) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final workerAccount =
        p.workerId != null ? dbService.getAccount(p.workerId!) : null;

    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minVerticalPadding: 0,
          leading: SizedBox(
            width: 36,
            height: 36,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ProfileInfoWidget(
                name: p.workerName,
                phone: workerAccount?.phone ?? '',
                profileImage: workerAccount?.profileImage,
                category: workerAccount?.category,
                customSize: 36,
                borderRadius: 8,
                showText: false,
              ),
            ),
          ),
          title: UrduAwareText(
            p.workerName,
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.darkColor,
            ),
          ),
          subtitle: p.note.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: UrduAwareText(
                    p.note,
                    style: TextStyle(
                      color: AppTheme.purpleColor,
                      fontSize: 11,
                      fontFamily: fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UrduAwareText(
                Formatters.formatAmountWithCurrency(p.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: AppTheme.expenseColor,
                ),
              ),
              const SizedBox(height: 2),
              UrduAwareText(
                Formatters.formatDate(p.date),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 12, endIndent: 12, thickness: 0.5),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String text,
    String? fontFamily,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 28, color: AppTheme.themeColor),
          ),
          const SizedBox(height: 12),
          UrduAwareText(
            text,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
