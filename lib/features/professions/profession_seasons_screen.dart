// lib/features/professions/profession_seasons_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart'
    as transaction_model;
import 'package:account_app/core/config/professions_config.dart';
import 'categories_management_screen.dart';
import 'season_comparison_screen.dart';
import 'complete_season_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/utils/receipt_helper.dart';
import 'package:account_app/features/professions/add_project_transaction_screen.dart';

class ProfessionSeasonsScreen extends StatefulWidget {
  final Profession masterProfession;

  const ProfessionSeasonsScreen({super.key, required this.masterProfession});

  @override
  State<ProfessionSeasonsScreen> createState() =>
      _ProfessionSeasonsScreenState();
}

class _ProfessionSeasonsScreenState extends State<ProfessionSeasonsScreen> {
  List<String> _incomeCategories = ['تنخواہ', 'فری لانس', 'کاروبار', 'دیگر'];
  List<String> _expenseCategories = [
    'کرایہ',
    'بجلی',
    'پانی',
    'ٹرانسپورٹ',
    'دیگر'
  ];
  String? _expandedSeasonId;

  bool get _isAgriculture =>
      ProfessionsConfig.categoryTypeFor(widget.masterProfession) ==
      ProfessionCategory.agriculture;

  String _workNoun(bool isUrdu, {bool plural = false}) {
    if (_isAgriculture) {
      return isUrdu
          ? (plural ? 'سیزنز' : 'سیزن')
          : (plural ? 'Seasons' : 'Season');
    }
    return isUrdu
        ? (plural ? 'پروجیکٹس' : 'پروجیکٹ')
        : (plural ? 'Projects' : 'Project');
  }

  @override
  void initState() {
    super.initState();
    _parseCategories();
  }

  void _parseCategories() {
    if (widget.masterProfession.categories.isNotEmpty) {
      final cleanCategories = widget.masterProfession.categories
          .map((c) {
            if (c.startsWith('INC:')) return c.substring(4);
            if (c.startsWith('EXP:')) return c.substring(4);
            return c;
          })
          .toSet()
          .toList();

      setState(() {
        _expenseCategories = cleanCategories;
        _incomeCategories = cleanCategories;
      });
    }
  }

  String _getProfitLabel(double income, double netProfit, bool isUrdu) {
    if (income == 0 && netProfit <= 0) {
      return isUrdu ? 'آمدنی درج نہیں' : 'No Income';
    }
    if (netProfit > 0) {
      return isUrdu ? 'بچت' : 'Savings';
    }
    return isUrdu ? 'خسارہ' : 'Loss';
  }

