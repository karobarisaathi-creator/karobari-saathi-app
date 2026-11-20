// lib/features/contracts/add_edit_contract_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/contract_service.dart';
import 'package:account_app/core/services/contract_document_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/models/contract_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/features/quick_bill/widgets/customer_picker_sheet.dart';

// ═══════════════════════════════════════════════════════════════
// مقامی رنگ — AppTheme تھیم فائل سے ماخوذ
// ═══════════════════════════════════════════════════════════════
class _C {
  static const bg = AppTheme.backgroundColor;
}

class AddEditContractScreen extends StatefulWidget {
  final ContractModel? contractToEdit;

  const AddEditContractScreen({super.key, this.contractToEdit});

  @override
  State<AddEditContractScreen> createState() => _AddEditContractScreenState();
}

class _AddEditContractScreenState extends State<AddEditContractScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _partyNameController;
  late final TextEditingController _partyPhoneController;

  final List<TextEditingController> _descControllers = [];
  final List<XFile> _pendingDocuments = [];
  late List<ContractDocument> _documents;
  Account? _selectedParty;
  DateTime _startDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.contractToEdit;
    _documents = List.of(c?.documents ?? const []);
    _titleController = TextEditingController(text: c?.title ?? '');
    _amountController = TextEditingController(
        text: c != null && c.totalAmount > 0 ? c.totalAmount.toString() : '');
    _partyNameController = TextEditingController(text: c?.partyName ?? '');
    _partyPhoneController = TextEditingController(text: '');
    _startDate = c?.startDate ?? DateTime.now();

    // تفصیل کے آئٹمز لوڈ کریں یا کم از کم 3 خالی انپٹ فیلڈز شامل کریں
    if (c != null && c.description.trim().isNotEmpty) {
      final rawLines = c.description.split('\n');
      for (final line in rawLines) {
        if (line.trim().isNotEmpty) {
          final clean = line.trim().replaceAll(RegExp(r'^\d+[\.\-\)]\s*'), '');
          _descControllers.add(TextEditingController(text: clean));
        }
      }
    }

    // کم از کم 3 فیلڈز شو ہونا لازمی ہیں
    while (_descControllers.length < 3) {
      _descControllers.add(TextEditingController());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // اگر ایڈٹ کر رہے ہیں اور partyId موجود ہے تو ڈیٹا بیس سے پارٹی لوپ اپ کریں
    if (widget.contractToEdit != null && _selectedParty == null) {
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);
      final accounts = databaseService.getAccounts();
      final pId = widget.contractToEdit!.partyId;
      if (pId.isNotEmpty && accounts.any((a) => a.id == pId)) {
        _selectedParty = accounts.firstWhere((a) => a.id == pId);
        if (_partyPhoneController.text.isEmpty) {
          _partyPhoneController.text =
              Formatters.formatPhoneNumber(_selectedParty!.phone);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _partyNameController.dispose();
    _partyPhoneController.dispose();
    for (final controller in _descControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// ٹھیکہ محفوظ کرنے کا مرکزی فنکشن — باٹم والے بٹن کے لیے
  Future<void> _saveWithStatus({required bool isIncoming}) async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    final title = _titleController.text.trim();
    final partyName = _partyNameController.text.trim().isNotEmpty
        ? _partyNameController.text.trim()
        : (_selectedParty?.name ?? '');

    if (title.isEmpty) {
      AppToast.warning(
          context,
          isUrdu
              ? 'برائے مہربانی ٹھیکے کا عنوان درج کریں'
              : 'Please enter contract title');
      return;
    }

    if (partyName.isEmpty) {
      AppToast.warning(
          context,
          isUrdu
              ? 'برائے مہربانی پارٹی کا نام درج یا منتخب کریں'
              : 'Please select or enter party name');
      return;
    }

    final rawAmount = _amountController.text.trim();
    final amount = Formatters.tryParseAmount(rawAmount) ??
        double.tryParse(rawAmount) ??
        0.0;

    if (amount <= 0) {
      AppToast.warning(
          context,
          isUrdu
              ? 'برائے مہربانی کل طے شدہ رقم درست درج کریں'
              : 'Please enter valid total amount');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // نمبر شمار کے ساتھ تفصیل تیار کریں (1. ، 2. ، 3. ...)
    final List<String> items = [];
    for (int i = 0; i < _descControllers.length; i++) {
      final text = _descControllers[i].text.trim();
      if (text.isNotEmpty) {
        final cleanText = text.replaceAll(RegExp(r'^\d+[\.\-\)]\s*'), '');
        items.add('${items.length + 1}. $cleanText');
      }
    }
    final description = items.join('\n');

    if (_isSaving) return;
    setState(() => _isSaving = true);

    final contractService =
        Provider.of<ContractService>(context, listen: false);
    final documentService = ContractDocumentService();
    final now = DateTime.now();
    final contractId =
        widget.contractToEdit?.id ?? now.microsecondsSinceEpoch.toString();
    final uploadedDocuments = <ContractDocument>[];

    try {
      if (_documents.length + _pendingDocuments.length >
          ContractDocumentService.maxDocumentsPerContract) {
        throw StateError(
            'A contract can have up to ${ContractDocumentService.maxDocumentsPerContract} images.');
      }
      for (final image in _pendingDocuments) {
        uploadedDocuments.add(
          await documentService.uploadImage(
            contractId: contractId,
            image: image,
          ),
        );
      }
    } catch (error) {
      final cleanupError =
          await _cleanupUploadedDocuments(documentService, uploadedDocuments);
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'معاہدے کی تصویر اپلوڈ نہیں ہو سکی'
              : 'Could not upload contract image',
          subtitle: cleanupError == null
              ? error.toString()
              : '$error\nCleanup error: $cleanupError',
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    if (!mounted) {
      await _cleanupUploadedDocuments(documentService, uploadedDocuments);
      return;
    }

    final documents = [..._documents, ...uploadedDocuments];
    final removedDocuments = (widget.contractToEdit?.documents ?? const [])
        .where(
            (document) => documents.every((saved) => saved.id != document.id))
        .toList();

    try {
      if (widget.contractToEdit == null) {
        final newContract = ContractModel(
          id: contractId,
          partyId: _selectedParty?.id ?? '',
          partyName: partyName,
          title: title,
          description: description,
          totalAmount: amount,
          isIncoming: isIncoming,
          startDate: _startDate,
          documents: documents,
          createdAt: now,
          updatedAt: now,
        );
        await contractService.addContract(newContract);
      } else {
        final updated = widget.contractToEdit!.copyWith(
          partyId: _selectedParty?.id ?? widget.contractToEdit!.partyId,
          partyName: partyName.isNotEmpty
              ? partyName
              : widget.contractToEdit!.partyName,
          title: title,
          description: description,
          totalAmount: amount,
          isIncoming: isIncoming,
          startDate: _startDate,
          documents: documents,
        );
        await contractService.updateContract(updated);
      }
    } catch (error) {
      final cleanupError =
          await _cleanupUploadedDocuments(documentService, uploadedDocuments);
      if (mounted) {
        AppToast.error(
          context,
          isUrdu ? 'ٹھیکہ محفوظ نہیں ہو سکا' : 'Could not save contract',
          subtitle: cleanupError == null
              ? error.toString()
              : '$error\nCleanup error: $cleanupError',
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    String? documentCleanupError;
    for (final document in removedDocuments) {
      try {
        await documentService.deleteDocument(document);
      } catch (error) {
        documentCleanupError ??= error.toString();
      }
    }

    if (!mounted) return;
    if (documentCleanupError != null) {
      AppToast.warning(
        context,
        isUrdu ? 'ٹھیکہ محفوظ ہو گیا' : 'Contract saved',
        subtitle: isUrdu
            ? 'کچھ پرانی تصاویر کلاؤڈ سے حذف نہیں ہو سکیں: $documentCleanupError'
            : 'Some removed images could not be deleted from cloud storage: $documentCleanupError',
      );
    } else {
      AppToast.success(
        context,
        widget.contractToEdit == null
            ? (isUrdu ? 'ٹھیکہ کامیابی سے شامل ہو گیا' : 'Contract saved')
            : (isUrdu ? 'ٹھیکہ اپڈیٹ ہو گیا' : 'Contract updated'),
      );
    }
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  Future<String?> _cleanupUploadedDocuments(
    ContractDocumentService documentService,
    List<ContractDocument> documents,
  ) async {
    final errors = <String>[];
    for (final document in documents) {
      try {
        await documentService.deleteDocument(document);
      } catch (error) {
        errors.add(error.toString());
      }
    }
    return errors.isEmpty ? null : errors.join('\n');
  }

  Future<void> _pickContractImages(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final remaining = ContractDocumentService.maxDocumentsPerContract -
          _documents.length -
          _pendingDocuments.length;
      if (remaining <= 0) {
        final isUrdu =
            Provider.of<LanguageService>(context, listen: false).isUrdu;
        AppToast.warning(
          context,
          isUrdu
              ? 'ایک ٹھیکے کے ساتھ زیادہ سے زیادہ ${ContractDocumentService.maxDocumentsPerContract} تصاویر لگ سکتی ہیں'
              : 'A contract can have up to ${ContractDocumentService.maxDocumentsPerContract} images.',
        );
        return;
      }

      final pickedImages = source == ImageSource.camera
          ? await picker.pickImage(
              source: source,
              maxWidth: 2400,
              maxHeight: 3200,
              imageQuality: 95,
            )
          : null;
      final images = source == ImageSource.camera
          ? (pickedImages == null ? <XFile>[] : [pickedImages])
          : await picker.pickMultiImage(
              maxWidth: 2400,
              maxHeight: 3200,
              imageQuality: 95,
              limit: remaining,
            );
      if (images.isEmpty || !mounted) return;
      setState(() => _pendingDocuments.addAll(images.take(remaining)));
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        Provider.of<LanguageService>(context, listen: false).isUrdu
            ? 'تصویر منتخب نہیں ہو سکی'
            : 'Could not select image',
        subtitle: error.toString(),
      );
    }
  }

  Widget _buildContractDocumentsSection(bool isUrdu, String? fontFamily) {
    final hasDocuments = _documents.isNotEmpty || _pendingDocuments.isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UrduAwareText(
            isUrdu ? 'معاہدہ / اسٹامپ پیپر' : 'Contract / Stamp Paper',
            style: TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 4),
          UrduAwareText(
            isUrdu
                ? 'تصویر اپلوڈ کے لیے محدود سائز اور کمپریشن کے ساتھ محفوظ ہوگی؛ کاغذی اصل بھی سنبھال کر رکھیں۔ تحریر خودکار طور پر نہیں پڑھی جائے گی۔'
                : 'The upload is resized and compressed; keep the paper original. Handwriting is not transcribed automatically.',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: isUrdu ? 'فوٹو لیں' : 'Take photo',
                  icon: Icons.camera_alt_outlined,
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.small,
                  isFullWidth: true,
                  onPressed: _isSaving
                      ? null
                      : () => _pickContractImages(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  text: isUrdu ? 'تصاویر منتخب کریں' : 'Choose photos',
                  icon: Icons.photo_library_outlined,
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.small,
                  isFullWidth: true,
                  onPressed: _isSaving
                      ? null
                      : () => _pickContractImages(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (hasDocuments) ...[
            const Divider(),
            ..._documents.map(
              (document) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_done_outlined,
                    color: AppTheme.themeColor),
                title: UrduAwareText(document.fileName),
                subtitle: UrduAwareText(
                  '${(document.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: IconButton(
                  tooltip: isUrdu ? 'ہٹائیں' : 'Remove',
                  onPressed: _isSaving
                      ? null
                      : () => _confirmRemoveDocument(document, isUrdu),
                  icon: const Icon(Icons.close, color: AppTheme.expenseColor),
                ),
              ),
            ),
            ..._pendingDocuments.map(
              (image) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.image_outlined, color: AppTheme.goldColor),
                title: UrduAwareText(image.name),
                subtitle: UrduAwareText(
                    isUrdu ? 'اپلوڈ کے لیے تیار' : 'Ready to upload'),
                trailing: IconButton(
                  tooltip: isUrdu ? 'ہٹائیں' : 'Remove',
                  onPressed: _isSaving
                      ? null
                      : () => setState(() => _pendingDocuments.remove(image)),
                  icon: const Icon(Icons.close, color: AppTheme.expenseColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRemoveDocument(
    ContractDocument document,
    bool isUrdu,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: UrduAwareText(
          isUrdu ? 'معاہدے کی تصویر ہٹائیں؟' : 'Remove contract image?',
        ),
        content: UrduAwareText(
          isUrdu
              ? 'محفوظ کرنے پر یہ تصویر نجی کلاؤڈ سے مستقل حذف ہو جائے گی۔'
              : 'Saving will permanently delete this image from private cloud storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: UrduAwareText(isUrdu ? 'منسوخ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: UrduAwareText(isUrdu ? 'تصویر ہٹائیں' : 'Remove image'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _documents.remove(document));
    }
  }

  Future<void> _pickPartyFromBottomSheet() async {
    final result = await showCustomerPickerSheet(context);
    if (result != null && result.account != null) {
      setState(() {
        _selectedParty = result.account;
        _partyNameController.text = result.account!.name;
        _partyPhoneController.text =
            Formatters.formatPhoneNumber(result.account!.phone);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return Directionality(
      textDirection: languageService.textDirection,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
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
                            widget.contractToEdit == null
                                ? (isUrdu
                                    ? 'نیا ٹھیکہ شامل کریں'
                                    : 'Add New Contract')
                                : (isUrdu
                                    ? 'ٹھیکے میں ترمیم'
                                    : 'Edit Contract'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: fontFamily,
                              color: AppTheme.darkColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── پارٹی سلیکشن ایریا (باٹم شیٹ کارڈ + مینول انپٹ) ──
                  _buildPartySelectionArea(isUrdu, fontFamily),
                  const SizedBox(height: 16),

                  // ── انپٹ فیلڈز کارڈ ──
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFD1D5DB), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.darkColor.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // ٹھیکے کا عنوان
                        _buildProfileStyleField(
                          controller: _titleController,
                          label: isUrdu ? 'ٹھیکے کا عنوان *' : 'Title *',
                          icon: PhosphorIcons.fileText(),
                          fontFamily: fontFamily,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (isUrdu ? 'عنوان درج کریں' : 'Title required')
                              : null,
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        // مینول پارٹی نام
                        _buildProfileStyleField(
                          controller: _partyNameController,
                          label: isUrdu ? 'پارٹی کا نام *' : 'Party Name *',
                          icon: PhosphorIcons.user(),
                          fontFamily: fontFamily,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (isUrdu
                                  ? 'پارٹی کا نام درج کریں'
                                  : 'Party name required')
                              : null,
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        // مینول فون نمبر
                        _buildProfileStyleField(
                          controller: _partyPhoneController,
                          label: isUrdu
                              ? 'فون نمبر (اختیاری)'
                              : 'Phone Number (Optional)',
                          icon: PhosphorIcons.phone(),
                          fontFamily: fontFamily,
                          isPhone: true,
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        // کل طے شدہ رقم
                        _buildProfileStyleField(
                          controller: _amountController,
                          label: isUrdu ? 'کل طے شدہ رقم *' : 'Total Amount *',
                          icon: PhosphorIcons.currencyDollar(),
                          fontFamily: fontFamily,
                          isNumber: true,
                          validator: (v) {
                            final n = Formatters.tryParseAmount(v ?? '') ??
                                double.tryParse(v?.trim() ?? '');
                            if (n == null || n <= 0) {
                              return isUrdu
                                  ? 'درست رقم لکھیں'
                                  : 'Invalid amount';
                            }
                            return null;
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                        // نمبر شمار والی تفصیل کی فہرست
                        _buildNumberedDescriptionSection(isUrdu, fontFamily),
                      ],
                    ),
                  ),
                  _buildContractDocumentsSection(isUrdu, fontFamily),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // ── باٹم پینڈ محفوظ کرنے کے بٹنز (ٹھیکہ لیا / ٹھیکہ دیا) ──
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: isUrdu ? 'ٹھیکہ لیا' : 'Take Contract',
                    icon: PhosphorIcons.arrowDownLeft(),
                    color: AppTheme.incomeColor,
                    size: AppButtonSize.large,
                    isFullWidth: true,
                    isLoading: _isSaving,
                    onPressed: () => _saveWithStatus(isIncoming: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    text: isUrdu ? 'ٹھیکہ دیا' : 'Give Contract',
                    icon: PhosphorIcons.arrowUpRight(),
                    color: AppTheme.expenseColor,
                    size: AppButtonSize.large,
                    isFullWidth: true,
                    isLoading: _isSaving,
                    onPressed: () => _saveWithStatus(isIncoming: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// پارٹی سلیکشن کا ایریا — اگر پارٹی سلیکٹ ہو تو PartyCard شو کرتا ہے
  Widget _buildPartySelectionArea(bool isUrdu, String? fontFamily) {
    if (_selectedParty != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.themeColor.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkColor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            PartyCard(
              party: _selectedParty!,
              showActions: false,
              showCard: false,
              onView: () {},
              onMessage: () {},
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _pickPartyFromBottomSheet,
                    icon: const Icon(Icons.swap_horiz_rounded,
                        size: 16, color: AppTheme.themeColor),
                    label: UrduAwareText(
                      isUrdu ? 'پارٹی تبدیل کریں' : 'Change Party',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.themeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppTheme.expenseColor),
                    tooltip: isUrdu ? 'پارٹی ہٹائیں' : 'Remove Party',
                    onPressed: () {
                      setState(() {
                        _selectedParty = null;
                        _partyNameController.clear();
                        _partyPhoneController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _pickPartyFromBottomSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.themeColor.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkColor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.themeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.userPlus(),
                  color: AppTheme.themeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UrduAwareText(
                    isUrdu
                        ? 'پارٹی / کلائنٹ منتخب کریں'
                        : 'Select Party / Client',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  UrduAwareText(
                    isUrdu
                        ? 'کھاتے داروں کی باٹم شیٹ میں سے چنیں'
                        : 'Choose from customer picker sheet',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.themeColor),
          ],
        ),
      ),
    );
  }

  /// نمبر شمار (1. ، 2. ، 3. ...) والی تفصیل کی فیلڈز
  Widget _buildNumberedDescriptionSection(bool isUrdu, String? fontFamily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Icon(PhosphorIcons.listNumbers(),
                  size: 18, color: AppTheme.themeColor),
              const SizedBox(width: 8),
              UrduAwareText(
                isUrdu ? 'کام کی تفصیل / فہرست' : 'Work Details / Items',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _descControllers.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: UrduAwareText(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.themeColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _descControllers[index],
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkColor,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: isUrdu
                            ? 'تفصیل نمبر ${index + 1}'
                            : 'Item detail #${index + 1}',
                        hintStyle: TextStyle(
                          fontFamily: fontFamily,
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_descControllers.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            size: 18, color: AppTheme.expenseColor),
                        tooltip: isUrdu ? 'لائن ہٹائیں' : 'Remove item',
                        onPressed: () {
                          setState(() {
                            _descControllers[index].dispose();
                            _descControllers.removeAt(index);
                          });
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        InkWell(
          onTap: () {
            setState(() {
              _descControllers.add(TextEditingController());
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline_rounded,
                    size: 18, color: AppTheme.themeColor),
                const SizedBox(width: 6),
                UrduAwareText(
                  isUrdu ? '+ مزید تفصیل شامل کریں' : '+ Add More Detail',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.themeColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStyleField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? fontFamily,
    bool isNumber = false,
    bool isPhone = false,
    int maxLines = 1,
    String? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isPhone
          ? TextInputType.phone
          : (isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text),
      validator: validator,
      onChanged: isPhone
          ? (val) {
              if (val.length >= 10) {
                final formatted = Formatters.formatPhoneNumber(val);
                if (formatted != val && formatted.isNotEmpty) {
                  controller.value = TextEditingValue(
                    text: formatted,
                    selection:
                        TextSelection.collapsed(offset: formatted.length),
                  );
                }
              }
            }
          : null,
      style: TextStyle(
        fontFamily: (isPhone || isNumber) ? null : fontFamily,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppTheme.darkColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
        prefixIcon: Icon(icon, color: AppTheme.themeColor),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.all(14.0),
                child: UrduAwareText(
                  suffix,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                  ),
                ),
              )
            : null,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
