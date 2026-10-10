// lib/features/professions/season_comparison_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/season_report_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/season_report_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

class SeasonComparisonScreen extends StatefulWidget {
  final Profession seasonA;
  final Profession? seasonB;

  const SeasonComparisonScreen({
    super.key,
    required this.seasonA,
    this.seasonB,
  });

  @override
  State<SeasonComparisonScreen> createState() => _SeasonComparisonScreenState();
}

class _SeasonComparisonScreenState extends State<SeasonComparisonScreen> {
  // ═════════════════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════════════════
  String _formatMoney(double amount) {
    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (abs >= 1000000) {
      return '$sign${(abs / 1000000).toStringAsFixed(2)}M';
    }
    if (abs >= 1000) {
      return '$sign${(abs / 1000).toStringAsFixed(0)}K';
    }
    return '$sign${abs.toStringAsFixed(0)}';
  }

  String _formatFull(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toStringAsFixed(0);
    return qty.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final db = Provider.of<DatabaseService>(context);

    // ─── Determine what to show ───
    final hasTwo = widget.seasonB != null;

    // Sort newer vs older
    Profession? newSeason;
    Profession? oldSeason;
    if (hasTwo) {
      if (widget.seasonA.createdAt.isAfter(widget.seasonB!.createdAt)) {
        newSeason = widget.seasonA;
        oldSeason = widget.seasonB;
      } else {
        newSeason = widget.seasonB;
        oldSeason = widget.seasonA;
      }
    } else {
      newSeason = widget.seasonA;
    }

    // ─── Build reports ───
    final allTx = db.getAllTransactions();
    final newReport = SeasonReportService.buildReport(
      profession: newSeason!,
      transactions: allTx,
    );

    final oldReport = hasTwo
        ? SeasonReportService.buildReport(
            profession: oldSeason!,
            transactions: allTx,
          )
        : null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: hasTwo
            ? (isUrdu ? 'سیزن کا موازنہ' : 'Season Comparison')
            : (isUrdu ? 'سیزن رپورٹ' : 'Season Report'),
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // ═══ Season Header ═══
            if (!hasTwo)
              _buildSingleHeader(newSeason, newReport, isUrdu, fontFamily)
            else
              _buildCompareHeader(newSeason, oldSeason!, isUrdu, fontFamily),
            const SizedBox(height: 14),

            // ═══ Hero Summary ═══
            if (!hasTwo)
              _buildHeroSummary(newReport, isUrdu, fontFamily)
            else
              _buildCompareHeroSummary(
                  newReport, oldReport!, isUrdu, fontFamily),
            const SizedBox(height: 14),

            // ═══ Per Acre Metrics ═══
            if (!hasTwo)
              _buildPerAcreCard(newReport, isUrdu, fontFamily)
            else
              _buildComparePerAcreCard(
                  newReport, oldReport!, isUrdu, fontFamily),
            const SizedBox(height: 14),

            // ═══ Target Progress (single only) ═══
            if (!hasTwo) ...[
              _buildTargetCard(newReport, isUrdu, fontFamily),
              const SizedBox(height: 14),
            ],

            // ═══ Income Categories ═══
            if (!hasTwo)
              _buildCategoryCard(
                title: isUrdu ? 'آمدن کی تفصیل' : 'Income Breakdown',
                icon: PhosphorIcons.arrowUpRight(),
                iconColor: AppTheme.incomeColor,
                iconBg: AppTheme.incomeColor.withValues(alpha: 0.10),
                badge: 'Rs ${_formatMoney(newReport.totalIncome)}',
                categories: newReport.incomeCategories,
                total: newReport.totalIncome,
                isIncome: true,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              )
            else
              _buildCompareCategoryCard(
                title: isUrdu
                    ? 'آمدن کی زمرہ وار موازنہ'
                    : 'Income Categories',
                icon: PhosphorIcons.arrowUpRight(),
                iconColor: AppTheme.incomeColor,
                iconBg: AppTheme.incomeColor.withValues(alpha: 0.10),
                newCategories: newReport.incomeCategories,
                oldCategories: oldReport!.incomeCategories,
                newTotal: newReport.totalIncome,
                oldTotal: oldReport.totalIncome,
                isIncome: true,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
            const SizedBox(height: 14),

            // ═══ Expense Categories ═══
            if (!hasTwo)
              _buildCategoryCard(
                title: isUrdu ? 'اخراجات کی تفصیل' : 'Expense Breakdown',
                icon: PhosphorIcons.arrowDownLeft(),
                iconColor: AppTheme.expenseColor,
                iconBg: AppTheme.expenseColor.withValues(alpha: 0.10),
                badge: 'Rs ${_formatMoney(newReport.totalExpense)}',
                categories: newReport.expenseCategories,
                total: newReport.totalExpense,
                isIncome: false,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              )
            else
              _buildCompareCategoryCard(
                title: isUrdu
                    ? 'اخراجات کی زمرہ وار موازنہ'
                    : 'Expense Categories',
                icon: PhosphorIcons.arrowDownLeft(),
                iconColor: AppTheme.expenseColor,
                iconBg: AppTheme.expenseColor.withValues(alpha: 0.10),
                newCategories: newReport.expenseCategories,
                oldCategories: oldReport!.expenseCategories,
                newTotal: newReport.totalExpense,
                oldTotal: oldReport.totalExpense,
                isIncome: false,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
            const SizedBox(height: 14),

            // ═══ Budget Alerts (single only) ═══
            if (!hasTwo && newReport.budgetOverruns.isNotEmpty) ...[
              _buildBudgetAlertCard(
                newReport.budgetOverruns,
                isUrdu,
                fontFamily,
              ),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Section Card Builder
  // ═════════════════════════════════════════════════════════
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    Widget? badge,
    required List<Widget> children,
    String? fontFamily,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEF1F5)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (badge != null) badge,
              ],
            ),
          ),
          // Content
          ...children,
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // 1. Season Header (Single)
  // ═════════════════════════════════════════════════════════
  Widget _buildSingleHeader(
    Profession season,
    SeasonReportData report,
    bool isUrdu,
    String? fontFamily,
  ) {
    final displayName =
        isUrdu && season.name.isNotEmpty ? season.name : season.name;
    final crop = season.cropType.isNotEmpty
        ? '${isUrdu ? 'فصل' : 'Crop'}: ${season.cropType}'
        : '';

    final health = report.healthLabel;
    final healthColor = _healthColor(health);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 3,
                  children: [
                    if (crop.isNotEmpty)
                      Text(
                        crop,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          fontFamily: fontFamily,
                        ),
                      ),
                    if (report.areaAcres > 0)
                      Text(
                        '${_formatQty(report.areaAcres)} ${isUrdu ? "ایکڑ" : "acres"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          fontFamily: fontFamily,
                        ),
                      ),
                    if (report.productionMun > 0)
                      Text(
                        '${_formatQty(report.productionMun)} ${isUrdu ? "من" : "mun"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          fontFamily: fontFamily,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: healthColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  health == 'excellent' || health == 'good'
                      ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                      : PhosphorIcons.warning(PhosphorIconsStyle.fill),
                  size: 11,
                  color: healthColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _healthLabel(health, isUrdu),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: healthColor,
                    fontFamily: fontFamily,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // 1b. Season Header (Comparison)
  // ═════════════════════════════════════════════════════════
  Widget _buildCompareHeader(
    Profession newSeason,
    Profession oldSeason,
    bool isUrdu,
    String? fontFamily,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: _seasonPill(
              newSeason.name.isNotEmpty ? newSeason.name : 'A',
              AppTheme.themeColor,
              fontFamily,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              isUrdu ? 'بمقابلہ' : 'VS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppTheme.textSecondary,
                fontFamily: fontFamily,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Flexible(
            child: _seasonPill(
              oldSeason.name.isNotEmpty ? oldSeason.name : 'B',
              const Color(0xFFD97706),
              fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _seasonPill(String label, Color color, String? fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
                fontFamily: fontFamily,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // 2. Hero Summary (Single)
  // ═════════════════════════════════════════════════════════
  Widget _buildHeroSummary(
    SeasonReportData report,
    bool isUrdu,
    String? fontFamily,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _heroCard(
                label: isUrdu ? 'کل آمدن' : 'Total Income',
                value: 'Rs ${_formatFull(report.totalIncome)}',
                icon: PhosphorIcons.arrowUpRight(),
                iconColor: AppTheme.incomeColor,
                iconBg: AppTheme.incomeColor.withValues(alpha: 0.10),
                borderColor: AppTheme.incomeColor,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _heroCard(
                label: isUrdu ? 'کل خرچ' : 'Total Expense',
                value: 'Rs ${_formatFull(report.totalExpense)}',
                icon: PhosphorIcons.arrowDownLeft(),
                iconColor: AppTheme.expenseColor,
                iconBg: AppTheme.expenseColor.withValues(alpha: 0.10),
                borderColor: AppTheme.expenseColor,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _heroCard(
          label: isUrdu ? 'خالص منافع' : 'Net Profit',
          value: 'Rs ${_formatFull(report.netProfit)}',
          icon: PhosphorIcons.money(),
          iconColor: AppTheme.incomeColor,
          iconBg: AppTheme.incomeColor.withValues(alpha: 0.10),
          borderColor: const Color(0xFFD97706),
          fullWidth: true,
          fontFamily: fontFamily,
        ),
        const SizedBox(height: 10),
        _heroCard(
          label: isUrdu ? 'منافع کی شرح' : 'Profit Margin',
          value: '${report.profitMargin.toStringAsFixed(1)}%',
          icon: PhosphorIcons.chartLine(),
          iconColor: AppTheme.themeColor,
          iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
          borderColor: AppTheme.themeColor,
          fullWidth: true,
          fontFamily: fontFamily,
        ),
      ],
    );
  }

  Widget _heroCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    bool fullWidth = false,
    String? fontFamily,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.transparent,
            blurRadius: 0,
            offset: Offset.zero,
            spreadRadius: 0,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                    fontFamily: fontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: fullWidth ? 22 : 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkColor,
              letterSpacing: -0.6,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontFamily: null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // 2b. Hero Summary (Comparison)
  // ═════════════════════════════════════════════════════════
  Widget _buildCompareHeroSummary(
    SeasonReportData newR,
    SeasonReportData oldR,
    bool isUrdu,
    String? fontFamily,
  ) {
    return _sectionCard(
      title: isUrdu ? 'مالیاتی موازنہ' : 'Financial Comparison',
      icon: PhosphorIcons.money(),
      iconColor: AppTheme.themeColor,
      iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
      fontFamily: fontFamily,
      children: [
        _compareHeaderRow(isUrdu, newR.totalIncome, oldR.totalIncome),
        _compareRow(
          isUrdu ? 'کل آمدن' : 'Total Income',
          newR.totalIncome,
          oldR.totalIncome,
          fontFamily,
        ),
        _compareRow(
          isUrdu ? 'کل خرچ' : 'Total Expense',
          newR.totalExpense,
          oldR.totalExpense,
          fontFamily,
          lowerIsBetter: true,
        ),
        _compareRow(
          isUrdu ? 'خالص منافع' : 'Net Profit',
          newR.netProfit,
          oldR.netProfit,
          fontFamily,
        ),
        _compareRow(
          isUrdu ? 'منافع کی شرح' : 'Profit Margin',
          newR.profitMargin,
          oldR.profitMargin,
          fontFamily,
          isPercent: true,
        ),
      ],
    );
  }

  Widget _compareHeaderRow(bool isUrdu, double a, double b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        border: Border(bottom: BorderSide(color: Color(0xFFE1E5EC))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              isUrdu ? 'تفصیل' : 'Metric',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Expanded(
            flex: 12,
            child: Text(
              'A',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.themeColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Expanded(
            flex: 12,
            child: Text(
              'B',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFFD97706),
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              isUrdu ? 'فرق' : 'Diff',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareRow(
    String label,
    double newVal,
    double oldVal,
    String? fontFamily, {
    bool lowerIsBetter = false,
    bool isPercent = false,
  }) {
    final diff = newVal - oldVal;
    final isGood = lowerIsBetter ? diff < 0 : diff > 0;

    final newText = isPercent
        ? '${newVal.toStringAsFixed(1)}%'
        : _formatMoney(newVal);
    final oldText = isPercent
        ? '${oldVal.toStringAsFixed(1)}%'
        : _formatMoney(oldVal);
    final diffText = isPercent
        ? '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(1)}%'
        : '${diff >= 0 ? "+" : ""}${_formatMoney(diff)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              newText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkColor,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              oldText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A9199),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: (isGood
                        ? AppTheme.incomeColor
                        : AppTheme.expenseColor)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                diffText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isGood
                      ? AppTheme.incomeColor
                      : AppTheme.expenseColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // 3. Per Acre Metrics (Single)
  // ═════════════════════════════════════════════════════════
  Widget _buildPerAcreCard(
    SeasonReportData report,
    bool isUrdu,
    String? fontFamily,
  ) {
    return _sectionCard(
      title: isUrdu ? 'فی ایکڑ تفصیلات' : 'Per Acre Metrics',
      icon: PhosphorIcons.ruler(),
      iconColor: AppTheme.themeColor,
      iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
      badge: report.areaAcres > 0
          ? _badge(
              '${_formatQty(report.areaAcres)} ${isUrdu ? "ایکڑ" : "acres"}',
              AppTheme.themeColor,
            )
          : null,
      fontFamily: fontFamily,
      children: [
        if (report.areaAcres > 0)
          _metricRow(
            isUrdu ? 'کل رقبہ' : 'Total Area',
            '${_formatQty(report.areaAcres)} ${isUrdu ? "ایکڑ" : "acres"}',
            fontFamily,
          ),
        if (report.rentPerAcre > 0) ...[
          _metricRow(
            isUrdu ? 'فی ایکڑ ٹھیکہ' : 'Rent / Acre',
            'Rs ${_formatFull(report.rentPerAcre)}',
            fontFamily,
          ),
          _metricRow(
            isUrdu ? 'کل ٹھیکہ' : 'Total Lease',
            'Rs ${_formatFull(report.totalLease)}',
            fontFamily,
            valueColor: AppTheme.expenseColor,
          ),
        ],
        if (report.productionMun > 0) ...[
          _metricRow(
            isUrdu ? 'کل پیداوار' : 'Total Production',
            '${_formatQty(report.productionMun)} ${isUrdu ? "من" : "mun"}',
            fontFamily,
          ),
          _metricRow(
            isUrdu ? 'فی ایکڑ پیداوار' : 'Yield / Acre',
            '${_formatQty(report.yieldPerAcre)} ${isUrdu ? "من" : "mun"}',
            fontFamily,
            valueColor: AppTheme.incomeColor,
          ),
        ],
        if (report.areaAcres > 0) ...[
          _metricRow(
            isUrdu ? 'فی ایکڑ خرچ' : 'Cost / Acre',
            'Rs ${_formatFull(report.costPerAcre)}',
            fontFamily,
            valueColor: AppTheme.expenseColor,
          ),
          _metricRow(
            isUrdu ? 'فی ایکڑ منافع' : 'Profit / Acre',
            'Rs ${_formatFull(report.profitPerAcre)}',
            fontFamily,
            valueColor: AppTheme.incomeColor,
          ),
        ],
        if (report.productionMun > 0) ...[
          _metricRow(
            isUrdu ? 'فی من اوسط ریٹ' : 'Avg Rate / Mun',
            'Rs ${_formatFull(report.avgRatePerMun)}',
            fontFamily,
          ),
          _metricRow(
            isUrdu ? 'فی من لاگت' : 'Cost / Mun',
            'Rs ${_formatFull(report.costPerMun)}',
            fontFamily,
            valueColor: AppTheme.expenseColor,
          ),
        ],
      ],
    );
  }

  Widget _metricRow(
    String label,
    String value,
    String? fontFamily, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                fontFamily: fontFamily,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: valueColor ?? AppTheme.darkColor,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // 3b. Per Acre (Comparison)
  // ═════════════════════════════════════════════════════════
  Widget _buildComparePerAcreCard(
    SeasonReportData newR,
    SeasonReportData oldR,
    bool isUrdu,
    String? fontFamily,
  ) {
    return _sectionCard(
      title: isUrdu ? 'فی ایکڑ موازنہ' : 'Per Acre Comparison',
      icon: PhosphorIcons.ruler(),
      iconColor: AppTheme.themeColor,
      iconBg: AppTheme.themeColor.withValues(alpha: 0.10),
      fontFamily: fontFamily,
      children: [
        _compareHeaderRow(isUrdu, 0, 0),
        _compareRow(
          isUrdu ? 'رقبہ' : 'Area',
          newR.areaAcres,
          oldR.areaAcres,
          fontFamily,
        ),
        _compareRow(
          isUrdu ? 'فی ایکڑ ٹھیکہ' : 'Rent / Acre',
          newR.rentPerAcre,
          oldR.rentPerAcre,
          fontFamily,
          lowerIsBetter: true,
        ),
        _compareRow(
          isUrdu ? 'فی ایکڑ پیداوار' : 'Yield / Acre',
          newR.yieldPerAcre,
          oldR.yieldPerAcre,
          fontFamily,
        ),
        _compareRow(
          isUrdu ? 'فی ایکڑ خرچ' : 'Cost / Acre',
          newR.costPerAcre,
          oldR.costPerAcre,
          fontFamily,
          lowerIsBetter: true,
        ),
        _compareRow(
          isUrdu ? 'فی ایکڑ منافع' : 'Profit / Acre',
          newR.profitPerAcre,
          oldR.profitPerAcre,
          fontFamily,
        ),
        _compareRow(
          isUrdu ? 'فی من اوسط ریٹ' : 'Avg Rate / Mun',
          newR.avgRatePerMun,
          oldR.avgRatePerMun,
          fontFamily,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════
  // 4. Target Card (Single only)
  // ═════════════════════════════════════════════════════════
  Widget _buildTargetCard(
    SeasonReportData report,
    bool isUrdu,
    String? fontFamily,
  ) {
    if (report.targetProduction <= 0 && report.benchmarkCostPerUnit <= 0) {
      return const SizedBox.shrink();
    }

    return _sectionCard(
      title: isUrdu ? 'ہدف کی کارکردگی' : 'Target Progress',
      icon: PhosphorIcons.target(),
      iconColor: const Color(0xFFD97706),
      iconBg: const Color(0xFFD97706).withValues(alpha: 0.10),
      fontFamily: fontFamily,
      children: [
        if (report.targetProduction > 0)
          _targetBar(
            label: isUrdu ? 'پیداوار کا ہدف' : 'Production Target',
            value: report.productionMun,
            target: report.targetProduction,
            unit: isUrdu ? 'من' : 'mun',
            fontFamily: fontFamily,
          ),
        if (report.benchmarkCostPerUnit > 0)
          _targetBar(
            label: isUrdu ? 'لاگت کا معیار' : 'Cost Benchmark',
            value: report.benchmarkCostPerUnit,
            target: report.costPerMun > 0 ? report.costPerMun : 1,
            isInverse: true,
            unit: 'Rs',
            fontFamily: fontFamily,
            inverseLabel: isUrdu ? 'اصل' : 'Actual',
          ),
      ],
    );
  }

  Widget _targetBar({
    required String label,
    required double value,
    required double target,
    required String unit,
    String? fontFamily,
    bool isInverse = false,
    String? inverseLabel,
  }) {
    double percent;
    if (isInverse) {
      percent = target > 0 ? (value / target * 100).clamp(0, 100) : 0;
    } else {
      percent = target > 0 ? (value / target * 100).clamp(0, 100) : 0;
    }

    final health = percent >= 80
        ? 'excellent'
        : percent >= 60
            ? 'good'
            : percent >= 40
                ? 'fair'
                : 'poor';
    final color = _healthColor(health);

    final valueText =
        unit == 'Rs' ? 'Rs ${_formatFull(value)}' : '${_formatQty(value)} $unit';
    final targetText = unit == 'Rs'
        ? 'Rs ${_formatFull(target)}'
        : '${_formatQty(target)} $unit';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: const Color(0xFFEEF1F5),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percent / 100,
                child: Container(color: color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  isInverse
                      ? '${inverseLabel ?? ""}: $targetText'
                      : '$valueText / $targetText',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // 5. Category Card (Single)
  // ═════════════════════════════════════════════════════════
  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String badge,
    required List<CategoryBreakdown> categories,
    required double total,
    required bool isIncome,
    required bool isUrdu,
    String? fontFamily,
  }) {
    final colors = _categoryColors();

    return _sectionCard(
      title: title,
      icon: icon,
      iconColor: iconColor,
      iconBg: iconBg,
      badge: _badge(badge, iconColor),
      fontFamily: fontFamily,
      children: [
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isUrdu ? 'کوئی زمرہ نہیں' : 'No categories',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontFamily: fontFamily,
              ),
            ),
          )
        else
          ...categories.asMap().entries.map((entry) {
            final idx = entry.key;
            final cat = entry.value;
            final color = colors[idx % colors.length];
            return _catRow(cat, total, color, isUrdu, fontFamily);
          }),
      ],
    );
  }

  Widget _catRow(
    CategoryBreakdown cat,
    double total,
    Color color,
    bool isUrdu,
    String? fontFamily,
  ) {
    final percent = cat.percentOf(total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cat.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rs ${_formatFull(cat.amount)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkColor,
                  letterSpacing: -0.3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 5,
              color: const Color(0xFFEEF1F5),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (percent / 100).clamp(0, 1),
                child: Container(color: color),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                isUrdu
                    ? '${cat.entriesCount} اندراج'
                    : '${cat.entriesCount} entries',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // 5b. Category Card (Comparison)
  // ═════════════════════════════════════════════════════════
  Widget _buildCompareCategoryCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required List<CategoryBreakdown> newCategories,
    required List<CategoryBreakdown> oldCategories,
    required double newTotal,
    required double oldTotal,
    required bool isIncome,
    required bool isUrdu,
    String? fontFamily,
  }) {
    final allNames = <String>{};
    for (final c in newCategories) {
      allNames.add(c.name);
    }
    for (final c in oldCategories) {
      allNames.add(c.name);
    }

    final rows = allNames.map((name) {
      final newC = newCategories.firstWhere(
        (c) => c.name == name,
        orElse: () => CategoryBreakdown(name: name, amount: 0, isIncome: isIncome),
      );
      final oldC = oldCategories.firstWhere(
        (c) => c.name == name,
        orElse: () => CategoryBreakdown(name: name, amount: 0, isIncome: isIncome),
      );
      return MapEntry(newC, oldC);
    }).toList()
      ..sort((a, b) => b.key.amount.compareTo(a.key.amount));

    return _sectionCard(
      title: title,
      icon: icon,
      iconColor: iconColor,
      iconBg: iconBg,
      fontFamily: fontFamily,
      children: [
        _compareHeaderRow(isUrdu, 0, 0),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isUrdu ? 'کوئی زمرہ نہیں' : 'No categories',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontFamily: fontFamily,
              ),
            ),
          )
        else
          ...rows.map((entry) {
            return _compareRow(
              entry.key.name,
              entry.key.amount,
              entry.value.amount,
              fontFamily,
              lowerIsBetter: !isIncome,
            );
          }),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            border: Border(top: BorderSide(color: Color(0xFFE1E5EC), width: 2)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  isUrdu ? 'کل' : 'TOTAL',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  _formatMoney(newTotal),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkColor,
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  _formatMoney(oldTotal),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8A9199),
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  '${newTotal - oldTotal >= 0 ? "+" : ""}${_formatMoney(newTotal - oldTotal)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: (isIncome
                            ? newTotal - oldTotal >= 0
                            : newTotal - oldTotal <= 0)
                        ? AppTheme.incomeColor
                        : AppTheme.expenseColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════
  // 6. Budget Alert Card
  // ═════════════════════════════════════════════════════════
  Widget _buildBudgetAlertCard(
    List<MapEntry<String, MapEntry<double, double>>> overruns,
    bool isUrdu,
    String? fontFamily,
  ) {
    return _sectionCard(
      title: isUrdu ? 'بجٹ کی حد' : 'Budget Alerts',
      icon: PhosphorIcons.bellRinging(),
      iconColor: AppTheme.expenseColor,
      iconBg: AppTheme.expenseColor.withValues(alpha: 0.10),
      badge: _badge('${overruns.length}', AppTheme.expenseColor),
      fontFamily: fontFamily,
      children: overruns.map((entry) {
        final name = entry.key;
        final limit = entry.value.key;
        final actual = entry.value.value;
        final over = actual - limit;
        final percent = limit > 0 ? ((over / limit) * 100) : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metricRow(
              '$name — ${isUrdu ? "بجٹ" : "Budget"}',
              'Rs ${_formatFull(limit)}',
              fontFamily,
            ),
            _metricRow(
              '$name — ${isUrdu ? "اصل" : "Actual"}',
              'Rs ${_formatFull(actual)}',
              fontFamily,
              valueColor: AppTheme.expenseColor,
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.expenseColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIcons.warning(PhosphorIconsStyle.fill),
                    size: 14,
                    color: AppTheme.expenseColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUrdu
                          ? '$name کی حد سے ${percent.toStringAsFixed(1)}% زیادہ (Rs ${_formatFull(over)})'
                          : '$name exceeded by ${percent.toStringAsFixed(1)}% (Rs ${_formatFull(over)})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.expenseColor,
                        fontFamily: fontFamily,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ═════════════════════════════════════════════════════════
  // Category Colors
  // ═════════════════════════════════════════════════════════
  List<Color> _categoryColors() {
    return const [
      Color(0xFF515D11), // income olive
      Color(0xFFD97706), // warning
      Color(0xFF1D6ED6), // theme
      Color(0xFFC83120), // expense
      Color(0xFF607D8B), // gold
      Color(0xFF8A9199), // gray
      Color(0xFF6B7A1F), // dark olive
    ];
  }

  // ═════════════════════════════════════════════════════════
  // Health Helpers
  // ═════════════════════════════════════════════════════════
  Color _healthColor(String health) {
    // ═════════════════════════════════════════════════════════
    switch (health) {
      case 'excellent':
        return AppTheme.incomeColor;
      case 'good':
        return AppTheme.themeColor;
      case 'fair':
        return const Color(0xFFD97706);
      default:
        return AppTheme.expenseColor;
    }
  }

  String _healthLabel(String health, bool isUrdu) {
    switch (health) {
      case 'excellent':
        return isUrdu ? 'بہترین' : 'Excellent';
      case 'good':
        return isUrdu ? 'اچھا' : 'Good';
      case 'fair':
        return isUrdu ? 'مناسب' : 'Fair';
      default:
        return isUrdu ? 'کمزور' : 'Poor';
    }
  }
}