  Color _getProfitColor(double income, double netProfit) {
    if (income == 0 && netProfit <= 0) {
      return Colors.grey.shade700;
    }
    if (netProfit > 0) {
      return AppTheme.incomeColor;
    }
    return AppTheme.expenseColor;
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.darkColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.masterProfession.name,
          style: TextStyle(
              color: Colors.white,
              fontFamily: fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.gear(), color: Colors.white),
            onPressed: () => _navigateToCategoriesScreen(context, isUrdu),
            tooltip: isUrdu ? 'زمرے مینج کریں' : 'Manage Categories',
          ),
        ],
      ),
      body: Consumer<DatabaseService>(
        builder: (context, databaseService, child) {
          final seasons =
              databaseService.getSeasons(widget.masterProfession.id);
          final activeSeason =
              seasons.where((s) => s.isActive ?? true).toList().isNotEmpty
                  ? seasons.firstWhere((s) => s.isActive ?? true)
                  : null;
          final completedSeasons =
              seasons.where((s) => !(s.isActive ?? true)).toList();

          completedSeasons.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          final masterProfession =
              databaseService.getProfession(widget.masterProfession.id) ??
                  widget.masterProfession;
          final double headerIncome = masterProfession.totalIncome;
          final double headerExpense = masterProfession.totalExpense;
          final netProfit = headerIncome - headerExpense;

          return Column(
            children: [
              _buildCompactStatsHeader(context, headerIncome, headerExpense,
                  netProfit, isUrdu, fontFamily),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (activeSeason != null) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: AppTheme.themeColor
                                      .withValues(alpha: 0.05),
                                  blurRadius: 10)
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onLongPress: () => _showSeasonOptions(
                                    context,
                                    activeSeason,
                                    isUrdu,
                                    fontFamily,
                                    databaseService),
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  children: [
                                    // Top Bar: Season Name + Year, Area, Start Date & Running Status
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      child: Row(
                                        children: [
                                          Text(
                                            activeSeason.season.isNotEmpty
                                                ? activeSeason.season
                                                : (activeSeason
                                                        .cropType.isNotEmpty
                                                    ? "${activeSeason.cropType} ${activeSeason.createdAt.year}"
                                                    : activeSeason.name),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppTheme.darkColor,
                                              fontFamily: fontFamily,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (activeSeason.areaAcres > 0) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFBFDBFE)),
                                              ),
                                              child: Text(
                                                '${activeSeason.areaAcres.toStringAsFixed(0)} ${isUrdu ? 'ایکڑ' : 'Acres'}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      const Color(0xFF1D4ED8),
                                                  fontFamily: fontFamily,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          const Spacer(),
                                          Text(
                                            DateFormat('dd/MM/yy')
                                                .format(activeSeason.createdAt),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.themeColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration:
                                                      const BoxDecoration(
                                                          color: AppTheme
                                                              .themeColor,
                                                          shape:
                                                              BoxShape.circle),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  isUrdu
                                                      ? 'جاری ہے'
                                                      : 'Running',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          AppTheme.themeColor,
                                                      fontFamily: fontFamily),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(
                                        height: 1, indent: 12, endIndent: 12),
                                    // Stats Row: Always visible
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildSmallStat(
                                              isUrdu ? 'آمدنی' : 'In',
                                              activeSeason.totalIncome,
                                              AppTheme.incomeColor,
                                              isUrdu,
                                              fontFamily),
                                          _buildSmallStat(
                                              isUrdu ? 'خرچ' : 'Out',
                                              activeSeason.totalExpense,
                                              AppTheme.expenseColor,
                                              isUrdu,
                                              fontFamily),
                                          _buildSmallStat(
                                              _getProfitLabel(
                                                  activeSeason.totalIncome,
                                                  activeSeason.netProfit,
                                                  isUrdu),
                                              activeSeason.netProfit,
                                              _getProfitColor(
                                                  activeSeason.totalIncome,
                                                  activeSeason.netProfit),
                                              isUrdu,
                                              fontFamily),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              _buildTransactionsForSeason(
                                  context,
                                  databaseService,
                                  activeSeason,
                                  isUrdu,
                                  fontFamily,
                                  hideSummary: true),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.themeColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.themeColor
                                      .withValues(alpha: 0.1),
                                  style: BorderStyle.solid),
                            ),
                            child: Column(
                              children: [
                                Icon(PhosphorIcons.calendarPlus(),
                                    size: 48, color: AppTheme.themeColor),
                                const SizedBox(height: 12),
                                Text(
                                  isUrdu
                                      ? 'کوئی جاری ${_workNoun(isUrdu)} نہیں ہے'
                                      : 'No active ${_workNoun(isUrdu).toLowerCase()} found',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.darkColor,
                                      fontFamily: fontFamily),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isUrdu
                                      ? 'نیا ${_workNoun(isUrdu)} شروع کریں تاکہ آپ اپنا حساب الگ رکھ سکیں۔'
                                      : 'Start a new ${_workNoun(isUrdu).toLowerCase()} to keep your records organized.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                      fontFamily: fontFamily),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _showStartSeasonDialog(
                                      context, isUrdu, fontFamily),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.themeColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                      isUrdu
                                          ? 'نیا ${_workNoun(isUrdu)} شروع کریں'
                                          : 'Start New ${_workNoun(isUrdu)}',
                                      style: TextStyle(fontFamily: fontFamily)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (completedSeasons.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(12, 24, 12, 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.darkColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AppTheme.darkColor.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isUrdu
                                    ? 'مکمل شدہ ${_workNoun(isUrdu, plural: true)}'
                                    : 'Completed ${_workNoun(isUrdu, plural: true)}',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkColor,
                                    fontFamily: fontFamily),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final season = completedSeasons[index];
                            return _buildCompactSeasonItem(context, season,
                                isUrdu, fontFamily, databaseService);
                          },
                          childCount: completedSeasons.length,
                        ),
                      ),
                    ],
                    const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton:
          Consumer<DatabaseService>(builder: (context, db, child) {
        final activeSeason = db
            .getSeasons(widget.masterProfession.id)
            .where((s) => s.isActive ?? true)
            .firstOrNull;
        if (activeSeason == null) return const SizedBox.shrink();

        return FloatingActionButton(
          onPressed: () => _navigateToAddTransaction(context, activeSeason),
          backgroundColor: AppTheme.darkColor,
          shape: const CircleBorder(),
          tooltip: isUrdu ? 'نیا اندراج' : 'Add Transaction',
          child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 30),
        );
      }),
    );
  }

  Widget _buildCompactStatsHeader(BuildContext context, double income,
      double expense, double netProfit, bool isUrdu, String fontFamily) {
    final netLabel = _getProfitLabel(income, netProfit, isUrdu);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 56,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildHeaderStatItem(
                isUrdu ? "آمدنی" : "Income",
                income,
                Colors.white70,
                fontFamily,
                PhosphorIcons.arrowDownLeft(),
              ),
              _buildStatDivider(),
              _buildHeaderStatItem(
                isUrdu ? "خرچ" : "Expense",
                expense,
                Colors.white70,
                fontFamily,
                PhosphorIcons.arrowUpRight(),
              ),
              _buildStatDivider(),
              _buildHeaderStatItem(
                netLabel,
                netProfit.abs(),
                Colors.white70,
                fontFamily,
                PhosphorIcons.trendUp(),
                isBold: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final dbService = Provider.of<DatabaseService>(context, listen: false);
                final seasons = dbService.getSeasons(widget.masterProfession.id);
                if (seasons.isNotEmpty) {
                  _openComparison(context, seasons);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeasonComparisonScreen(
                        seasonA: widget.masterProfession,
                      ),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIcons.chartLine(),
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUrdu
                          ? 'تفصیلی سیزن رپورٹ اور موازنہ'
                          : 'Detailed Season Report & Comparison',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatItem(String label, double amount, Color iconColor,
      String fontFamily, IconData icon,
      {bool isBold = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
                color: Colors.white70, fontSize: 11, fontFamily: fontFamily),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Rs ${amount.toStringAsFixed(0)}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isBold ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: '',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() =>
      Container(height: 20, width: 1, color: Colors.white12);

  Widget _buildCompactSeasonItem(BuildContext context, Profession season,
      bool isUrdu, String fontFamily, DatabaseService db) {
    final isExpanded = _expandedSeasonId == season.id;
    final isBaseRecord =
        season.season == (isUrdu ? 'بنیادی ریکارڈ' : 'Base Record');

    final df = DateFormat('dd/MM/yy');
    final start = df.format(season.createdAt);
    final end = df.format(season.updatedAt);

    final profitLabel =
        _getProfitLabel(season.totalIncome, season.netProfit, isUrdu);
    final profitColor = _getProfitColor(season.totalIncome, season.netProfit);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: isExpanded
              ? AppTheme.darkColor.withValues(alpha: 0.08)
              : AppTheme.darkColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isExpanded
                  ? AppTheme.themeColor.withOpacity(0.2)
                  : AppTheme.darkColor.withValues(alpha: 0.1)),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 5)
                ]
              : []),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedSeasonId = isExpanded ? null : season.id;
              });
            },
            onLongPress: () {
              _showSeasonOptions(context, season, isUrdu, fontFamily, db,
                  isBaseRecord: isBaseRecord);
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Crop / Season Name with Year
                      Text(
                        season.season.isNotEmpty
                            ? season.season
                            : (season.cropType.isNotEmpty
                                ? "${season.cropType} ${season.createdAt.year}"
                                : season.name),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.darkColor,
                          fontFamily: fontFamily,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Area Badge if available
                      if (season.areaAcres > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            '${season.areaAcres.toStringAsFixed(0)} ${isUrdu ? 'ایکڑ' : 'Acres'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1D4ED8),
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      const Spacer(),

                      // Dates
                      Text(
                        "$start - $end",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 12, endIndent: 12),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSmallStat(
                          isUrdu ? 'آمدنی' : 'In',
                          season.totalIncome,
                          AppTheme.incomeColor,
                          isUrdu,
                          fontFamily),
                      _buildSmallStat(
                          isUrdu ? 'خرچ' : 'Out',
                          season.totalExpense,
                          AppTheme.expenseColor,
                          isUrdu,
                          fontFamily),
                      _buildSmallStat(profitLabel, season.netProfit,
                          profitColor, isUrdu, fontFamily),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildTransactionsForSeason(context, db, season, isUrdu, fontFamily,
                hideSummary: true),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsForSeason(BuildContext context, DatabaseService db,
      Profession season, bool isUrdu, String fontFamily,
      {bool hideSummary = false}) {
    final txs = db
        .getAllTransactions()
        .where((t) => t.professionId == season.id)
        .toList();
    txs.sort((a, b) => b.date.compareTo(a.date));

    if (txs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: Text(isUrdu ? 'کوئی ٹرانزیکشن نہیں' : 'No transactions',
                style: const TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: txs.length,
          itemBuilder: (context, index) {
            return _buildTransactionItem(
                context, txs[index], isUrdu, fontFamily,
                isLast: index == txs.length - 1);
          },
        ),
      ],
    );
  }

  Widget _buildTransactionItem(BuildContext context,
      transaction_model.Transaction t, bool isUrdu, String fontFamily,
      {bool isLast = false}) {
    final isIncome = t.professionSide == 'income';
    final db = Provider.of<DatabaseService>(context, listen: false);
    final account = db.getAccount(t.accountId);
    final String displayName = account?.name ?? t.category;

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () => ReceiptHelper.showReceiptDialog(
            context,
            transaction: t,
            isLocalTransaction: true,
          ),
          onLongPress: () =>
              _showDeleteTransactionDialog(context, t, isUrdu, fontFamily, db),
          title: Text(t.description.isNotEmpty ? t.description : displayName,
              style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.darkColor)),
          subtitle: Row(
            children: [
              Text(DateFormat('dd MMM').format(t.date),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              if (t.description.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        color: Colors.grey, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                        color: AppTheme.themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        fontFamily: fontFamily),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              if (t.description.isNotEmpty) const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      isIncome
                          ? PhosphorIcons.arrowDownLeft()
                          : PhosphorIcons.arrowUpRight(),
                      color: isIncome
                          ? AppTheme.incomeColor
                          : AppTheme.expenseColor,
                      size: 12),
                  const SizedBox(width: 2),
                  Text('Rs ${t.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isIncome
                              ? AppTheme.incomeColor
                              : AppTheme.expenseColor)),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 12, endIndent: 12, thickness: 0.5),
      ],
    );
  }

  void _navigateToAddTransaction(BuildContext context, Profession season) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddProjectTransactionScreen(
                  profession: season,
                )));
  }

  void _showDeleteTransactionDialog(
      BuildContext context,
      transaction_model.Transaction t,
      bool isUrdu,
      String fontFamily,
      DatabaseService db) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isUrdu ? 'ٹرانزیکشن حذف کریں؟' : 'Delete Transaction?',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isUrdu
              ? 'کیا آپ واقعی اس ٹرانزیکشن کو حذف کرنا چاہتے ہیں؟'
              : 'Are you sure you want to delete this transaction?',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isUrdu ? 'منسوخ' : 'Cancel',
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await db.deleteTransaction(t.id);
              if (context.mounted) Navigator.pop(context);
              AppToast.success(
                context,
                isUrdu ? 'حذف کر دیا گیا' : 'Deleted successfully',
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.expenseColor,
                foregroundColor: Colors.white),
            child: Text(isUrdu ? 'حذف کریں' : 'Delete',
                style: TextStyle(fontFamily: fontFamily)),
          ),
        ],
      ),
    );
  }

  void _navigateToCategoriesScreen(BuildContext context, bool isUrdu) {
    final cleanCategories = widget.masterProfession.categories
        .map((c) {
          if (c.contains(':')) return c.split(':')[1];
          return c;
        })
        .toSet()
        .toList();

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CategoriesManagementScreen(
                categories: cleanCategories,
                isUrdu: isUrdu,
                categoryType:
                    ProfessionsConfig.categoryTypeFor(widget.masterProfession),
                onCategoriesUpdated: (newCats) async {
                  final db =
                      Provider.of<DatabaseService>(context, listen: false);

                  final updatedProfession = widget.masterProfession
                      .copyWith(categories: newCats, updatedAt: DateTime.now());

                  await db.updateProfession(updatedProfession);

                  final activeSeason = db
                      .getSeasons(widget.masterProfession.id)
                      .where((s) => s.isActive ?? true)
                      .firstOrNull;

                  if (activeSeason != null) {
                    await db.updateProfession(activeSeason.copyWith(
                        categories: newCats, updatedAt: DateTime.now()));
                  }

                  if (mounted) {
                    AppToast.success(
                      context,
                      isUrdu
                          ? 'زمرہ جات محفوظ کر لیے گئے ہیں'
                          : 'Categories saved successfully',
                    );
                  }
                })));
  }

  // 🌾 Screen 1: Start New Season Dialog
  void _showStartSeasonDialog(
      BuildContext context, bool isUrdu, String fontFamily) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final categoryType =
        ProfessionsConfig.categoryTypeFor(widget.masterProfession);
    final isAgriculture = categoryType == ProfessionCategory.agriculture;
    String selectedCrop = 'دھان';
    final TextEditingController nameController = TextEditingController(
      text: isAgriculture ? 'دھان ${DateTime.now().year}' : '',
    );
    final TextEditingController areaController = TextEditingController();
    final TextEditingController rentController = TextEditingController();
    final nameFocusNode = FocusNode();
    final areaFocusNode = FocusNode();
    final rentFocusNode = FocusNode();
    bool hasFocusedInput = false;
    bool focusListenersAttached = false;

    final crops = [
      {'name': 'دھان', 'icon': PhosphorIcons.plant()},
      {'name': 'گندم', 'icon': PhosphorIcons.plant()},
      {'name': 'کپاس', 'icon': PhosphorIcons.cloud()},
      {'name': 'گنا', 'icon': PhosphorIcons.plant()},
      {'name': 'مکئی', 'icon': PhosphorIcons.plant()},
      {'name': 'سبزیاں', 'icon': PhosphorIcons.leaf()},
      {'name': 'پھل', 'icon': PhosphorIcons.appleLogo()},
      {'name': 'دیگر', 'icon': PhosphorIcons.plus()},
    ];

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!focusListenersAttached) {
            focusListenersAttached = true;
            for (final focusNode in [
              nameFocusNode,
              if (isAgriculture) areaFocusNode,
              if (isAgriculture) rentFocusNode,
            ]) {
              focusNode.addListener(() {
                final isFocused = nameFocusNode.hasFocus ||
                    (isAgriculture &&
                        (areaFocusNode.hasFocus || rentFocusNode.hasFocus));
                if (isFocused != hasFocusedInput) {
                  setDialogState(() => hasFocusedInput = isFocused);
                }
              });
            }
          }

          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isAgriculture
                  ? (isUrdu ? 'نیا سیزن شروع کریں' : 'Start New Season')
                  : (isUrdu ? 'نیا پروجیکٹ شروع کریں' : 'Start New Project'),
              style: TextStyle(
                  fontFamily: fontFamily, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAgriculture) ...[
                      Text(
                        isUrdu ? 'فصل کی قسم منتخب کریں' : 'Select Crop Type',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontFamily: fontFamily),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: crops.map((crop) {
                          final cropName = crop['name'] as String;
                          return ChoiceChip(
                            label: Text(cropName),
                            avatar: Icon(
                              crop['icon'] as IconData,
                              size: 16,
                              color: selectedCrop == cropName
                                  ? AppTheme.themeColor
                                  : AppTheme.darkColor,
                            ),
                            selected: selectedCrop == cropName,
                            onSelected: (_) {
                              setDialogState(() {
                                selectedCrop = cropName;
                                nameController.text =
                                    '$cropName ${DateTime.now().year}';
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Grouped Inputs Container (Master Profile Style)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasFocusedInput
                              ? AppTheme.themeColor
                              : Colors.grey.shade200,
                          width: hasFocusedInput ? 1.5 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: nameController,
                              focusNode: nameFocusNode,
                              style: const TextStyle(color: AppTheme.darkColor),
                              decoration: InputDecoration(
                                labelText: isAgriculture
                                    ? (isUrdu ? 'سیزن کا نام' : 'Season Name')
                                    : (isUrdu
                                        ? 'پروجیکٹ / کام کا نام'
                                        : 'Project / Work Name'),
                                labelStyle: TextStyle(fontFamily: fontFamily),
                                prefixIcon: Icon(PhosphorIcons.textT(),
                                    color: AppTheme.themeColor),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                            if (isAgriculture) ...[
                              const Divider(height: 1),
                              TextField(
                                controller: areaController,
                                focusNode: areaFocusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style:
                                    const TextStyle(color: AppTheme.darkColor),
                                decoration: InputDecoration(
                                  labelText: isUrdu
                                      ? 'رقبہ (ایکڑ) — اختیاری'
                                      : 'Area (Acres) - Optional',
                                  hintText: 'مثلاً 12',
                                  labelStyle: TextStyle(fontFamily: fontFamily),
                                  prefixIcon: Icon(PhosphorIcons.mapPin(),
                                      color: AppTheme.themeColor),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                              ),
                              const Divider(height: 1),
                              TextField(
                                controller: rentController,
                                focusNode: rentFocusNode,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style:
                                    const TextStyle(color: AppTheme.darkColor),
                                decoration: InputDecoration(
                                  labelText: isUrdu
                                      ? 'کرایہ زمین فی ایکڑ — اختیاری'
                                      : 'Land Rent per Acre - Optional',
                                  hintText: 'اگر اپنی زمین ہے تو خالی چھوڑیں',
                                  hintStyle: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                      fontFamily: fontFamily),
                                  labelStyle: TextStyle(fontFamily: fontFamily),
                                  prefixIcon: Icon(PhosphorIcons.money(),
                                      color: AppTheme.themeColor),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isUrdu ? 'منسوخ' : 'Cancel'),
              ),
              AppButton(
                text: isAgriculture
                    ? (isUrdu ? 'سیزن شروع کریں' : 'Start Season')
                    : (isUrdu ? 'پروجیکٹ شروع کریں' : 'Start Project'),
                onPressed: () async {
                  final seasonName = nameController.text.trim();
                  if (seasonName.isEmpty) {
                    AppToast.warning(
                      context,
                      isUrdu ? 'نام درج کریں' : 'Please enter a name',
                    );
                    return;
                  }
                  final area = double.tryParse(areaController.text) ?? 0.0;
                  final rent = double.tryParse(rentController.text) ?? 0.0;

                  final newSeason = Profession(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: widget.masterProfession.name,
                    categories: widget.masterProfession.categories,
                    description: widget.masterProfession.description,
                    totalProduction: 0,
                    productionUnit: widget.masterProfession.productionUnit,
                    season: seasonName,
                    categoryType: categoryType,
                    cropType: isAgriculture ? selectedCrop : '',
                    areaAcres: area,
                    rentPerAcre: rent,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    isActive: true,
                    isMaster: false,
                    parentId: widget.masterProfession.id,
                  );

                  await db.addProfession(newSeason);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      nameController.dispose();
      areaController.dispose();
      rentController.dispose();
      nameFocusNode.dispose();
      areaFocusNode.dispose();
      rentFocusNode.dispose();
    });
  }

  void _showSeasonOptions(BuildContext context, Profession season, bool isUrdu,
      String fontFamily, DatabaseService db,
      {bool isBaseRecord = false}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                isBaseRecord
                    ? (isUrdu
                        ? 'بنیادی ریکارڈ کے اختیارات'
                        : 'Base Record Options')
                    : '${_workNoun(isUrdu)}: ${season.season}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: fontFamily),
              ),
            ),
            if (!isBaseRecord && (season.isActive ?? true))
              ListTile(
                leading: Icon(PhosphorIcons.checkCircle(),
                    color: AppTheme.incomeColor),
                title: Text(
                  isUrdu
                      ? '${_workNoun(isUrdu)} مکمل کریں'
                      : 'Complete ${_workNoun(isUrdu)}',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CompleteSeasonScreen(season: season),
                    ),
                  );
                },
              ),
            if (!isBaseRecord && !(season.isActive ?? true)) ...[
              ListTile(
                leading: Icon(PhosphorIcons.pencilLine(),
                    color: AppTheme.themeColor),
                title: Text(
                  isUrdu ? 'تفصیل شامل کریں / ترمیم' : 'Add / Edit Details',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CompleteSeasonScreen(
                        season: season,
                        isEditingDetails: true,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(PhosphorIcons.playCircle(),
                    color: AppTheme.themeColor),
                title: Text(
                  isUrdu ? 'دوبارہ فعال کریں' : 'Reactivate',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _reactivateSeason(context, season, isUrdu, fontFamily, db);
                },
              ),
            ],
            ListTile(
              leading:
                  Icon(PhosphorIcons.trash(), color: AppTheme.expenseColor),
              title: Text(
                isBaseRecord
                    ? (isUrdu ? 'بنیادی ریکارڈ صاف کریں' : 'Clear Base Record')
                    : (isUrdu ? 'حذف کریں' : 'Delete'),
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
              ),
              onTap: () {
                Navigator.pop(context);
                if (isBaseRecord) {
                  _showClearBaseRecordDialog(context, isUrdu, fontFamily, db);
                } else {
                  _showDeleteSeasonDialog(context, season, isUrdu, fontFamily);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearBaseRecordDialog(BuildContext context, bool isUrdu,
      String fontFamily, DatabaseService db) {
    bool isConfirmed = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isUrdu ? 'بنیادی ریکارڈ صاف کریں؟' : 'Clear Base Record?',
            style:
                TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUrdu
                    ? 'کیا آپ واقعی اس پیشے کا بنیادی ریکارڈ (وہ ٹرانزیکشنز جو کسی ${_workNoun(isUrdu)} سے منسلک نہیں) صاف کرنا چاہتے ہیں؟ اس سے صرف پرانا ڈیٹا مٹے گا، نئے ریکارڈز محفوظ رہیں گے۔'
                    : 'Are you sure you want to clear the base record (transactions not linked to any ${_workNoun(isUrdu).toLowerCase()})? This will only delete legacy data; active records will remain safe.',
                style: TextStyle(fontFamily: fontFamily, fontSize: 13),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: isConfirmed,
                onChanged: (val) =>
                    setDialogState(() => isConfirmed = val ?? false),
                title: Text(
                  isUrdu
                      ? 'جی ہاں، میں مٹانا چاہتا ہوں'
                      : 'Yes, I want to clear',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.expenseColor,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'منسوخ' : 'Cancel'),
            ),
            AppButton(
              text: isUrdu ? 'صاف کریں' : 'Clear',
              onPressed: isConfirmed
                  ? () async {
                      final masterId = widget.masterProfession.id;
                      final txs = db
                          .getAllTransactions()
                          .where((t) => t.professionId == masterId)
                          .toList();

                      for (var t in txs) {
                        await db.deleteTransaction(t.id);
                      }

                      final updatedMaster = widget.masterProfession.copyWith(
                        totalIncome: 0,
                        totalExpense: 0,
                        updatedAt: DateTime.now(),
                      );
                      await db.updateProfession(updatedMaster);

                      if (context.mounted) {
                        Navigator.pop(context);
                        AppToast.info(
                          context,
                          isUrdu
                              ? 'بنیادی ریکارڈ صاف کر دیا گیا'
                              : 'Base record cleared',
                        );
                      }
                    }
                  : null,
              color: AppTheme.expenseColor,
              size: AppButtonSize.small,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteSeasonDialog(
      BuildContext context, Profession season, bool isUrdu, String fontFamily) {
    bool isConfirmed = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isUrdu
                ? '${_workNoun(isUrdu)} حذف کریں؟'
                : 'Delete ${_workNoun(isUrdu)}?',
            style:
                TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUrdu
                    ? 'کیا آپ واقعی "${season.season}" کو حذف کرنا چاہتے ہیں؟ اس سے منسلک تمام ٹرانزیکشنز بھی ڈیلیٹ ہو جائیں گی۔'
                    : 'Are you sure you want to delete "${season.season}"? This will also delete all its transactions.',
                style: TextStyle(fontFamily: fontFamily),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: isConfirmed,
                onChanged: (val) => setState(() => isConfirmed = val ?? false),
                title: Text(
                  isUrdu
                      ? 'جی ہاں، میں ڈیلیٹ کرنا چاہتا ہوں'
                      : 'Yes, I want to delete',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.expenseColor,
              ),
            ],
          ),
          actions: [
            AppButton(
              text: isUrdu ? 'منسوخ' : 'Cancel',
              onPressed: () => Navigator.pop(context),
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.small,
              color: AppTheme.textSecondary,
            ),
            AppButton(
              text: isUrdu ? 'حذف کریں' : 'Delete',
              onPressed: isConfirmed
                  ? () async {
                      final databaseService =
                          Provider.of<DatabaseService>(context, listen: false);
                      await databaseService.deleteProfession(season.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  : null,
              color: AppTheme.expenseColor,
              size: AppButtonSize.small,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reactivateSeason(BuildContext context, Profession season,
      bool isUrdu, String fontFamily, DatabaseService db) async {
    final allSeasons = db.getSeasons(widget.masterProfession.id);
    final activeSeason =
        allSeasons.where((s) => s.isActive ?? true).firstOrNull;

    if (activeSeason != null) {
      await db.updateProfession(activeSeason.copyWith(isActive: false));
    }

    await db.updateProfession(season.copyWith(isActive: true));

    if (context.mounted) {
      AppToast.success(
        context,
        isUrdu
            ? '${_workNoun(isUrdu)} دوبارہ فعال کر دیا گیا ہے'
            : '${_workNoun(isUrdu)} reactivated successfully',
      );
    }
  }

  Widget _buildSmallStat(String label, double amount, Color color, bool isUrdu,
      String fontFamily) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontFamily: fontFamily,
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount.abs().toStringAsFixed(0),
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.bold,
                fontFamily: '',
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openComparison(
      BuildContext context, List<Profession> completedSeasons) {
    if (completedSeasons.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeasonComparisonScreen(
            seasonA: completedSeasons.single,
          ),
        ),
      );
    } else if (completedSeasons.length == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeasonComparisonScreen(
            seasonA: completedSeasons[0],
            seasonB: completedSeasons[1],
          ),
        ),
      );
    } else if (completedSeasons.length > 2) {
      _showSeasonPickerForComparison(context, completedSeasons);
    }
  }

  void _showSeasonPickerForComparison(
      BuildContext context, List<Profession> completedSeasons) {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    Profession selectedA = completedSeasons[0];
    Profession selectedB = completedSeasons[1];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isUrdu
                ? 'موازنے کے لیے ۲ سیزن منتخب کریں'
                : 'Select 2 Seasons to Compare',
            style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isUrdu ? 'پہلا سیزن:' : 'First Season:'),
              const SizedBox(height: 4),
              DropdownButton<Profession>(
                isExpanded: true,
                value: selectedA,
                items: completedSeasons.map((s) {
                  return DropdownMenuItem(
                      value: s,
                      child: Text(s.season.isNotEmpty ? s.season : s.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedA = val);
                },
              ),
              const SizedBox(height: 12),
              Text(isUrdu ? 'دوسرا سیزن:' : 'Second Season:'),
              const SizedBox(height: 4),
              DropdownButton<Profession>(
                isExpanded: true,
                value: selectedB,
                items: completedSeasons.map((s) {
                  return DropdownMenuItem(
                      value: s,
                      child: Text(s.season.isNotEmpty ? s.season : s.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedB = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'منسوخ' : 'Cancel'),
            ),
            AppButton(
              text: isUrdu ? 'موازنہ کریں' : 'Compare',
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeasonComparisonScreen(
                      seasonA: selectedA,
                      seasonB: selectedB,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
