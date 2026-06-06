import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/l10n/app_localizations.dart';

class SeasonComparisonScreen extends StatefulWidget {
  final String professionName;

  const SeasonComparisonScreen({super.key, required this.professionName});

  @override
  _SeasonComparisonScreenState createState() => _SeasonComparisonScreenState();
}

class _SeasonComparisonScreenState extends State<SeasonComparisonScreen> {
  List<Profession> _seasons = [];
  bool _isLoading = true;

  final Color _goldColor = const Color(0xFFDAAD51);
  final Color _greenColor = const Color(0xFF4CAF50);
  final Color _redColor = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      _seasons = databaseService.getProfessions()
          .where((p) => p.name == widget.professionName && p.season.isNotEmpty)
          .toList();
      _seasons.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('سیزن لوڈ کرنے میں خرابی: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showHelpDialog(bool isUrdu, String fontFamily) {
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Row(
          children: [
            Icon(PhosphorIcons.question(), color: AppTheme.themeColor),
            const SizedBox(width: 10),
            Text(
              isUrdu ? 'مدد اور معلومات' : 'Help & Information',
              style: TextStyle(fontFamily: fontFamily, color: AppTheme.darkColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUrdu ? 'اس سکرین کا مقصد آپ کے مختلف سیزنز (جیسے گندم ٢٠٢٣، کپاس ٢٠٢٤) کا آپس میں موازنہ کرنا ہے تاکہ آپ اپنے کاروبار کی کارکردگی کو بہتر طور پر سمجھ سکیں۔' 
                    : 'The purpose of this screen is to compare your different seasons (e.g., Wheat 2023, Cotton 2024) to better understand your business performance.',
                style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary, fontWeight: fontWeight),
              ),
              const SizedBox(height: 16),
              _buildHelpItem(PhosphorIcons.arrowsLeftRight(), isUrdu ? 'کارکردگی کا تجزیہ' : 'Performance Analysis', isUrdu ? 'یہ کارڈ آپ کے حالیہ سیزن کا پچھلے سیزن سے موازنہ کرتا ہے۔ اس میں فی یونٹ لاگت، منافع اور کل پیداوار میں ہونے والی تبدیلی کو فیصد (%) میں دکھایا جاتا ہے۔' : 'This card compares your latest season with the previous one. It shows the percentage (%) change in cost per unit, profit, and total production.', fontFamily, fontWeight),
              _buildHelpItem(PhosphorIcons.lightbulb(), isUrdu ? 'ہوشیار تجاویز' : 'Smart Suggestions', isUrdu ? 'یہاں ایپ آپ کے ڈیٹا کا تجزیہ کر کے بہتری کے لیے تجاویز دیتی ہے۔ مثال کے طور پر، اگر لاگت بڑھ رہی ہو تو اسے کم کرنے کا مشورہ دیا جاتا ہے۔' : 'Here, the app analyzes your data and provides suggestions for improvement. For example, if costs are increasing, it advises on how to reduce them.', fontFamily, fontWeight),
              _buildHelpItem(PhosphorIcons.clockCounterClockwise(), isUrdu ? 'پرانے سیزن ریکارڈ' : 'Previous Season Records', isUrdu ? 'اگر دو سے زیادہ سیزن کا ڈیٹا موجود ہو تو یہاں پرانے تمام سیزنز کا مختصر ریکارڈ دکھایا جاتا ہے تاکہ آپ اپنی تاریخ دیکھ سکیں۔' : 'If data for more than two seasons exists, a brief record of all old seasons is displayed here so you can see your history.', fontFamily, fontWeight),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isUrdu ? 'بند کریں' : 'Close', style: TextStyle(fontFamily: fontFamily, color: AppTheme.themeColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String subtitle, String fontFamily, FontWeight fontWeight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.themeColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary, fontSize: 14, fontWeight: fontWeight)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    final numberStyle = const TextStyle(fontFamily: '', fontWeight: FontWeight.bold);

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'سیزن وار موازنہ' : 'Season Comparison',
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.question()),
            onPressed: () => _showHelpDialog(isUrdu, fontFamily),
            tooltip: isUrdu ? 'مدد' : 'Help',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.themeColor))
          : _seasons.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.chartBar(), size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              isUrdu ? 'کوئی ڈیٹا نہیں' : 'No Data Available',
              style: TextStyle(fontFamily: fontFamily, fontSize: 18, color: AppTheme.darkColor),
            ),
          ],
        ),
      )
          : _seasons.length == 1
          ? _buildSingleSeasonView(isUrdu, fontFamily)
          : _buildComparisonView(isUrdu, fontFamily),
    );
  }

  // ایک سیزن کا ڈسپلے
  Widget _buildSingleSeasonView(bool isUrdu, String fontFamily) {
    final season = _seasons.first;
    final term = season.terminology;
    final unit = term['unit'] ?? season.displayUnit;
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(season, isUrdu, fontFamily, fontWeight),
          const SizedBox(height: 16),
          _buildDetailCard(season, isUrdu, fontFamily, fontWeight, term, unit),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(PhosphorIcons.info(), color: AppTheme.themeColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'موازنہ دستیاب نہیں' : 'Comparison Unavailable',
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontWeight: fontWeight,
                          color: AppTheme.darkColor,
                        ),
                      ),
                      Text(
                        isUrdu
                            ? 'بہترین تجزیے کے لیے کم از کم دو سیزن کا ڈیٹا درکار ہے۔'
                            : 'At least two seasons data required for best analysis.',
                        style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary, fontWeight: fontWeight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSuggestionsCard(season, isUrdu, fontFamily, fontWeight, term, null),
        ],
      ),
    );
  }

  // موازنہ کا ڈسپلے
  Widget _buildComparisonView(bool isUrdu, String fontFamily) {
    final latest = _seasons.first;
    final previous = _seasons[1];
    final term = latest.terminology;
    final unit = term['unit'] ?? latest.displayUnit;
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    final costChange = latest.costPerUnit - previous.costPerUnit;
    final costChangePercent = previous.costPerUnit > 0
        ? (costChange / previous.costPerUnit * 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
             latest.name,
             style: TextStyle(
               fontSize: 22,
               fontWeight: fontWeight,
               fontFamily: fontFamily,
               color: AppTheme.darkColor,
             ),
             textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    latest.season,
                    style: TextStyle(fontWeight: fontWeight, fontFamily: fontFamily, color: AppTheme.themeColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFFDAAD51), shape: BoxShape.circle),
                      child: const Text('VS', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: '')),
                    ),
                  ),
                  Text(
                    previous.season,
                    style: TextStyle(fontWeight: fontWeight, fontFamily: fontFamily, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(child: _buildMiniSeasonCard(latest, isUrdu, fontFamily, fontWeight, true)),
              const SizedBox(width: 12),
              Expanded(child: _buildMiniSeasonCard(previous, isUrdu, fontFamily, fontWeight, false)),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.chartLineUp(), color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      isUrdu ? 'کارکردگی کا تجزیہ' : 'Performance Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: fontWeight,
                        fontFamily: fontFamily,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32, color: Colors.white24),
                _buildComparisonRow(
                  isUrdu ? (term['cost_per_unit'] ?? 'لاگت فی یونٹ') : 'Cost Per Unit',
                  latest.costPerUnit,
                  previous.costPerUnit,
                  'روپے', 
                  isUrdu,
                  fontFamily,
                  fontWeight,
                  inverseBetter: true,
                  isCurrency: true,
                ),
                const Divider(height: 32, indent: 40, color: Colors.white12),
                _buildComparisonRow(
                  isUrdu ? 'فی $unit منافع' : 'Profit Per $unit',
                  latest.profitPerUnit,
                  previous.profitPerUnit,
                  'روپے',
                  isUrdu,
                  fontFamily,
                  fontWeight,
                  inverseBetter: false,
                  isCurrency: true,
                ),
                const Divider(height: 32, indent: 40, color: Colors.white12),
                _buildComparisonRow(
                  isUrdu ? (term['profit'] ?? 'کل منافع') : 'Net Profit',
                  latest.netProfit,
                  previous.netProfit,
                  'روپے',
                  isUrdu,
                  fontFamily,
                  fontWeight,
                  inverseBetter: false,
                  isCurrency: true,
                ),
                const Divider(height: 32, indent: 40, color: Colors.white12),
                _buildComparisonRow(
                  isUrdu ? (term['production'] ?? 'پیداوار') : 'Production',
                  latest.totalProduction,
                  previous.totalProduction,
                  unit,
                  isUrdu,
                  fontFamily,
                  fontWeight,
                  inverseBetter: false,
                  isCurrency: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _buildSuggestionsCard(latest, isUrdu, fontFamily, fontWeight, term, costChangePercent),

          if (_seasons.length > 2) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(PhosphorIcons.clockCounterClockwise(), color: AppTheme.themeColor),
                  const SizedBox(width: 8),
                  Text(
                    isUrdu ? 'پرانے سیزن ریکارڈ' : 'Previous Season Records',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: fontWeight,
                      fontFamily: fontFamily,
                      color: AppTheme.darkColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._seasons.skip(2).map((s) => _buildHistorySeasonCard(s, isUrdu, fontFamily, fontWeight, term)).toList(),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Profession season, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            season.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: fontWeight,
              color: Colors.white,
              fontFamily: fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              season.season,
              style: TextStyle(
                color: Colors.white,
                fontFamily: fontFamily,
                fontSize: 14,
                fontWeight: fontWeight,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderStat(
                isUrdu ? 'کل خرچ' : 'Total Expense',
                season.totalExpense.toStringAsFixed(0),
                PhosphorIcons.arrowDown(),
                Colors.redAccent.shade100,
                fontFamily,
                fontWeight,
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildHeaderStat(
                isUrdu ? 'کل آمدنی' : 'Total Income',
                season.totalIncome.toStringAsFixed(0),
                PhosphorIcons.arrowUp(),
                Colors.greenAccent.shade100,
                fontFamily,
                fontWeight,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeaderStat(String label, String value, IconData icon, Color color, String fontFamily, FontWeight fontWeight) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: fontFamily, fontWeight: fontWeight),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: '',
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(Profession season, bool isUrdu, String fontFamily, FontWeight fontWeight, Map<String, String> term, String unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            isUrdu ? term['production']! : 'Production',
            '${season.totalProduction.toStringAsFixed(season.productionUnit == 'unit' ? 0 : 2)} $unit',
            PhosphorIcons.package(),
            AppTheme.themeColor,
            fontFamily,
            fontWeight,
          ),
          Divider(color: AppTheme.darkColor.withOpacity(0.1)),
          
          Row(
            children: [
              Expanded(
                child: _buildDetailRow(
                  isUrdu ? (term['cost_per_unit'] ?? 'لاگت') : 'Cost',
                  '${season.costPerUnit.toStringAsFixed(0)}',
                  PhosphorIcons.money(),
                  const Color(0xFFDAAD51),
                  fontFamily,
                  fontWeight,
                  isCompact: true,
                ),
              ),
              Container(width: 1, height: 40, color: AppTheme.darkColor.withOpacity(0.1)),
              Expanded(
                child: _buildDetailRow(
                  isUrdu ? 'فی یونٹ منافع' : 'Profit',
                  '${season.profitPerUnit.toStringAsFixed(0)}',
                  PhosphorIcons.trendUp(),
                  season.profitPerUnit >= 0 ? _greenColor : _redColor,
                  fontFamily,
                  fontWeight,
                  isCompact: true,
                ),
              ),
            ],
          ),
          
          Divider(color: AppTheme.darkColor.withOpacity(0.1)),
          
          _buildDetailRow(
            isUrdu ? (term['profit'] ?? 'کل منافع') : 'Net Profit',
            '${season.netProfit.toStringAsFixed(0)} روپے',
            PhosphorIcons.currencyCircleDollar(),
            season.isProfitable ? _greenColor : _redColor,
            fontFamily,
            fontWeight,
            subtitle: isUrdu ? '(کل منافع)' : '(Total Profit)',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color, String fontFamily, FontWeight fontWeight, {String? subtitle, bool isCompact = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), 
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isCompact ? 20 : 24),
          ),
          SizedBox(width: isCompact ? 8 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: isCompact ? 12 : 14,
                    fontFamily: fontFamily,
                    fontWeight: fontWeight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.darkColor, 
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 16 : 18,
                    fontFamily: fontFamily,
                  ),
                ),
                if (subtitle != null && !isCompact)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.7),
                      fontSize: 12,
                      fontFamily: fontFamily,
                      fontWeight: fontWeight,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSeasonCard(Profession season, bool isUrdu, String fontFamily, FontWeight fontWeight, bool isLatest) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLatest ? AppTheme.themeColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isLatest ? null : Border.all(color: AppTheme.darkColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isLatest ? (isUrdu ? 'حالیہ' : 'Latest') : (isUrdu ? 'پچھلا' : 'Previous'),
            style: TextStyle(
              fontSize: 12,
              color: isLatest ? Colors.white.withOpacity(0.8) : AppTheme.textSecondary,
              fontFamily: fontFamily,
              fontWeight: fontWeight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            season.season,
            style: TextStyle(
              fontSize: 16,
              fontWeight: fontWeight,
              color: isLatest ? Colors.white : AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isLatest ? Colors.white.withOpacity(0.15) : AppTheme.lightColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  season.netProfit >= 0 ? (isUrdu ? 'منافع' : 'Profit') : (isUrdu ? 'نقصان' : 'Loss'),
                  style: TextStyle(fontSize: 10, fontFamily: fontFamily, fontWeight: fontWeight, color: isLatest ? Colors.white.withOpacity(0.8) : AppTheme.textSecondary),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    season.netProfit.abs().toStringAsFixed(0),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isLatest
                          ? Colors.white
                          : (season.netProfit >= 0 ? _greenColor : _redColor),
                      fontSize: 16,
                      fontFamily: '',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
      String title,
      double val1,
      double val2,
      String unit,
      bool isUrdu,
      String fontFamily,
      FontWeight fontWeight, {
        required bool inverseBetter,
        bool isCurrency = false,
      }) {
    
    double diff = val1 - val2;
    double percent = val2.abs() > 0 ? (diff / val2.abs() * 100) : (diff != 0 ? 100.0 : 0.0);
    
    bool isGood = inverseBetter ? diff < 0 : diff > 0;
    bool isNeutral = diff.abs() < 0.01;
    
    Color statusColor = isNeutral 
        ? AppTheme.lightColor.withOpacity(0.7)
        : (isGood ? _greenColor : _redColor);
        
    IconData icon = isNeutral
        ? Icons.remove
        : (isGood 
            ? (inverseBetter ? Icons.arrow_downward : Icons.arrow_upward)
            : (inverseBetter ? Icons.arrow_upward : Icons.arrow_downward));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontFamily: fontFamily,
                  fontWeight: fontWeight,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      isNeutral ? '-' : '${percent.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: '',
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${val1.toStringAsFixed(isCurrency ? 0 : 2)} $unit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                  fontFamily: fontFamily,
                ),
              ),
              Text(
                '${val2.toStringAsFixed(isCurrency ? 0 : 2)} $unit',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.5),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.white.withOpacity(0.5),
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard(Profession season, bool isUrdu, String fontFamily, FontWeight fontWeight, Map<String, String> term, double? costChangePercent) {
    List<String> suggestions = [];
    
    if (costChangePercent != null) {
      if (costChangePercent > 10) {
         suggestions.add(isUrdu 
             ? '${term['cost_per_unit'] ?? 'لاگت'} میں $costChangePercent% اضافہ ہوا ہے۔ غیر ضروری اخراجات کم کریں۔'
             : 'Cost increased by ${costChangePercent.toStringAsFixed(1)}%. Reduce unnecessary expenses.');
      } else if (costChangePercent < -5) {
        suggestions.add(isUrdu
            ? 'لاگت میں کمی خوش آئند ہے۔ معیار برقرار رکھیں۔'
            : 'Cost reduction is good. Maintain quality.');
      }
    } else {
      if (!season.isProfitable) {
        suggestions.add(isUrdu
            ? 'فی الحال کاروبار خسارے میں ہے۔'
            : 'Currently business is in loss.');
      }
    }

    if (season.netProfit > 0 && season.performanceScore < 50) {
      suggestions.add(isUrdu
          ? 'منافع ہے مگر کارکردگی بہتر ہو سکتی ہے۔'
          : 'Profitable but performance can be improved.');
    }

    if (suggestions.isEmpty) {
      suggestions.add(isUrdu 
          ? 'کارکردگی تسلی بخش ہے۔' 
          : 'Performance is satisfactory.');
    }

    return Card(
      elevation: 0,
      color: const Color(0xFFFFF3E0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFFCC80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.lightbulb(), color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Text(
                  isUrdu ? 'تجزیہ و تجاویز' : 'Analysis & Suggestions',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: fontWeight,
                    fontSize: 16,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•', style: TextStyle(color: Colors.orange.shade800, fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontWeight: fontWeight,
                        color: Colors.orange.shade900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySeasonCard(Profession season, bool isUrdu, String fontFamily, FontWeight fontWeight, Map<String, String> term) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.darkColor.withOpacity(0.2)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                season.season,
                style: TextStyle(
                  fontWeight: fontWeight,
                  color: AppTheme.themeColor,
                  fontFamily: fontFamily,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isUrdu ? 'منافع' : 'Profit'}: ${season.netProfit.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: fontWeight,
                      color: season.netProfit >= 0 ? _greenColor : _redColor,
                    ),
                  ),
                  Text(
                    '${isUrdu ? 'پیداوار' : 'Prod'}: ${season.totalProduction.toStringAsFixed(0)} ${season.displayUnit}',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: fontWeight,
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIcons.caretRight(), color: AppTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
