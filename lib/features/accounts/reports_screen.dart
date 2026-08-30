import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

class ReportsScreen extends StatefulWidget {
  final Profession? selectedProfession; // Optional profession for filtering

  const ReportsScreen({Key? key, this.selectedProfession}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Profession> _professions = [];
  List<model.Transaction> _transactions = [];
  bool _isLoading = true;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  List<String> _relevantProfessionIds = []; // IDs of master + all its seasons
  final Set<String> _expandedSeasonIds = {}; // کھلنے اور بند ہونے والے سیزنز کے لیے

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);

      var allProfs = databaseService.getProfessions();
      
      // If a specific profession is selected, find its seasons
      List<String> relevantIds = [];
      if (widget.selectedProfession != null) {
        relevantIds.add(widget.selectedProfession!.id);
        // اگر یہ ماسٹر پیشہ ہے تو اس کے سیزنز بھی ڈھونڈیں
        final seasons = allProfs.where((p) => p.parentId == widget.selectedProfession!.id).toList();
        relevantIds.addAll(seasons.map((s) => s.id));
        
        _professions = allProfs.where((p) => relevantIds.contains(p.id)).toList();
      } else {
        _professions = allProfs;
      }

      // Filter out transactions that belong to partnerships
      final allTransactions = databaseService.getAllTransactions();
      _transactions = allTransactions.where((t) => t.partnershipId == null).toList();
      _relevantProfessionIds = relevantIds;

      if (mounted) {
        _calculateTotals();
        setState(() {
          _isLoading = false;
        });
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
      
      // If filtering, check if transaction belongs to master or any of its seasons
      if (widget.selectedProfession != null && !_relevantProfessionIds.contains(transaction.professionId)) {
        continue;
      }

      if (transaction.type == 'income') {
        income += transaction.amount;
      } else if (transaction.type == 'expense') {
        expense += transaction.amount;
      }
    }

