import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';

class ReportsScreen extends StatefulWidget {
  final Profession? selectedProfession;

  const ReportsScreen({Key? key, this.selectedProfession}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<model.Transaction> _allTransactions = [];
  List<Profession> _availableSeasons = [];
  Profession? _currentViewSeason;
  bool _isLoading = true;
  String _selectedType = 'expense'; // 'income' or 'expense'

  final List<Color> _segmentColors = [
    const Color(0xFFFFC107), // Amber
    const Color(0xFF03A9F4), // Light Blue
    const Color(0xFFE91E63), // Pink
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFF5722), // Deep Orange
    const Color(0xFF009688), // Teal
    const Color(0xFF607D8B), // Blue Grey
    const Color(0xFF795548), // Brown
    const Color(0xFF673AB7), // Deep Purple
    const Color(0xFF3F51B5), // Indigo
    const Color(0xFFCDDC39), // Lime
    const Color(0xFFFF9800), // Orange
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFF8BC34A), // Light Green
    const Color(0xFFF44336), // Red
    const Color(0xFF2196F3), // Blue
    const Color(0xFF9E9E9E), // Grey
    const Color(0xFFFF4081), // Pink Accent
    const Color(0xFF7C4DFF), // Deep Purple Accent
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final allProfs = db.getProfessions();
      _allTransactions = db
          .getAllTransactions()
          .where((t) => t.partnershipId == null)
          .toList();

