// lib/features/contracts/contract_detail_screen.dart

import 'package:account_app/features/contracts/workers_list_screen.dart';
import 'package:account_app/features/contracts/worker_attendance_screen.dart';
import 'package:account_app/features/contracts/contract_documents_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/contract_document_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/models/contract_model.dart';
import 'add_edit_contract_screen.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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

  void _showAddLaborPaymentDialog(
      BuildContext context, ContractModel contract, bool isUrdu,
      {ContractLaborPayment? paymentToEdit}) {
    final amountController = TextEditingController(
        text: paymentToEdit != null ? paymentToEdit.amount.toString() : '');
    final noteController = TextEditingController(
        text: paymentToEdit != null ? paymentToEdit.note : '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dbService = Provider.of<DatabaseService>(dialogContext);
        final contractService =
            Provider.of<ContractService>(dialogContext, listen: false);

        final contractWorkerNames = <String>{};
        for (var c in contractService.contracts) {
          for (var lp in c.laborPayments) {
            if (lp.workerName.trim().isNotEmpty) {
              contractWorkerNames.add(lp.workerName.trim().toLowerCase());
            }
          }
        }

        final workers = dbService.accounts.where((a) {
          final isWorkerCat = a.category == 'worker' ||
              a.category == 'technician' ||
              a.category == 'employee';
          bool isSelectedInContract = false;
          for (var cwName in contractWorkerNames) {
            if (a.name.trim().toLowerCase().contains(cwName) ||
                cwName.contains(a.name.trim().toLowerCase()) ||
                (a.phone.isNotEmpty && cwName.contains(a.phone))) {
              isSelectedInContract = true;
              break;
            }
          }
          return isWorkerCat || isSelectedInContract;
        }).toList();

        return AlertDialog(
          backgroundColor: AppTheme.lightColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Expanded(
                child: UrduAwareText(
                  paymentToEdit == null
                      ? (isUrdu ? 'مزدور کی اجرت درج کریں' : 'Add Labor Wage')
                      : (isUrdu
                          ? 'مزدوری کی اجرت میں ترمیم کریں'
                          : 'Edit Labor Wage'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(PhosphorIcons.users(),
                    color: AppTheme.goldColor, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkersListScreen(),
                    ),
                  );
                },
                tooltip: isUrdu ? 'مزدوروں کی ڈائریکٹری' : 'Workers Directory',
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Column(
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
                  const SizedBox(height: 16),
                  Align(
                    alignment:
                        isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                    child: UrduAwareText(
                      paymentToEdit == null
                          ? (isUrdu
                              ? 'مزدور منتخب کریں (کارڈ پر ٹیپ کریں):'
                              : 'Tap worker card to pay:')
                          : (isUrdu
                              ? 'مزدور منتخب کریں (یا تبدیل کریں):'
                              : 'Select worker to update:'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary),
                    ),
                  ),
                  if (paymentToEdit != null) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment:
                          isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                      child: UrduAwareText(
                        'موجودہ مزدور: ${paymentToEdit.workerName}',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.goldColor),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  workers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: UrduAwareText(
                            isUrdu
                                ? 'کوئی مزدور موجود نہیں'
                                : 'No workers found',
                            style:
                                const TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: workers.length,
                            itemBuilder: (_, index) {
                              final w = workers[index];
                              final isSelected =
                                  paymentToEdit?.workerName == w.name;
                              return InkWell(
                                onTap: () async {
                                  final amount = Formatters.tryParseAmount(
                                          amountController.text.trim(),
                                          allowDecimals: true) ??
                                      double.tryParse(
                                          amountController.text.trim()) ??
                                      0.0;
                                  if (amount <= 0) {
                                    AppToast.warning(
                                      context,
                                      isUrdu
                                          ? 'پہلے درست رقم درج کریں'
                                          : 'Enter a valid amount first',
                                    );
                                    return;
                                  }

                                  try {
                                    if (paymentToEdit == null) {
                                      await contractService.addLaborPayment(
                                        contractId: contract.id,
                                        workerName: w.name,
                                        amount: amount,
                                        note: noteController.text.trim(),
                                        databaseService: dbService,
                                      );
                                    } else {
                                      await contractService.editLaborPayment(
                                        contractId: contract.id,
                                        paymentId: paymentToEdit.id,
                                        workerName: w.name,
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
                                          ? 'مزدوری محفوظ نہیں ہو سکی'
                                          : 'Could not save labor payment',
                                      subtitle: error.toString(),
                                    );
                                    return;
                                  }
                                  if (!dialogContext.mounted ||
                                      !context.mounted) {
                                    return;
                                  }
                                  Navigator.pop(dialogContext);
                                  AppToast.success(
                                    context,
                                    paymentToEdit == null
                                        ? (isUrdu
                                            ? '${w.name} کو اجرت ادا کر دی گئی'
                                            : 'Wage paid to ${w.name}')
                                        : (isUrdu
                                            ? 'مزدوری کی اجرت اپڈیٹ ہو گئی'
                                            : 'Labor payment updated'),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.goldColor
                                            .withValues(alpha: 0.15)
                                        : AppTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: isSelected
                                            ? AppTheme.goldColor
                                            : const Color(0xFFD1D5DB)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ProfileInfoWidget(
                                          name: w.name,
                                          phone: w.phone,
                                          profileImage: w.profileImage,
                                          category: w.category,
                                          address: w.address,
                                          isLarge: false,
                                          isVerticalCategory: false,
                                          customSize: 36,
                                          borderRadius: 8,
                                        ),
                                      ),
                                      const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: AppTheme.goldColor),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: UrduAwareText(isUrdu ? 'بند کریں' : 'Cancel',
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        );
      },
    );
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
            Icon(PhosphorIcons.bookOpen(), color: AppTheme.goldColor, size: 22),
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
                            color: AppTheme.goldColor,
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
              backgroundColor: AppTheme.goldColor,
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

    return Directionality(
      textDirection: languageService.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── ٹاپ ہینڈر بار (ایپ بار کے بغیر) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isUrdu
                            ? PhosphorIcons.arrowRight()
                            : PhosphorIcons.arrowLeft(),
                        color: AppTheme.darkColor,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: isUrdu ? 'پیچھے جائیں' : 'Back',
                    ),
                    Expanded(
                      child: UrduAwareText(
                        contract.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: fontFamily,
                          color: AppTheme.darkColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (contract.documents.isNotEmpty)
                      IconButton(
                        tooltip:
                            isUrdu ? 'معاہدے کی تصاویر' : 'Contract documents',
                        icon: const Icon(Icons.attach_file_rounded,
                            color: AppTheme.themeColor),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContractDocumentsScreen(
                                contractTitle: contract.title,
                                documents: contract.documents,
                                isUrdu: isUrdu,
                              ),
                            ),
                          );
                        },
                      ),
                    PopupMenuButton<String>(
                      icon: Icon(PhosphorIcons.dotsThreeVertical(),
                          color: AppTheme.darkColor),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditContractScreen(
                                  contractToEdit: contract),
                            ),
                          );
                        } else if (value == 'delete') {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: UrduAwareText(
                                isUrdu ? 'ٹھیکہ حذف کریں؟' : 'Delete contract?',
                                style:
                                    const TextStyle(color: AppTheme.darkColor),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: UrduAwareText(isUrdu ? 'نہیں' : 'No',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary)),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await contractService.deleteContract(
                                        contract.id,
                                        databaseService:
                                            Provider.of<DatabaseService>(
                                                context,
                                                listen: false),
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
                                    final documentService =
                                        ContractDocumentService();
                                    for (final document in contract.documents) {
                                      try {
                                        await documentService
                                            .deleteDocument(document);
                                      } catch (error) {
                                        documentCleanupError ??=
                                            error.toString();
                                      }
                                    }
                                    if (!context.mounted || !ctx.mounted) {
                                      return;
                                    }
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
                                  child: UrduAwareText(isUrdu ? 'ہاں' : 'Yes',
                                      style: const TextStyle(
                                          color: AppTheme.expenseColor)),
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
              ),

              // ═══ سالڈ گولڈ خلاصہ کارڈ (بغیر تفصیل کے) ═══
              Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.goldColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.goldColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // پارٹی کا نام + اسٹیٹس بیج
                    Row(
                      children: [
                        Expanded(
                          child: UrduAwareText(
                            contract.partyName.isNotEmpty
                                ? '👤 ${contract.partyName}'
                                : (isUrdu ? 'کوئی پارٹی نہیں' : 'No party'),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
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
                      ],
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
                              fontSize: 11.5,
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
                            isUrdu ? 'منافع:' : 'Profit:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: fontFamily,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 6),
                          UrduAwareText(
                            Formatters.formatAmountWithCurrency(
                                contract.netProfit),
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
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
                                  ? AppTheme.goldColor
                                  : (!contract.isIncoming
                                      ? AppTheme.goldColor
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
                                        : AppTheme.goldColor
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
                                          : AppTheme.goldColor,
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
                                    ? AppTheme.goldColor
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
                                          : AppTheme.goldColor
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
                                            : AppTheme.goldColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Button 3: کام کی تفصیل (اگر موجود ہو)
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

              // اگر آؤٹ گوئنگ (ٹھیکہ دیا) ہو تو قسط اور تفصیل کا بار
              if (!contract.isIncoming)
                Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
                            color: AppTheme.goldColor,
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
              const SizedBox(height: 8),

              Expanded(
                child: contract.isIncoming
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _buildClientPaymentsList(
                              contract, isUrdu, fontFamily),
                          _buildLaborPaymentsList(contract, isUrdu, fontFamily),
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
            if (!contract.isIncoming || _tabController.index == 0)
              FloatingActionButton.extended(
                heroTag: 'client',
                onPressed: () =>
                    _showAddPaymentDialog(context, contract, isUrdu),
                backgroundColor: AppTheme.themeColor,
                foregroundColor: Colors.white,
                icon: Icon(PhosphorIcons.cardholder(), color: Colors.white),
                label: UrduAwareText(
                  isUrdu ? 'قسط' : 'Installment',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientPaymentsList(
      ContractModel contract, bool isUrdu, String? fontFamily) {
    if (contract.payments.isEmpty) {
      return _emptyState(
        icon: PhosphorIcons.receipt(),
        text: isUrdu
            ? 'ابھی تک کوئی قسط درج نہیں کی گئی'
            : 'No installments recorded yet',
        fontFamily: fontFamily,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 100),
      itemCount: contract.payments.length,
      itemBuilder: (context, i) {
        final p = contract.payments[i];
        return _buildClientPaymentItem(
            context, contract, p, isUrdu, fontFamily);
      },
    );
  }

  Widget _buildClientPaymentItem(
    BuildContext context,
    ContractModel contract,
    ContractPayment p,
    bool isUrdu,
    String? fontFamily,
  ) {
    final hasCustomNote = p.note.isNotEmpty && p.note != 'Contract Installment';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.incomeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(PhosphorIcons.arrowDown(),
                size: 18, color: AppTheme.incomeColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: UrduAwareText(
              hasCustomNote
                  ? p.note
                  : (isUrdu ? 'قسط ادائیگی' : 'Installment Payment'),
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppTheme.darkColor,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UrduAwareText(
                Formatters.formatAmountWithCurrency(p.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppTheme.incomeColor,
                ),
              ),
              const SizedBox(height: 2),
              UrduAwareText(
                Formatters.formatDate(p.date),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(PhosphorIcons.dotsThreeVertical(),
                size: 18, color: AppTheme.textSecondary),
            onSelected: (value) {
              if (value == 'edit') {
                _showAddPaymentDialog(
                  context,
                  contract,
                  isUrdu,
                  paymentToEdit: p,
                );
              } else if (value == 'delete') {
                _confirmDeleteClientPayment(context, contract, p, isUrdu);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: UrduAwareText(isUrdu ? 'ترمیم کریں' : 'Edit'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: UrduAwareText(
                  isUrdu ? 'حذف کریں' : 'Delete',
                  style: const TextStyle(color: AppTheme.expenseColor),
                ),
              ),
            ],
          ),
        ],
      ),
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 100),
      itemCount: contract.laborPayments.length,
      itemBuilder: (context, i) {
        final p = contract.laborPayments[i];
        return _buildLaborPaymentItem(context, contract, p, isUrdu, fontFamily);
      },
    );
  }

  Widget _buildLaborPaymentItem(BuildContext context, ContractModel contract,
      ContractLaborPayment p, bool isUrdu, String? fontFamily) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.goldColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(PhosphorIcons.userGear(),
                size: 18, color: AppTheme.goldColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  p.workerName,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppTheme.darkColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  UrduAwareText(
                    p.note,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (p.workerPayrollPaymentId != null) ...[
                  const SizedBox(height: 4),
                  UrduAwareText(
                    isUrdu
                        ? 'حاضری و اجرت کے ریکارڈ سے منسلک'
                        : 'Linked to attendance & payroll',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              UrduAwareText(
                Formatters.formatAmountWithCurrency(p.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppTheme.goldColor,
                ),
              ),
              const SizedBox(height: 2),
              UrduAwareText(
                Formatters.formatDate(p.date),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary),
              ),
            ],
          ),
          if (p.workerPayrollPaymentId != null && p.workerId != null)
            IconButton(
              tooltip: isUrdu
                  ? 'حاضری و اجرت میں دیکھیں'
                  : 'Open attendance & payroll',
              icon: Icon(PhosphorIcons.arrowSquareOut(),
                  size: 18, color: AppTheme.themeColor),
              onPressed: () {
                final worker =
                    Provider.of<DatabaseService>(context, listen: false)
                        .getAccount(p.workerId!);
                if (worker == null) {
                  AppToast.error(
                    context,
                    isUrdu
                        ? 'مزدور کا اکاؤنٹ نہیں ملا'
                        : 'Worker account not found',
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerAttendanceScreen(worker: worker),
                  ),
                );
              },
            )
          else if (p.workerPayrollPaymentId == null)
            PopupMenuButton<String>(
              icon: Icon(PhosphorIcons.dotsThreeVertical(),
                  size: 18, color: AppTheme.textSecondary),
              onSelected: (val) {
                if (val == 'edit') {
                  _showAddLaborPaymentDialog(context, contract, isUrdu,
                      paymentToEdit: p);
                } else if (val == 'delete') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.lightColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: UrduAwareText(
                        isUrdu ? 'مزدوری حذف کریں؟' : 'Delete labor wage?',
                        style: const TextStyle(color: AppTheme.darkColor),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: UrduAwareText(isUrdu ? 'نہیں' : 'No',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await Provider.of<ContractService>(context,
                                      listen: false)
                                  .deleteLaborPayment(
                                contractId: contract.id,
                                paymentId: p.id,
                                databaseService: Provider.of<DatabaseService>(
                                    context,
                                    listen: false),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              AppToast.error(
                                context,
                                isUrdu
                                    ? 'مزدوری حذف نہیں ہو سکی'
                                    : 'Could not delete labor payment',
                                subtitle: error.toString(),
                              );
                              return;
                            }
                            if (!context.mounted || !ctx.mounted) return;
                            Navigator.pop(ctx);
                            AppToast.success(
                              context,
                              isUrdu
                                  ? 'مزدوری کی اجرت حذف کر دی گئی'
                                  : 'Labor payment deleted',
                            );
                          },
                          child: UrduAwareText(isUrdu ? 'ہاں' : 'Yes',
                              style: const TextStyle(
                                  color: AppTheme.expenseColor)),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: UrduAwareText(
                    isUrdu ? 'ترمیم کریں' : 'Edit',
                    style: const TextStyle(color: AppTheme.darkColor),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: UrduAwareText(
                    isUrdu ? 'حذف کریں' : 'Delete',
                    style: const TextStyle(color: AppTheme.expenseColor),
                  ),
                ),
              ],
            ),
        ],
      ),
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
