// lib/features/professions/complete_season_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart'
    as transaction_model;
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/config/professions_config.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/utils/formatters.dart';

class CompleteSeasonScreen extends StatefulWidget {
  final Profession season;
  final bool isEditingDetails;

  const CompleteSeasonScreen({
    super.key,
    required this.season,
    this.isEditingDetails = false,
  });

  @override
  State<CompleteSeasonScreen> createState() => _CompleteSeasonScreenState();
}

class _CompleteSeasonScreenState extends State<CompleteSeasonScreen> {
  late TextEditingController _seasonNameController;
  late TextEditingController _areaController;
  late TextEditingController _prodController;
  late TextEditingController _notesController;
  bool _isSaving = false;

  bool get _isAgriculture =>
      widget.season.cropType.isNotEmpty ||
      ProfessionsConfig.categoryTypeFor(widget.season) ==
          ProfessionCategory.agriculture;

  String _workNoun(bool isUrdu) => _isAgriculture
      ? (isUrdu ? 'سیزن' : 'Season')
      : (isUrdu ? 'پروجیکٹ' : 'Project');

  @override
  void initState() {
    super.initState();
    _seasonNameController = TextEditingController(
      text: widget.season.season.isNotEmpty
          ? widget.season.season
          : widget.season.cropType.isNotEmpty
              ? '${widget.season.cropType} ${widget.season.createdAt.year}'
              : widget.season.name,
    );
    _areaController = TextEditingController(
      text:
          widget.season.areaAcres > 0 ? widget.season.areaAcres.toString() : '',
    );
    _prodController = TextEditingController(
      text: widget.season.productionMun > 0
          ? widget.season.productionMun.toString()
          : '',
    );
    _notesController = TextEditingController(
      text: widget.season.notes,
    );
  }