    _totalIncome = income;
    _totalExpense = expense;
  }

  Map<String, double> _getIncomeCategories() {
    Map<String, double> categories = {};
    for (var transaction in _transactions.where((t) => t.type == 'income' && t.partnershipId == null && t.professionId != null)) {
      if (widget.selectedProfession != null && !_relevantProfessionIds.contains(transaction.professionId)) continue;
      String category = transaction.category;
      categories[category] = (categories[category] ?? 0) + transaction.amount;
    }
    return categories;
  }

  Map<String, double> _getExpenseCategories() {
    Map<String, double> categories = {};
    for (var transaction in _transactions.where((t) => t.type == 'expense' && t.partnershipId == null && t.professionId != null)) {
      if (widget.selectedProfession != null && !_relevantProfessionIds.contains(transaction.professionId)) continue;
      String category = transaction.category;
      categories[category] = (categories[category] ?? 0) + transaction.amount;
    }
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    final content = _isLoading
        ? const Center(
            child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(color: AppTheme.themeColor),
          ))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. Budget Alerts
                _buildBudgetAlertsSection(isUrdu, fontFamily, fontWeight),

                const SizedBox(height: 10),

                // 2. سیزن وار زمرہ جات کا تفصیلی حساب
                if (widget.selectedProfession != null)
                  _buildDetailedSeasonCategoryBreakdown(
                      isUrdu, fontFamily, fontWeight),

                const SizedBox(height: 10),

                // If viewing all, show summary.
                if (widget.selectedProfession == null)
                  _buildProfessionSummary(isUrdu, fontFamily, fontWeight),

                const SizedBox(height: 10),
                _buildCategorySummary(isUrdu, fontFamily, fontWeight),
                const SizedBox(height: 20),
              ],
            ),
          );

    // پوپ اپ (Bottom Sheet) ڈیزائن
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ہینڈل بار
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ہیڈر
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.selectedProfession != null
                      ? (isUrdu
                          ? '${widget.selectedProfession!.name} رپورٹ'
                          : '${widget.selectedProfession!.name} Report')
                      : (isUrdu ? 'رپورٹس (خلاصہ)' : 'Reports Summary'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily,
                    color: AppTheme.darkColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.darkColor),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // مواد (Scrollable)
          Flexible(child: content),
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
        border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.2)),
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

  // سیزن وار زمرہ جات کا تفصیلی حساب (آمدنی اور خرچ)
  Widget _buildDetailedSeasonCategoryBreakdown(bool isUrdu, String fontFamily, FontWeight fontWeight) {
    final relevantProfessions = _professions.where((p) => _relevantProfessionIds.contains(p.id)).toList();
    relevantProfessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(PhosphorIcons.listChecks(), color: AppTheme.themeColor, size: 24),
            const SizedBox(width: 8),
            Text(
              isUrdu ? 'سیزن وار تفصیلی حساب' : 'Detailed Season Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily, color: AppTheme.darkColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...relevantProfessions.map((profession) {
          final seasonTxs = _transactions.where((t) => t.professionId == profession.id).toList();
          if (seasonTxs.isEmpty) return const SizedBox.shrink();

          Map<String, double> catIncome = {};
          Map<String, double> catExpenses = {};
          
          for (var tx in seasonTxs) {
            if (tx.type == 'income') {
              catIncome[tx.category] = (catIncome[tx.category] ?? 0) + tx.amount;
            } else {
              catExpenses[tx.category] = (catExpenses[tx.category] ?? 0) + tx.amount;
            }
          }

          if (catIncome.isEmpty && catExpenses.isEmpty) return const SizedBox.shrink();

          final sortedIncome = catIncome.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final sortedExpenses = catExpenses.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final isExpanded = _expandedSeasonIds.contains(profession.id);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedSeasonIds.remove(profession.id);
                      } else {
                        _expandedSeasonIds.add(profession.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                isExpanded ? PhosphorIcons.caretUp() : PhosphorIcons.caretDown(),
                                size: 16,
                                color: AppTheme.themeColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (profession.isMaster ?? false) ? (isUrdu ? 'بنیادی کھاتہ' : 'Base Account') : profession.season,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.themeColor, fontFamily: fontFamily),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Rs ${profession.totalIncome.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.incomeColor),
                            ),
                            const Text(' | ', style: TextStyle(color: Colors.grey)),
                            Text(
                              'Rs ${profession.totalExpense.toStringAsFixed(0)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.expenseColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (isExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- آمدنی کا سیکشن ---
                        if (sortedIncome.isNotEmpty) ...[
                          Text(isUrdu ? 'آمدنی' : 'Income', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.incomeColor, fontFamily: fontFamily)),
                          const SizedBox(height: 8),
                          ...sortedIncome.map((entry) => _buildSimpleBreakdownRow(entry.key, entry.value, profession.totalIncome, AppTheme.incomeColor, fontFamily)),
                          const SizedBox(height: 16),
                        ],

                        // --- اخراجات کا سیکشن ---
                        if (sortedExpenses.isNotEmpty) ...[
                          Text(isUrdu ? 'اخراجات' : 'Expenses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.expenseColor, fontFamily: fontFamily)),
                          const SizedBox(height: 8),
                          ...sortedExpenses.map((entry) => _buildSimpleBreakdownRow(entry.key, entry.value, profession.totalExpense, AppTheme.expenseColor, fontFamily)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSimpleBreakdownRow(String label, double amount, double total, Color color, String fontFamily) {
    double percentage = total > 0 ? (amount / total) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 11, fontFamily: fontFamily))),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[100],
                valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.6)),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('Rs ${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Profession Summary List
  Widget _buildProfessionSummary(bool isUrdu, String fontFamily, FontWeight fontWeight) {
    if (_professions.isEmpty) return const SizedBox.shrink();

    final activeProfessions = _professions.where((p) => p.isActive ?? true).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.2)),
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
              Expanded(child: Center(child: Text(isUrdu ? 'آمدنی' : 'Inc', style: TextStyle(color: AppTheme.incomeColor, fontWeight: FontWeight.bold, fontFamily: fontFamily, fontSize: 12)))),
              Expanded(child: Center(child: Text(isUrdu ? 'خرچ' : 'Exp', style: TextStyle(color: AppTheme.expenseColor, fontWeight: FontWeight.bold, fontFamily: fontFamily, fontSize: 12)))),
              Expanded(child: Align(alignment: Alignment.centerRight, child: Text(isUrdu ? 'بچت' : 'Net', style: TextStyle(color: AppTheme.darkColor, fontWeight: FontWeight.bold, fontFamily: fontFamily, fontSize: 12)))),
            ],
          ),
          Divider(color: AppTheme.darkColor.withValues(alpha: 0.1)),

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
                                color: AppTheme.darkColor.withValues(alpha: 0.5),
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
                            style: TextStyle(color: AppTheme.incomeColor, fontFamily: '', fontWeight: FontWeight.bold, fontSize: 12),
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
                            style: TextStyle(color: AppTheme.expenseColor, fontFamily: '', fontWeight: FontWeight.bold, fontSize: 12),
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
                              color: profession.netProfit >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
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
        border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.2)),
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
            _buildCategorySection(isUrdu ? 'آمدنی' : 'Income', AppTheme.incomeColor, incomeCategories, fontFamily, fontWeight),
            const SizedBox(height: 24),
          ],

          if (expenseCategories.isNotEmpty) ...[
            _buildCategorySection(isUrdu ? 'خرچ' : 'Expense', AppTheme.expenseColor, expenseCategories, fontFamily, fontWeight),
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
        Divider(color: AppTheme.darkColor.withValues(alpha: 0.1)),
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
                          backgroundColor: AppTheme.darkColor.withValues(alpha: 0.05),
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

  List<String> _generateBudgetWarnings(Profession profession) {
    final warnings = <String>[];
    if (profession.budgetLimits == null) return warnings;

    double totalBudget = profession.budgetLimits!.values.fold(0, (sum, val) => sum + val);
    if (totalBudget > 0 && profession.totalExpense > totalBudget) {
       warnings.add('کل خرچ بجٹ (${totalBudget.toStringAsFixed(0)}) سے زیادہ ہے');
    }
    return warnings;
  }
}