      if (widget.selectedProfession != null) {
        if (widget.selectedProfession!.isMaster ?? false) {
          _availableSeasons = allProfs
              .where((p) => p.parentId == widget.selectedProfession!.id)
              .toList();
          _availableSeasons.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (_availableSeasons.isNotEmpty) {
            _currentViewSeason = _availableSeasons.first;
          } else {
            _currentViewSeason = widget.selectedProfession;
            _availableSeasons = [widget.selectedProfession!];
          }
        } else {
          _currentViewSeason = widget.selectedProfession;
          _availableSeasons = [widget.selectedProfession!];
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, double> _getCategoryData() {
    if (_currentViewSeason == null) return {};

    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    Map<String, double> data = {};

    final filtered = _allTransactions
        .where((t) => t.professionId == _currentViewSeason!.id)
        .toList();

    for (var tx in filtered) {
      if (tx.professionSide != _selectedType) continue;

      String category = _getEffectiveCategory(tx, isUrdu);
      data[category] = (data[category] ?? 0) + tx.amount;
    }
    return data;
  }

  String _getEffectiveCategory(model.Transaction t, bool isUrdu) {
    if (t.accountId != 'default_account' &&
        t.accountId != 'artisan_internal_income' &&
        t.accountId != QuickBillConstants.cashCustomerAccountId) {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final account = db.getAccount(t.accountId);
      if (account != null) return account.name;
    }

    String category = t.category;
    if (category.startsWith('INC:')) category = category.substring(4);
    if (category.startsWith('EXP:')) category = category.substring(4);

    if (category == 'income' ||
        category == 'expense' ||
        category == 'دیگر' ||
        category == 'Other') {
      return isUrdu
          ? (t.type == 'income' ? 'آمدن' : 'خرچ')
          : (t.type == 'income' ? 'Income' : 'Expense');
    }
    return category;
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: _buildSeasonSelector(isUrdu, fontFamily),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildComparisonBars(isUrdu, fontFamily),
                  const SizedBox(height: 32),
                  _buildTypeToggle(isUrdu, fontFamily),
                  const SizedBox(height: 40),
                  _buildChartSection(isUrdu, fontFamily),
                  const SizedBox(height: 40),
                  _buildCategoryList(isUrdu, fontFamily),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSeasonSelector(bool isUrdu, String fontFamily) {
    if (_availableSeasons.isEmpty) return const SizedBox.shrink();

    final currentYear = _currentViewSeason != null
        ? DateFormat('yyyy').format(_currentViewSeason!.createdAt)
        : DateFormat('yyyy').format(DateTime.now());

    return InkWell(
      onTap: () => _showSeasonPicker(isUrdu, fontFamily),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          UrduAwareText(
            isUrdu ? "رپورٹ $currentYear" : "Report $currentYear",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: fontFamily,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
              PhosphorIconsStyle.bold == PhosphorIconsStyle.bold
                  ? Icons.unfold_more
                  : Icons.unfold_more,
              color: Colors.white,
              size: 18),
        ],
      ),
    );
  }

  void _showSeasonPicker(bool isUrdu, String fontFamily) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              isUrdu ? "سیزن منتخب کریں" : "Select Season",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: fontFamily,
                  color: AppTheme.darkColor),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _availableSeasons.length,
                itemBuilder: (context, index) {
                  final p = _availableSeasons[index];
                  final isSelected = _currentViewSeason?.id == p.id;
                  final seasonName = (p.isMaster ?? false)
                      ? (isUrdu ? 'بنیادی کھاتہ' : 'Base Record')
                      : p.season;

                  return InkWell(
                    onTap: () {
                      setState(() => _currentViewSeason = p);
                      Navigator.pop(context);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.themeColor
                            : const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected
                                ? AppTheme.themeColor
                                : Colors.grey.shade200),
                      ),
                      child: UrduAwareText(
                        seasonName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: fontFamily,
                          color: isSelected ? Colors.white : AppTheme.darkColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonBars(bool isUrdu, String fontFamily) {
    final double income = _currentViewSeason?.totalIncome ?? 0.0;
    final double expense = _currentViewSeason?.totalExpense ?? 0.0;
    final double maxVal =
        income > expense ? income : (expense == 0 ? 1.0 : expense);

    return Column(
      children: [
        _buildMiniProgressBar(isUrdu ? "خرچ" : "Expense", expense, maxVal,
            const Color(0xFFFFC107), isUrdu, fontFamily),
        const SizedBox(height: 16),
        _buildMiniProgressBar(isUrdu ? "آمدنی" : "Earn", income, maxVal,
            const Color(0xFF3F51B5), isUrdu, fontFamily),
      ],
    );
  }

  Widget _buildMiniProgressBar(String label, double val, double max,
      Color color, bool isUrdu, String fontFamily) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: UrduAwareText(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: val / max,
              minHeight: 6,
              backgroundColor: const Color(0xFFF0F2F5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        UrduAwareText("Rs ${val.toStringAsFixed(0)}",
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildTypeToggle(bool isUrdu, String fontFamily) {
    return Row(
      children: [
        _buildToggleItem(
            isUrdu ? "خرچ" : "Expense", 'expense', isUrdu, fontFamily),
        const SizedBox(width: 24),
        _buildToggleItem(
            isUrdu ? "آمدنی" : "Earn", 'income', isUrdu, fontFamily),
      ],
    );
  }

  Widget _buildToggleItem(
      String label, String type, bool isUrdu, String fontFamily) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UrduAwareText(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              fontFamily: fontFamily,
              color: isSelected ? AppTheme.darkColor : Colors.grey[400],
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 3,
              width: 24,
              decoration: BoxDecoration(
                  color: AppTheme.darkColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }

  Widget _buildChartSection(bool isUrdu, String fontFamily) {
    final catData = _getCategoryData();
    final total = catData.values.fold(0.0, (sum, v) => sum + v);

    if (catData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: UrduAwareText(isUrdu ? "کوئی ڈیٹا موجود نہیں" : "No data available",
              style: TextStyle(color: Colors.grey, fontFamily: fontFamily)),
        ),
      );
    }

    return Center(
      child: SizedBox(
        height: 220,
        width: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 75,
                startDegreeOffset: -90,
                sections: catData.entries.toList().asMap().entries.map((entry) {
                  final idx = entry.key;
                  final val = entry.value.value;
                  return PieChartSectionData(
                    color: _segmentColors[idx % _segmentColors.length],
                    value: val,
                    title: '',
                    radius: 30,
                  );
                }).toList(),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UrduAwareText(
                  "Rs ${total.toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.darkColor),
                ),
                UrduAwareText(
                  isUrdu
                      ? "${catData.length} زمروں میں"
                      : "in ${catData.length} categories",
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontFamily: fontFamily),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList(bool isUrdu, String fontFamily) {
    final catData = _getCategoryData().entries.toList();
    catData.sort((a, b) => b.value.compareTo(a.value));
    final total = catData.fold(0.0, (sum, e) => sum + e.value);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: catData.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final entry = catData[index];
        final color = _segmentColors[index % _segmentColors.length];
        final percentage = (entry.value / total) * 100;

        return Row(
          children: [
            // Percentage
            SizedBox(
              width: 30,
              child: UrduAwareText(
                "${percentage.toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  fontFamily: '',
                ),
              ),
            ),
            // Category Name
            Expanded(
              flex: 3,
              child: UrduAwareText(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: fontFamily,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Progress Bar
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: entry.value / total,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF0F2F5),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Amount
            UrduAwareText(
              "Rs ${entry.value.toStringAsFixed(0)}",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.grey[400],
                fontFamily: '',
              ),
            ),
          ],
        );
      },
    );
  }
}
