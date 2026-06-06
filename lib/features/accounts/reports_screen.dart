import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/features/professions/season_comparison_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

class ReportsScreen extends StatefulWidget {
  final Profession? selectedProfession; // Optional profession for filtering

  const ReportsScreen({Key? key, this.selectedProfession}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'monthly';
  DateTime _selectedDate = DateTime.now();
  List<Profession> _professions = [];
  List<Account> _accounts = [];
  List<model.Transaction> _transactions = [];
  bool _isLoading = true;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  // Colors mapping for Ledger Style
  final Color _profitBg = const Color(0xFFE3F2FD);
  final Color _profitBorder = Colors.blue;
  final Color _lossBg = const Color(0xFFFFEBEE);
  final Color _lossBorder = Colors.red;
  final Color _goldColor = const Color(0xFFDAAD51);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);

      var professions = await databaseService.getProfessions();
      final accounts = await databaseService.getAccounts();

      // If a specific profession is selected, filter the list
      if (widget.selectedProfession != null) {
        professions = professions.where((p) => p.id == widget.selectedProfession!.id).toList();
      }

      // Filter out transactions that belong to partnerships
      final allTransactions = await databaseService.getAllTransactions();
      final transactions = allTransactions.where((t) => t.partnershipId == null).toList();

      if (mounted) {
        setState(() {
          _professions = professions;
          _accounts = accounts;
          _transactions = transactions;
          _isLoading = false;
        });
        _calculateTotals();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateTotals() {
    double income = 0.0;
    double expense = 0.0;

    for (var transaction in _transactions) {
      if (transaction.professionId == null) continue;
      
      // If filtering, check if transaction belongs to filtered profession
      if (widget.selectedProfession != null && transaction.professionId != widget.selectedProfession!.id) {
        continue;
      }

      if (transaction.type == 'income') {
        income += transaction.amount;
      } else if (transaction.type == 'expense') {
        expense += transaction.amount;
      }
    }

    setState(() {
      _totalIncome = income;
      _totalExpense = expense;
    });
  }

  Map<String, double> _getIncomeCategories() {
    Map<String, double> categories = {};
    for (var transaction in _transactions.where((t) => t.type == 'income' && t.partnershipId == null && t.professionId != null)) {
      if (widget.selectedProfession != null && transaction.professionId != widget.selectedProfession!.id) continue;
      String category = transaction.category ?? 'دیگر';
      categories[category] = (categories[category] ?? 0) + transaction.amount;
    }
    return categories;
  }

  Map<String, double> _getExpenseCategories() {
    Map<String, double> categories = {};
    for (var transaction in _transactions.where((t) => t.type == 'expense' && t.partnershipId == null && t.professionId != null)) {
      if (widget.selectedProfession != null && transaction.professionId != widget.selectedProfession!.id) continue;
      String category = transaction.category ?? 'دیگر';
      categories[category] = (categories[category] ?? 0) + transaction.amount;
    }
    return categories;
  }

  Future<void> _selectDate(BuildContext context) async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: isUrdu ? const Locale('ur') : const Locale('en'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.themeColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.darkColor,
            ),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              headerBackgroundColor: AppTheme.darkColor,
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 24),
              headerHelpStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 16),
              yearStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
              weekdayStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
              dayStyle: const TextStyle(fontFamily: '', fontWeight: FontWeight.bold),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.themeColor,
                textStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: CustomAppBar(
        title: widget.selectedProfession != null
            ? (isUrdu ? '${widget.selectedProfession!.name} رپورٹ' : '${widget.selectedProfession!.name} Report')
            : (isUrdu ? 'رپورٹس (خلاصہ)' : 'Reports Summary'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.themeColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Period Selector
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
                    ),
                    alignment: Alignment.centerLeft,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPeriod,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: Icon(PhosphorIcons.caretDown(), color: AppTheme.darkColor, size: 20),
                        style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontWeight: fontWeight),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedPeriod = newValue!;
                          });
                        },
                        items: [
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text(
                              isUrdu ? 'روزانہ' : 'Daily',
                              style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight, color: AppTheme.darkColor),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text(
                              isUrdu ? 'ہفتہ وار' : 'Weekly',
                              style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight, color: AppTheme.darkColor),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text(
                              isUrdu ? 'ماہانہ' : 'Monthly',
                              style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight, color: AppTheme.darkColor),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Text(
                              isUrdu ? 'سالانہ' : 'Yearly',
                              style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight, color: AppTheme.darkColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDate(_selectedDate), style: const TextStyle(fontFamily: '', color: AppTheme.darkColor, fontWeight: FontWeight.bold)),
                          Icon(PhosphorIcons.calendar(), color: AppTheme.themeColor, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    isUrdu ? 'کل آمدنی' : 'Total Income',
                    'Rs ${_totalIncome.toStringAsFixed(0)}',
                    Colors.blue,
                    PhosphorIcons.trendUp(),
                    fontFamily,
                    fontWeight,
                    _profitBg,
                    _profitBorder,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    isUrdu ? 'کل خرچ' : 'Total Expense',
                    'Rs ${_totalExpense.toStringAsFixed(0)}',
                    Colors.red,
                    PhosphorIcons.trendDown(),
                    fontFamily,
                    fontWeight,
                    _lossBg,
                    _lossBorder,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    isUrdu ? 'خالص منافع' : 'Net Profit',
                    'Rs ${(_totalIncome - _totalExpense).toStringAsFixed(0)}',
                    (_totalIncome - _totalExpense) >= 0 ? Colors.blue : Colors.red,
                    (_totalIncome - _totalExpense) >= 0 ? PhosphorIcons.trendUp() : PhosphorIcons.trendDown(),
                    fontFamily,
                    fontWeight,
                    (_totalIncome - _totalExpense) >= 0 ? _profitBg : _lossBg,
                    (_totalIncome - _totalExpense) >= 0 ? _profitBorder : _lossBorder,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    isUrdu ? 'منافع کی شرح' : 'Profit Margin',
                    '${(_totalIncome > 0 ? ((_totalIncome - _totalExpense) / _totalIncome) * 100 : 0).toStringAsFixed(1)}%',
                    AppTheme.themeColor,
                    PhosphorIcons.percent(),
                    fontFamily,
                    fontWeight,
                    Colors.white,
                    AppTheme.themeColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // If a specific profession is selected, show Season Comparison Button
            if (widget.selectedProfession != null && widget.selectedProfession!.season.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SeasonComparisonScreen(
                            professionName: widget.selectedProfession!.name,
                          ),
                        ),
                      );
                    },
                    icon: Icon(PhosphorIcons.arrowsLeftRight(), color: Colors.white),
                    label: Text(
                      isUrdu ? 'سیزن کا موازنہ' : 'Season Comparison',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            // 1. Cost Per Unit Analysis (Only if relevant professions exist)
            _buildCostPerUnitAnalysis(isUrdu, fontFamily, fontWeight),

            // 2. Seasonal Comparison (Only if not single profession selected or multiple seasons exist)
            if (widget.selectedProfession == null)
               _buildSeasonalComparison(isUrdu, fontFamily, fontWeight),

            // 3. Budget Alerts
            _buildBudgetAlertsSection(isUrdu, fontFamily, fontWeight),

            // 4. AI Recommendations
            _buildAIRecommendations(isUrdu, fontFamily, fontWeight),

            SizedBox(height: 20),
            
            // If viewing all, show summary.
            if (widget.selectedProfession == null)
               _buildProfessionSummary(isUrdu, fontFamily, fontWeight),
               
            SizedBox(height: 20),
            _buildCategorySummary(isUrdu, fontFamily, fontWeight),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ... (Keep existing _buildSummaryCard and other helper methods) ...
  Widget _buildSummaryCard(
      String title,
      String value,
      Color iconColor,
      IconData icon,
      String fontFamily,
      FontWeight fontWeight,
      Color bgColor,
      Color borderColor,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkColor.withOpacity(0.7),
              fontFamily: fontFamily,
              fontWeight: fontWeight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Cost Per Unit
  Widget _buildCostPerUnitAnalysis(bool isUrdu, String fontFamily, FontWeight fontWeight) {
    final professionsWithProduction = _professions
        .where((p) => p.totalProduction > 0)
        .toList();

    if (professionsWithProduction.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.calculator(), color: AppTheme.themeColor, size: 24),
              const SizedBox(width: 8),
              Text(
                isUrdu ? 'فی اکائی لاگت' : 'Cost Per Unit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...professionsWithProduction.map((profession) {
            final costPerUnit = profession.costPerUnit;
            final benchmark = profession.benchmarkCostPerUnit;
            final hasBenchmark = benchmark > 0;
            final isEfficient = !hasBenchmark || costPerUnit <= benchmark;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isEfficient ? _profitBg.withOpacity(0.3) : _lossBg.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isEfficient ? _profitBorder.withOpacity(0.2) : _lossBorder.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          profession.name,
                          style: TextStyle(
                            color: AppTheme.darkColor,
                            fontFamily: fontFamily,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${costPerUnit.toStringAsFixed(2)}/${profession.displayUnit}',
                            style: TextStyle(
                              color: isEfficient ? Colors.blue : Colors.red,
                              fontFamily: '',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (profession.totalProduction > 0)
                            Text(
                              '${profession.totalProduction.toStringAsFixed(0)} ${profession.displayUnit}',
                              style: TextStyle(
                                color: AppTheme.darkColor.withOpacity(0.6),
                                fontSize: 12,
                                fontFamily: '',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  if (hasBenchmark)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(
                            isEfficient ? PhosphorIcons.checkCircle() : PhosphorIcons.warning(),
                            color: isEfficient ? Colors.green : Colors.red,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isUrdu
                                  ? 'معیار: ${benchmark.toStringAsFixed(2)} (${((costPerUnit - benchmark) / benchmark * 100).toStringAsFixed(1)}%)'
                                  : 'Benchmark: ${benchmark.toStringAsFixed(2)} (${((costPerUnit - benchmark) / benchmark * 100).toStringAsFixed(1)}%)',
                              style: TextStyle(
                                color: AppTheme.darkColor.withOpacity(0.7),
                                fontFamily: fontFamily,
                                fontWeight: fontWeight,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (profession.targetProduction > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isUrdu ? 'ہدف پیداوار' : 'Target',
                              style: TextStyle(
                                color: AppTheme.darkColor.withOpacity(0.7),
                                fontFamily: fontFamily,
                                fontWeight: fontWeight,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${profession.productionProgress.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: profession.productionProgress >= 100 ? Colors.green :
                                profession.productionProgress >= 70 ? Colors.orange :
                                Colors.red,
                                fontWeight: FontWeight.bold,
                                fontFamily: '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: profession.productionProgress / 100,
                            backgroundColor: AppTheme.darkColor.withOpacity(0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              profession.productionProgress >= 100 ? Colors.green :
                              profession.productionProgress >= 70 ? Colors.orange :
                              Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Seasonal Comparison (General)
  Widget _buildSeasonalComparison(bool isUrdu, String fontFamily, FontWeight fontWeight) {
    final professionsWithSeason = _professions
        .where((p) => p.season.isNotEmpty)
        .toList();

    if (professionsWithSeason.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group by season
    final seasonGroups = <String, List<Profession>>{};
    for (var profession in professionsWithSeason) {
      seasonGroups.putIfAbsent(profession.season, () => []);
      seasonGroups[profession.season]!.add(profession);
    }

    final seasons = seasonGroups.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.arrowsLeftRight(), color: AppTheme.themeColor, size: 24),
              const SizedBox(width: 8),
              Text(
                isUrdu ? 'سیزن وار موازنہ' : 'Seasonal Comparison',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (seasons.length <= 1)
            Center(
              child: Text(
                isUrdu ? 'صرف ایک سیزن کا ڈیٹا موجود ہے' : 'Only one season data available',
                style: TextStyle(color: AppTheme.darkColor.withOpacity(0.6), fontFamily: fontFamily, fontWeight: fontWeight),
              ),
            )
          else
            Column(
              children: seasons.map((season) {
                final seasonProfs = seasonGroups[season]!;
                final totalIncome = seasonProfs.fold(0.0, (sum, p) => sum + p.totalIncome);
                final totalExpense = seasonProfs.fold(0.0, (sum, p) => sum + p.totalExpense);
                final netProfit = totalIncome - totalExpense;

                double avgCostPerUnit = 0.0;
                int count = 0;
                for (var prof in seasonProfs) {
                  if (prof.costPerUnit > 0) {
                    avgCostPerUnit += prof.costPerUnit;
                    count++;
                  }
                }
                if (count > 0) avgCostPerUnit /= count;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: netProfit >= 0 ? _profitBg.withOpacity(0.3) : _lossBg.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: netProfit >= 0 ? _profitBorder.withOpacity(0.2) : _lossBorder.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            season,
                            style: TextStyle(
                              color: AppTheme.darkColor,
                              fontFamily: fontFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: netProfit >= 0 ? Colors.blue : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Rs ${netProfit.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: '',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUrdu ? 'آمدنی' : 'Income',
                                style: TextStyle(
                                  color: AppTheme.darkColor.withOpacity(0.6),
                                  fontFamily: fontFamily,
                                  fontWeight: fontWeight,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Rs ${totalIncome.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: '',
                                ),
                              ),
                            ],
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUrdu ? 'خرچ' : 'Expense',
                                style: TextStyle(
                                  color: AppTheme.darkColor.withOpacity(0.6),
                                  fontFamily: fontFamily,
                                  fontWeight: fontWeight,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Rs ${totalExpense.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: '',
                                ),
                              ),
                            ],
                          ),

                          if (avgCostPerUnit > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isUrdu ? 'اوسط لاگت' : 'Avg Cost',
                                  style: TextStyle(
                                    color: AppTheme.darkColor.withOpacity(0.6),
                                    fontFamily: fontFamily,
                                    fontWeight: fontWeight,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  avgCostPerUnit.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: AppTheme.darkColor,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: '',
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // Budget Alerts
  Widget _buildBudgetAlertsSection(bool isUrdu, String fontFamily, FontWeight fontWeight) {
    final professionsWithBudget = _professions
        .where((p) => p.budgetLimits != null && p.budgetLimits!.isNotEmpty) 
        .toList();

    if (professionsWithBudget.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
             Text(isUrdu ? 'بجٹ کنٹرول' : 'Budget Control', style: TextStyle(color: AppTheme.darkColor, fontSize: 18, fontFamily: fontFamily, fontWeight: FontWeight.bold)),
             const SizedBox(height: 12),
             ...professionsWithBudget.map((profession) {
                final warnings = _generateBudgetWarnings(profession);
                if(warnings.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profession.name, style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontWeight: FontWeight.bold)),
                    ...warnings.map((w) => Row(
                      children: [
                        Icon(PhosphorIcons.warning(), color: Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Expanded(child: Text(w, style: TextStyle(color: Colors.red, fontSize: 12, fontFamily: fontFamily, fontWeight: fontWeight))),
                      ],
                    )).toList(),
                    const SizedBox(height: 8),
                  ],
                );
             }).toList(),
        ],
      ),
    );
  }

  // AI Recommendations
  Widget _buildAIRecommendations(bool isUrdu, String fontFamily, FontWeight fontWeight) {
    final needRecommendations = _professions
        .where((p) => p.performanceScore < 70 || p.netProfit < 0)
        .toList();

    if (needRecommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.lightbulb(), color: Colors.yellow, size: 24),
              const SizedBox(width: 8),
              Text(isUrdu ? 'ہوشیار تجاویز' : 'Smart Recommendations', style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: fontFamily, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...needRecommendations.map((p) {
             final rec = _generateRecommendation(p, isUrdu);
             return Padding(
               padding: const EdgeInsets.only(bottom: 8.0),
               child: Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text('• ', style: TextStyle(color: Colors.white, fontSize: 16)),
                   Expanded(
                     child: Text(
                       '${p.name}: $rec', 
                       style: TextStyle(color: Colors.white.withOpacity(0.9), fontFamily: fontFamily, fontWeight: fontWeight, fontSize: 13)
                     ),
                   ),
                 ],
               ),
             );
          }).toList(),
        ],
      ),
    );
  }

  // Profession Summary List
  Widget _buildProfessionSummary(bool isUrdu, String fontFamily, FontWeight fontWeight) {
    if (_professions.isEmpty) return const SizedBox.shrink();

    final activeProfessions = _professions.where((p) => p.isActive).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.briefcase(), color: AppTheme.themeColor, size: 24),
              const SizedBox(width: 8),
              Text(
                isUrdu ? 'پیشوں کا خلاصہ' : 'Professions Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(flex: 3, child: Text(isUrdu ? 'پیشہ' : 'Profession', style: TextStyle(color: AppTheme.darkColor, fontWeight: FontWeight.bold, fontFamily: fontFamily, fontSize: 12))),
              Expanded(child: Center(child: Text(isUrdu ? 'آمدنی' : 'Inc', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontFamily: fontFamily, fontSize: 12)))),
              Expanded(child: Center(child: Text(isUrdu ? 'خرچ' : 'Exp', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: fontFamily, fontSize: 12)))),
              Expanded(child: Align(alignment: Alignment.centerRight, child: Text(isUrdu ? 'بچت' : 'Net', style: TextStyle(color: AppTheme.darkColor, fontWeight: FontWeight.bold, fontFamily: fontFamily, fontSize: 12)))),
            ],
          ),
          Divider(color: AppTheme.darkColor.withOpacity(0.1)),

          ...activeProfessions.map((profession) =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profession.name, style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontWeight: fontWeight, fontSize: 13)),
                          if (profession.season.isNotEmpty)
                            Text(
                              profession.season,
                              style: TextStyle(
                                color: AppTheme.darkColor.withOpacity(0.5),
                                fontFamily: fontFamily,
                                fontWeight: fontWeight,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            profession.totalIncome.toStringAsFixed(0),
                            style: const TextStyle(color: Colors.blue, fontFamily: '', fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            profession.totalExpense.toStringAsFixed(0),
                            style: const TextStyle(color: Colors.red, fontFamily: '', fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            profession.netProfit.toStringAsFixed(0),
                            style: TextStyle(
                              color: profession.netProfit >= 0 ? Colors.blue : Colors.red,
                              fontFamily: '',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
          ).toList(),
        ],
      ),
    );
  }

  // Category Summary
  Widget _buildCategorySummary(bool isUrdu, String fontFamily, FontWeight fontWeight) {
    final incomeCategories = _getIncomeCategories();
    final expenseCategories = _getExpenseCategories();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? 'زمرہ وار خلاصہ' : 'Category-wise Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: fontFamily,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 16),

          if (incomeCategories.isNotEmpty) ...[
            _buildCategorySection(isUrdu ? 'آمدنی' : 'Income', Colors.blue, incomeCategories, fontFamily, fontWeight),
            const SizedBox(height: 24),
          ],

          if (expenseCategories.isNotEmpty) ...[
            _buildCategorySection(isUrdu ? 'خرچ' : 'Expense', Colors.red, expenseCategories, fontFamily, fontWeight),
          ],
        ],
      ),
    );
  }
  
  // Helper for category section
  Widget _buildCategorySection(String title, Color color, Map<String, double> categories, String fontFamily, FontWeight fontWeight) {
    double total = categories.values.fold(0, (sum, amount) => sum + amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, fontFamily: fontFamily)),
        Divider(color: AppTheme.darkColor.withOpacity(0.1)),
        ...categories.entries.map((entry) {
          double percentage = total > 0 ? (entry.value / total) : 0;
          String percentageText = '${(percentage * 100).toStringAsFixed(1)}%';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    entry.key,
                    style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontWeight: fontWeight, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: AppTheme.darkColor.withOpacity(0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 16,
                        ),
                      ),
                      Text(
                        percentageText,
                        style: TextStyle(
                          color: percentage > 0.5 ? Colors.white : AppTheme.darkColor,
                          fontFamily: '',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                SizedBox(
                  width: 80,
                  child: Text(
                    'Rs ${entry.value.toStringAsFixed(0)}',
                    textAlign: TextAlign.end,
                    style: TextStyle(color: color, fontFamily: '', fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- Local Helper Functions for Alerts & Recommendations ---

  List<String> _generateBudgetWarnings(Profession profession) {
    final warnings = <String>[];
    if (profession.budgetLimits == null) return warnings;

    // Check against total if available, otherwise check components?
    // Since we don't have budget tracking per profession fully integrated here in this simple check,
    // we'll do a simple check.
    // Assuming budgetLimits has keys like 'total' or 'costPerUnit' as seen in other files logic.
    // Or check if totalExpense > sum of budget limits?
    
    // Simple check: if total expense > 0 and budgetLimits is not empty
    double totalBudget = profession.budgetLimits!.values.fold(0, (sum, val) => sum + val);
    if (totalBudget > 0 && profession.totalExpense > totalBudget) {
       warnings.add('کل خرچ بجٹ (${totalBudget.toStringAsFixed(0)}) سے زیادہ ہے');
    }
    return warnings;
  }

  String _generateRecommendation(Profession profession, bool isUrdu) {
    // Local implementation of recommendation logic
    if (profession.netProfit < 0) {
      return isUrdu ? 'نقصان ہو رہا ہے۔ اخراجات کم کریں۔' : 'Loss making. Reduce expenses.';
    }
    if (profession.performanceScore < 50) {
      return isUrdu ? 'کارکردگی بہتر بنانے کی ضرورت ہے۔' : 'Performance needs improvement.';
    }
    if (profession.benchmarkCostPerUnit > 0 && profession.costPerUnit > profession.benchmarkCostPerUnit) {
      return isUrdu ? 'لاگت معیار سے زیادہ ہے۔' : 'Cost is higher than benchmark.';
    }
    return isUrdu ? 'سب ٹھیک ہے۔' : 'All good.';
  }

  Widget _buildActionChip(String label, IconData icon, String fontFamily, Color color) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontFamily: fontFamily, fontSize: 11)),
      avatar: Icon(icon, size: 14, color: Colors.white),
      backgroundColor: color,
      labelStyle: TextStyle(color: Colors.white),
      onPressed: () {},
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return _goldColor;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}