  @override
  void dispose() {
    _seasonNameController.dispose();
    _areaController.dispose();
    _prodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _parseOptionalMeasurement(String value) {
    if (value.trim().isEmpty) return 0;
    return Formatters.tryParseAmount(value, allowDecimals: true);
  }

  void _showLinkTransactionBottomSheet(
      BuildContext context, bool isUrdu, String? fontFamily) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final transactions = db.transactions
        .where((t) => t.professionId == widget.season.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                UrduAwareText(
                  isUrdu
                      ? 'انٹری (ٹرانزیکشن) کا حوالہ دیں'
                      : 'Link Transaction',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: transactions.isEmpty
                  ? Center(
                      child: UrduAwareText(
                        isUrdu
                            ? 'اس سیزن میں کوئی انٹری موجود نہیں'
                            : 'No transactions found for this season',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontFamily: fontFamily,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (_, index) {
                        final tx = transactions[index];
                        final df = DateFormat('dd/MM/yyyy');
                        final isExpense = tx.type == 'expense';
                        final amountStr =
                            Formatters.formatAmountWithCurrency(tx.amount);
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: isExpense
                                ? AppTheme.expenseColor.withValues(alpha: 0.1)
                                : AppTheme.incomeColor.withValues(alpha: 0.1),
                            child: Icon(
                              isExpense
                                  ? PhosphorIcons.arrowUpRight()
                                  : PhosphorIcons.arrowDownLeft(),
                              color: isExpense
                                  ? AppTheme.expenseColor
                                  : AppTheme.incomeColor,
                              size: 16,
                            ),
                          ),
                          title: UrduAwareText(
                            tx.description.isNotEmpty
                                ? tx.description
                                : (isExpense ? 'خرچ' : 'آمدنی'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              fontFamily: fontFamily,
                            ),
                          ),
                          subtitle: UrduAwareText(
                            '${df.format(tx.date)} • $amountStr',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(Icons.add_link,
                              size: 18, color: AppTheme.themeColor),
                          onTap: () async {
                            Navigator.pop(sheetContext);

                            final promptController = TextEditingController(
                                text: (tx.voiceNote != null &&
                                        tx.voiceNote != 'LINKED')
                                    ? tx.voiceNote
                                    : '');
                            final enteredNote = await showDialog<String>(
                              context: context,
                              builder: (promptContext) => AlertDialog(
                                title: UrduAwareText(
                                  isUrdu
                                      ? 'انٹری کا نوٹ درج کریں'
                                      : 'Enter Entry Note',
                                  style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                content: TextField(
                                  controller: promptController,
                                  autofocus: true,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText: isUrdu
                                        ? 'اس انٹری کے متعلق کوئی نوٹ لکھیں...'
                                        : 'Write a note for this entry...',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(promptContext, null),
                                    child: UrduAwareText(
                                        isUrdu ? 'چھوڑ دیں' : 'Skip'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.themeColor),
                                    onPressed: () => Navigator.pop(
                                        promptContext,
                                        promptController.text.trim()),
                                    child: UrduAwareText(
                                      isUrdu ? 'محفوظ کریں' : 'Save',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              promptController.dispose();
                            });
                            if (enteredNote == null) return;
                            if (!context.mounted) return;

                            final noteText = enteredNote;
                            final dateStr = df.format(tx.date);
                            final typeLabel = isExpense
                                ? (isUrdu ? 'خرچ' : 'Expense')
                                : (isUrdu ? 'آمدنی' : 'Income');
                            final refLine = noteText.isNotEmpty
                                ? '[$dateStr] $typeLabel: $amountStr - $noteText'
                                : '';

                            try {
                              final db = Provider.of<DatabaseService>(context,
                                  listen: false);
                              final oldNote = (tx.voiceNote != null &&
                                      tx.voiceNote != 'LINKED')
                                  ? tx.voiceNote!.trim()
                                  : '';
                              final oldRefLine = oldNote.isNotEmpty
                                  ? '[$dateStr] $typeLabel: $amountStr - $oldNote'
                                  : '[$dateStr] $typeLabel: $amountStr';
                              final updatedTx =
                                  transaction_model.Transaction.fromMap({
                                ...tx.toMap(),
                                'voiceNote':
                                    noteText.isNotEmpty ? noteText : 'LINKED',
                                'updatedAt': DateTime.now().toIso8601String(),
                              });
                              await db.updateTransaction(updatedTx);

                              final currentNotes = _notesController.text.trim();
                              var updatedNotes = currentNotes
                                  .replaceFirst(oldRefLine, '')
                                  .trim();
                              updatedNotes = updatedNotes
                                  .replaceAll(
                                      '\n──────────────────\n\n──────────────────\n',
                                      '\n──────────────────\n')
                                  .trim();
                              if (refLine.isNotEmpty) {
                                final separator = updatedNotes.isNotEmpty
                                    ? '\n──────────────────\n'
                                    : '';
                                updatedNotes =
                                    '$updatedNotes$separator$refLine';
                              }
                              await db.updateProfession(widget.season.copyWith(
                                notes: updatedNotes,
                                updatedAt: DateTime.now(),
                              ));

                              if (!context.mounted) return;
                              setState(() {
                                _notesController.text = updatedNotes;
                                _notesController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _notesController.text.length),
                                );
                              });

                              AppToast.success(
                                context,
                                isUrdu
                                    ? 'انٹری کا حوالہ نوٹ میں شامل کر دیا گیا'
                                    : 'Transaction reference added to notes',
                              );
                            } catch (error, stackTrace) {
                              debugPrint(
                                  'Unable to save transaction note: $error');
                              debugPrintStack(stackTrace: stackTrace);
                              if (context.mounted) {
                                AppToast.error(
                                  context,
                                  isUrdu
                                      ? 'انٹری کا نوٹ محفوظ نہیں ہو سکا'
                                      : 'Could not save transaction note',
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSeasonDetails({
    required bool withDetails,
    required bool isUrdu,
  }) async {
    if (_isSaving) return;

    final seasonName = _seasonNameController.text.trim();
    if (seasonName.isEmpty) {
      AppToast.warning(
        context,
        isUrdu
            ? 'سیزن یا پروجیکٹ کا نام درج کریں'
            : 'Enter a season or project name',
      );
      return;
    }

    final areaVal = withDetails && _isAgriculture
        ? _parseOptionalMeasurement(_areaController.text)
        : widget.season.areaAcres;
    final prodVal = withDetails && _isAgriculture
        ? _parseOptionalMeasurement(_prodController.text)
        : widget.season.productionMun;

    if (areaVal == null || prodVal == null || areaVal < 0 || prodVal < 0) {
      AppToast.warning(
        context,
        isUrdu
            ? 'رقبہ اور پیداوار درست درج کریں'
            : 'Enter a valid area and production amount',
      );
      return;
    }

    setState(() => _isSaving = true);
    var didPop = false;
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final parentProfession = widget.season.parentId == null
          ? null
          : db.getProfession(widget.season.parentId!);
      final existingDescription = widget.season.description;
      final preservedDescription =
          existingDescription?.startsWith('ICON:') ?? false
              ? existingDescription
              : parentProfession?.description ?? existingDescription;
      final updated = widget.season.copyWith(
        season: seasonName,
        areaAcres: areaVal,
        productionMun: prodVal,
        description: preservedDescription,
        notes: _notesController.text.trim(),
        isActive: widget.isEditingDetails ? widget.season.isActive : false,
        updatedAt: DateTime.now(),
      );

      await db.updateProfession(updated);
      if (mounted) {
        didPop = true;
        Navigator.pop(context);
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to complete season: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppToast.error(
          context,
          isUrdu ? 'سیزن مکمل نہیں ہو سکا' : 'Could not complete the season',
        );
      }
    } finally {
      if (mounted && !didPop) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    final area = _isAgriculture
        ? _parseOptionalMeasurement(_areaController.text) ?? 0.0
        : 0.0;
    final hasArea = _isAgriculture && area > 0;
    final income = widget.season.totalIncome;
    final expense = widget.season.totalExpense;

    final costPerAcre = area > 0 ? expense / area : 0.0;
    final incomePerAcre = area > 0 ? income / area : 0.0;
    final netProfit = income - expense;

    final df = DateFormat('dd/MM/yyyy');
    final durationDays =
        widget.season.updatedAt.difference(widget.season.createdAt).inDays;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ScreenAppBar(
        title: widget.isEditingDetails
            ? (isUrdu ? 'تفصیلات میں ترمیم' : 'Edit Details')
            : (isUrdu
                ? '${_workNoun(isUrdu)} مکمل کریں'
                : 'Complete ${_workNoun(isUrdu)}'),
        isUrdu: isUrdu,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                text: widget.isEditingDetails
                    ? (isUrdu ? 'تفصیلات محفوظ کریں' : 'Save Details')
                    : (isUrdu
                        ? '${_workNoun(isUrdu)} مکمل کریں'
                        : 'Complete ${_workNoun(isUrdu)}'),
                icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                size: AppButtonSize.large,
                isFullWidth: true,
                isLoading: _isSaving,
                onPressed: _isSaving
                    ? null
                    : () => _saveSeasonDetails(
                          withDetails: true,
                          isUrdu: isUrdu,
                        ),
              ),
              if (!widget.isEditingDetails) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => _saveSeasonDetails(
                            withDetails: false,
                            isUrdu: isUrdu,
                          ),
                  child: UrduAwareText(
                    isUrdu
                        ? 'بغیر تفصیل کے فوری مکمل کریں'
                        : 'Complete without details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🌟 Card 1: Season Header Overview (Theme Color Accent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.themeColor.withValues(alpha: 0.3),
                    width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isAgriculture
                          ? PhosphorIcons.plant(PhosphorIconsStyle.bold)
                          : PhosphorIcons.briefcase(PhosphorIconsStyle.bold),
                      color: AppTheme.themeColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UrduAwareText(
                          widget.season.season.isNotEmpty
                              ? widget.season.season
                              : widget.season.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkColor,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const SizedBox(height: 2),
                        UrduAwareText(
                          _isAgriculture
                              ? (isUrdu ? 'زراعت سیزن' : 'Agriculture Season')
                              : (isUrdu ? 'پروجیکٹ ریکارڈ' : 'Project Record'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontFamily: fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.season.isActive == false
                          ? AppTheme.incomeColor.withValues(alpha: 0.15)
                          : AppTheme.themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: UrduAwareText(
                      widget.season.isActive == false
                          ? (isUrdu ? 'مکمل شدہ' : 'Completed')
                          : (isUrdu ? 'جاری' : 'Active'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: widget.season.isActive == false
                            ? AppTheme.incomeColor
                            : AppTheme.themeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 🌟 Card 2: Duration & Financial Overview (Income & Theme Color Accents)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.incomeColor.withValues(alpha: 0.3),
                    width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(PhosphorIcons.calendarBlank(),
                          size: 16, color: AppTheme.themeColor),
                      const SizedBox(width: 6),
                      UrduAwareText(
                        isUrdu ? 'مدت اور تاریخیں' : 'Duration & Dates',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkColor,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDateInfoBox(
                        isUrdu ? 'شروع کی تاریخ' : 'Start Date',
                        df.format(widget.season.createdAt),
                        fontFamily,
                      ),
                      _buildDateInfoBox(
                        isUrdu ? 'ختم / آج کی تاریخ' : 'End Date',
                        df.format(widget.season.updatedAt),
                        fontFamily,
                      ),
                      _buildDateInfoBox(
                        isUrdu ? 'کل مدت' : 'Total Days',
                        isUrdu ? '$durationDays دن' : '$durationDays days',
                        fontFamily,
                        isHighlight: true,
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildFinancialInfoBox(
                          isUrdu ? 'کل خرچ' : 'Total Expense',
                          Formatters.formatAmountWithCurrency(expense),
                          AppTheme.expenseColor,
                          fontFamily,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFinancialInfoBox(
                          isUrdu ? 'کل آمدنی' : 'Total Income',
                          Formatters.formatAmountWithCurrency(income),
                          AppTheme.incomeColor,
                          fontFamily,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 📋 Section Title: Edit Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: UrduAwareText(
                isUrdu ? 'سیزن کی معلومات درج کریں' : 'Enter Season Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 📝 Modern Input Fields Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _seasonNameController,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                          color: AppTheme.darkColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: _isAgriculture
                            ? (isUrdu ? 'سیزن کا نام' : 'Season Name')
                            : (isUrdu ? 'پروجیکٹ کا نام' : 'Project Name'),
                        labelStyle: TextStyle(
                            fontFamily: fontFamily,
                            color: AppTheme.textSecondary,
                            fontSize: 13),
                        prefixIcon: Icon(PhosphorIcons.tag(),
                            color: AppTheme.themeColor, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_isAgriculture) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      TextField(
                        controller: _areaController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          CurrencyInputFormatter(allowDecimals: true),
                        ],
                        style: const TextStyle(
                            color: AppTheme.darkColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5),
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'رقبہ (ایکڑ)' : 'Area (Acres)',
                          labelStyle: TextStyle(
                              fontFamily: fontFamily,
                              color: AppTheme.textSecondary,
                              fontSize: 13),
                          prefixIcon: Icon(PhosphorIcons.mapPin(),
                              color: AppTheme.themeColor, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      TextField(
                        controller: _prodController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          CurrencyInputFormatter(allowDecimals: true),
                        ],
                        style: const TextStyle(
                            color: AppTheme.darkColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5),
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'پیداوار (من)' : 'Yield (Mun)',
                          hintText: isUrdu ? 'مثلاً 552 من' : 'e.g. 552',
                          labelStyle: TextStyle(
                              fontFamily: fontFamily,
                              color: AppTheme.textSecondary,
                              fontSize: 13),
                          prefixIcon: Icon(PhosphorIcons.scales(),
                              color: AppTheme.themeColor, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 📝 Notes Card with Link Transaction Button & Next-Line System
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.notePencil(),
                            color: AppTheme.themeColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: UrduAwareText(
                              isUrdu
                                  ? 'نوٹ / تبصرہ (اختیاری)'
                                  : 'Notes / Remarks (Optional)',
                              style: TextStyle(
                                color: AppTheme.darkColor,
                                fontFamily: fontFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.themeColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _showLinkTransactionBottomSheet(
                                context, isUrdu, fontFamily),
                            icon: const Icon(Icons.link_rounded, size: 14),
                            label: UrduAwareText(
                              isUrdu ? 'انٹری لنک کریں' : 'Link Tx',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                fontFamily: fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                          color: AppTheme.darkColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: isUrdu
                            ? "یہاں نوٹ لکھیں یا اوپر 'انٹری لنک کریں' سے حوالہ شامل کریں..."
                            : "Write notes here or link a transaction reference above...",
                        hintStyle: TextStyle(
                            color: AppTheme.textSecondary,
                            fontFamily: fontFamily,
                            fontSize: 12),
                        alignLabelWithHint: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 💡 Modern Financial Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(PhosphorIcons.calculator(),
                            size: 16, color: const Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 8),
                      UrduAwareText(
                        isUrdu ? 'مالیاتی خلاصہ' : 'Financial Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkColor,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    hasArea
                        ? (isUrdu ? 'فی ایکڑ خرچ' : 'Cost / Acre')
                        : (isUrdu ? 'کل خرچ' : 'Total Expense'),
                    Formatters.formatAmountWithCurrency(
                      hasArea ? costPerAcre : expense,
                    ),
                    fontFamily,
                  ),
                  if (_isAgriculture && !hasArea) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                    _buildSummaryRow(
                      isUrdu ? 'فی ایکڑ حساب' : 'Per-acre calculation',
                      isUrdu ? 'رقبہ درج کریں' : 'Enter area',
                      fontFamily,
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  _buildSummaryRow(
                    hasArea
                        ? (isUrdu ? 'فی ایکڑ آمدنی' : 'Income / Acre')
                        : (isUrdu ? 'کل آمدنی' : 'Total Income'),
                    income > 0
                        ? Formatters.formatAmountWithCurrency(
                            hasArea ? incomePerAcre : income,
                          )
                        : (isUrdu ? 'ابھی درج نہیں' : 'Not recorded'),
                    fontFamily,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  _buildSummaryRow(
                    isUrdu ? 'خالص منافع / نقصان' : 'Net Profit / Loss',
                    income > 0 || expense > 0
                        ? Formatters.formatAmountWithCurrency(netProfit)
                        : (isUrdu
                            ? 'ابھی کوئی اندراج نہیں'
                            : 'No transactions'),
                    fontFamily,
                    isBold: true,
                    valueColor: netProfit >= 0
                        ? AppTheme.incomeColor
                        : AppTheme.expenseColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInfoBox(String label, String value, String? fontFamily,
      {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: AppTheme.textSecondary,
            fontFamily: fontFamily,
          ),
        ),
        const SizedBox(height: 2),
        UrduAwareText(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppTheme.themeColor : AppTheme.darkColor,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialInfoBox(
      String label, String value, Color color, String? fontFamily) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UrduAwareText(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 2),
          UrduAwareText(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, String? fontFamily,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontFamily: fontFamily,
          ),
        ),
        UrduAwareText(
          value,
          style: TextStyle(
            fontSize: isBold ? 14.5 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: valueColor ?? AppTheme.darkColor,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }
}
