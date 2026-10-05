// lib/features/professions/complete_season_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';

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
  late TextEditingController _incomeController;

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
    _incomeController = TextEditingController(
      text: widget.season.totalIncome > 0
          ? widget.season.totalIncome.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _areaController.dispose();
    _prodController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    final area = double.tryParse(_areaController.text) ??
        (widget.season.areaAcres > 0 ? widget.season.areaAcres : 1.0);
    final income = double.tryParse(_incomeController.text) ?? widget.season.totalIncome;
    final expense = widget.season.totalExpense;

    final costPerAcre = area > 0 ? expense / area : 0.0;
    final incomePerAcre = area > 0 ? income / area : 0.0;
    final netProfit = income - expense;

    final df = DateFormat('dd/MM/yy');
    final durationStr =
        '${df.format(widget.season.createdAt)} – ${df.format(widget.season.updatedAt)} (${widget.season.updatedAt.difference(widget.season.createdAt).inDays} دن)';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: CustomAppBar(
        title: widget.isEditingDetails
            ? (isUrdu ? 'سیزن کی تفصیلات' : 'Season Details')
            : (isUrdu ? 'سیزن مکمل کریں' : 'Complete Season'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🏷️ Season Info Top Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
              child: Column(
                children: [
                  _buildHeaderRow(
                    isUrdu ? 'سیزن' : 'Season',
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
                    'Rs. ${expense.toStringAsFixed(0)}',
                    isBold: true,
                    fontFamily: fontFamily,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 📝 Form Inputs Card (Master Profile Style)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Area
                  TextField(
                    controller: _areaController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.darkColor),
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'رقبہ (ایکڑ)' : 'Area (Acres)',
                      labelStyle: TextStyle(fontFamily: fontFamily),
                      prefixIcon: Icon(PhosphorIcons.mapPin(), color: AppTheme.themeColor),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const Divider(height: 1),

                  // Production
                  TextField(
                    controller: _prodController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.darkColor),
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'پیداوار (من)' : 'Yield (Mun)',
                      hintText: 'مثلاً 552',
                      labelStyle: TextStyle(fontFamily: fontFamily),
                      prefixIcon: Icon(PhosphorIcons.scales(), color: AppTheme.themeColor),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const Divider(height: 1),

                  // Total Income
                  TextField(
                    controller: _incomeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.darkColor),
                    decoration: InputDecoration(
                      labelText: isUrdu ? 'کل آمدنی' : 'Total Income',
                      hintText: 'فروخت کے اندراج سے خودکار آئے گی',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontFamily: fontFamily,
                      ),
                      labelStyle: TextStyle(fontFamily: fontFamily),
                      prefixIcon: Icon(PhosphorIcons.currencyCircleDollar(), color: AppTheme.themeColor),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                      Text(
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
                    isUrdu ? 'فی ایکڑ خرچ' : 'Cost / Acre',
                    'Rs. ${costPerAcre.toStringAsFixed(0)}',
                    fontFamily,
                  ),
                  const Divider(height: 16, color: Color(0xFFBFDBFE)),
                  _buildSummaryRow(
                    isUrdu ? 'فی ایکڑ آمدنی' : 'Income / Acre',
                    income > 0
                        ? 'Rs. ${incomePerAcre.toStringAsFixed(0)}'
                        : (isUrdu ? 'ابھی درج نہیں' : 'Not recorded'),
                    fontFamily,
                  ),
                  const Divider(height: 16, color: Color(0xFFBFDBFE)),
                  _buildSummaryRow(
                    isUrdu ? 'منافع' : 'Net Profit',
                    income > 0
                        ? 'Rs. ${netProfit.toStringAsFixed(0)}'
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
                  ? (isUrdu ? 'محفوظ کریں' : 'Save Details')
                  : (isUrdu ? 'سیزن مکمل کریں' : 'Complete Season'),
              icon: PhosphorIcons.checkCircle(),
              onPressed: () async {
                final db = Provider.of<DatabaseService>(context, listen: false);
                final areaVal = double.tryParse(_areaController.text) ?? widget.season.areaAcres;
                final prodVal = double.tryParse(_prodController.text) ?? widget.season.productionMun;
                final incVal = double.tryParse(_incomeController.text) ?? widget.season.totalIncome;

                final updated = widget.season.copyWith(
                  areaAcres: areaVal,
                  productionMun: prodVal,
                  totalIncome: incVal,
                  isActive: widget.isEditingDetails ? widget.season.isActive : false,
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
                  final db = Provider.of<DatabaseService>(context, listen: false);
                  final updated = widget.season.copyWith(
                    isActive: false,
                    updatedAt: DateTime.now(),
                  );
                  await db.updateProfession(updated);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  isUrdu ? 'بغیر تفصیل کے مکمل کریں' : 'Complete without details',
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
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontFamily: fontFamily,
          ),
        ),
        Text(
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
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF1E3A8A),
            fontFamily: fontFamily,
          ),
        ),
        Text(
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
