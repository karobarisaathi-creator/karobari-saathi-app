// lib/features/professions/complete_season_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/config/professions_config.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';
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
  late TextEditingController _areaController;
  late TextEditingController _prodController;

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
    _areaController = TextEditingController(
      text: widget.season.areaAcres > 0
          ? widget.season.areaAcres.toStringAsFixed(0)
          : '',
    );
    _prodController = TextEditingController(
      text: widget.season.productionMun > 0
          ? widget.season.productionMun.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _areaController.dispose();
    _prodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final area = double.tryParse(_areaController.text) ??
        (widget.season.areaAcres > 0 ? widget.season.areaAcres : 1.0);
    final income = widget.season.totalIncome;
    final expense = widget.season.totalExpense;

    final costPerAcre = area > 0 ? expense / area : 0.0;
    final incomePerAcre = area > 0 ? income / area : 0.0;
    final netProfit = income - expense;

    final df = DateFormat('dd/MM/yy');
    final durationDays =
        widget.season.updatedAt.difference(widget.season.createdAt).inDays;
    final durationStr = isUrdu
        ? '${df.format(widget.season.createdAt)} – ${df.format(widget.season.updatedAt)} ($durationDays دن)'
        : '${df.format(widget.season.createdAt)} – ${df.format(widget.season.updatedAt)} ($durationDays days)';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: widget.isEditingDetails
            ? (isUrdu
                ? '${_workNoun(isUrdu)} کی تفصیلات'
                : '${_workNoun(isUrdu)} Details')
            : (isUrdu
                ? '${_workNoun(isUrdu)} مکمل کریں'
                : 'Complete ${_workNoun(isUrdu)}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          children: [
            // 🏷️ Season Info Top Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
              child: Column(
                children: [
                  _buildHeaderRow(
                    _workNoun(isUrdu),
                    widget.season.season.isNotEmpty
                        ? widget.season.season
                        : widget.season.name,
                    isBold: true,
                    fontFamily: fontFamily,
                  ),
                  const Divider(height: 16),
                  _buildHeaderRow(
                    isUrdu ? 'مدت' : 'Duration',
                    durationStr,
                    fontFamily: fontFamily,
                  ),
                  const Divider(height: 16),
                  _buildHeaderRow(
                    isUrdu ? 'خرچ اب تک' : 'Expense so far',
                    'Rs. ${Formatters.formatAmount(expense)}',
                    isBold: true,
                    fontFamily: fontFamily,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isAgriculture) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _areaController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [CurrencyInputFormatter()],
                        style: const TextStyle(color: AppTheme.darkColor),
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'رقبہ (ایکڑ)' : 'Area (Acres)',
                          labelStyle: TextStyle(fontFamily: fontFamily),
                          prefixIcon: Icon(PhosphorIcons.mapPin(),
                              color: AppTheme.themeColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const Divider(height: 1),
                      TextField(
                        controller: _prodController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [CurrencyInputFormatter()],
                        style: const TextStyle(color: AppTheme.darkColor),
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'پیداوار (من)' : 'Yield (Mun)',
                          hintText: 'مثلاً 552',
                          labelStyle: TextStyle(fontFamily: fontFamily),
                          prefixIcon: Icon(PhosphorIcons.scales(),
                              color: AppTheme.themeColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 💡 Summary Card (خلاصہ)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(PhosphorIcons.calculator(),
                          size: 18, color: const Color(0xFF1D4ED8)),
                      const SizedBox(width: 8),
                      UrduAwareText(
                        isUrdu ? 'خلاصہ' : 'Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E40AF),
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    _isAgriculture
                        ? (isUrdu ? 'فی ایکڑ خرچ' : 'Cost / Acre')
                        : (isUrdu ? 'کل خرچ' : 'Total Expense'),
                    'Rs. ${Formatters.formatAmount(_isAgriculture ? costPerAcre : expense)}',
                    fontFamily,
                  ),
                  const Divider(height: 16, color: Color(0xFFBFDBFE)),
                  _buildSummaryRow(
                    _isAgriculture
                        ? (isUrdu ? 'فی ایکڑ آمدنی' : 'Income / Acre')
                        : (isUrdu ? 'کل آمدنی' : 'Total Income'),
                    income > 0
                        ? 'Rs. ${Formatters.formatAmount(_isAgriculture ? incomePerAcre : income)}'
                        : (isUrdu ? 'ابھی درج نہیں' : 'Not recorded'),
                    fontFamily,
                  ),
                  const Divider(height: 16, color: Color(0xFFBFDBFE)),
                  _buildSummaryRow(
                    isUrdu ? 'خالص منافع' : 'Net Profit',
                    income > 0
                        ? 'Rs. ${Formatters.formatAmount(netProfit)}'
                        : (isUrdu ? 'آمدنی درج نہیں' : 'No Income'),
                    fontFamily,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 🔵 Primary Complete Button
            AppButton(
              text: widget.isEditingDetails
                  ? (isUrdu ? 'تفصیلات محفوظ کریں' : 'Save Details')
                  : (isUrdu
                      ? '${_workNoun(isUrdu)} مکمل کریں'
                      : 'Complete ${_workNoun(isUrdu)}'),
              icon: PhosphorIcons.checkCircle(),
              size: AppButtonSize.large,
              isFullWidth: true,
              onPressed: () async {
                final db = Provider.of<DatabaseService>(context, listen: false);
                final areaVal = double.tryParse(_areaController.text) ??
                    widget.season.areaAcres;
                final prodVal = double.tryParse(_prodController.text) ??
                    widget.season.productionMun;
                final updated = widget.season.copyWith(
                  areaAcres: areaVal,
                  productionMun: prodVal,
                  isActive:
                      widget.isEditingDetails ? widget.season.isActive : false,
                  updatedAt: DateTime.now(),
                );

                await db.updateProfession(updated);
                if (context.mounted) Navigator.pop(context);
              },
            ),

            if (!widget.isEditingDetails) ...[
              const SizedBox(height: 12),
              // Secondary Link: Complete without details
              TextButton(
                onPressed: () async {
                  final db =
                      Provider.of<DatabaseService>(context, listen: false);
                  final updated = widget.season.copyWith(
                    isActive: false,
                    updatedAt: DateTime.now(),
                  );
                  await db.updateProfession(updated);
                  if (context.mounted) Navigator.pop(context);
                },
                child: UrduAwareText(
                  isUrdu
                      ? 'بغیر تفصیل کے مکمل کریں'
                      : 'Complete without details',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    decoration: TextDecoration.underline,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(String label, String value,
      {bool isBold = false, required String fontFamily}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontFamily: fontFamily,
          ),
        ),
        UrduAwareText(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: AppTheme.darkColor,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, String fontFamily,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF1E3A8A),
            fontFamily: fontFamily,
          ),
        ),
        UrduAwareText(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF1E40AF),
          ),
        ),
      ],
    );
  }
}
