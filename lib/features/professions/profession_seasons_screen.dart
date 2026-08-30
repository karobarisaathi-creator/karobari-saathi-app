import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as transaction_model;
import 'categories_management_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/features/accounts/transaction_receipt_screen.dart';
import 'package:account_app/features/accounts/reports_screen.dart';
import 'add_profession_transaction_screen.dart';

class ProfessionSeasonsScreen extends StatefulWidget {
  final Profession masterProfession;

  const ProfessionSeasonsScreen({super.key, required this.masterProfession});

  @override
  State<ProfessionSeasonsScreen> createState() => _ProfessionSeasonsScreenState();
}

class _ProfessionSeasonsScreenState extends State<ProfessionSeasonsScreen> {
  List<String> _incomeCategories = ['تنخواہ', 'فری لانس', 'کاروبار', 'دیگر'];
  List<String> _expenseCategories = ['کرایہ', 'بجلی', 'پانی', 'ٹرانسپورٹ', 'دیگر'];
  String? _expandedSeasonId; 

  @override
  void initState() {
    super.initState();
    _parseCategories();
  }

  void _parseCategories() {
    if (widget.masterProfession.categories.isNotEmpty) {
      List<String> loadedIncome = [];
      List<String> loadedExpense = [];
      bool hasData = false;

      for (var cat in widget.masterProfession.categories) {
        if (cat.startsWith('INC:')) {
          loadedIncome.add(cat.substring(4));
          hasData = true;
        } else if (cat.startsWith('EXP:')) {
          loadedExpense.add(cat.substring(4));
          hasData = true;
        }
      }

      if (hasData) {
        setState(() {
          _incomeCategories = loadedIncome;
          _expenseCategories = loadedExpense;
        });
      }
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.masterProfession.name,
          style: TextStyle(color: Colors.white, fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.presentationChart(), color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.8,
                  maxChildSize: 0.95,
                  minChildSize: 0.5,
                  builder: (context, scrollController) => ReportsScreen(
                    selectedProfession: widget.masterProfession,
                  ),
                ),
              );
            },
            tooltip: isUrdu ? 'رپورٹ' : 'Report',
          ),
          IconButton(
            icon: Icon(PhosphorIcons.gear(), color: Colors.white),
            onPressed: () => _navigateToCategoriesScreen(context, isUrdu),
            tooltip: isUrdu ? 'زمرے مینج کریں' : 'Manage Categories',
          ),
        ],
      ),
      body: Consumer<DatabaseService>(
        builder: (context, databaseService, child) {
          final seasons = databaseService.getSeasons(widget.masterProfession.id);
          final activeSeason = seasons.where((s) => s.isActive ?? true).toList().isNotEmpty 
              ? seasons.firstWhere((s) => s.isActive ?? true) 
              : null;
          final completedSeasons = seasons.where((s) => !(s.isActive ?? true)).toList();
          
          // نئے مکمل شدہ ریکارڈز کو اوپر دکھانے کے لیے ترتیب دیں
          completedSeasons.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          double masterIncome = widget.masterProfession.totalIncome;
          double masterExpense = widget.masterProfession.totalExpense;
          for (var s in seasons) {
            masterIncome += s.totalIncome;
            masterExpense += s.totalExpense;
          }
          final netProfit = masterIncome - masterExpense;

          return Column(
            children: [
              _buildCompactStatsHeader(context, masterIncome, masterExpense, netProfit, isUrdu, fontFamily),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (activeSeason != null) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.themeColor.withValues(alpha: 0.2)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                  InkWell(
                                    onLongPress: () => _showSeasonOptions(context, activeSeason, isUrdu, fontFamily, databaseService),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Text(
                                                  isUrdu ? 'جاری:' : 'Active:',
                                                  style: TextStyle(fontSize: 13, color: AppTheme.themeColor, fontWeight: FontWeight.bold, fontFamily: fontFamily),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  activeSeason.season,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildSmallStat(isUrdu ? 'آمدنی' : 'In', activeSeason.totalIncome, AppTheme.incomeColor, isUrdu, fontFamily),
                                          const SizedBox(width: 8),
                                          _buildSmallStat(isUrdu ? 'خرچ' : 'Out', activeSeason.totalExpense, AppTheme.expenseColor, isUrdu, fontFamily),
                                          const SizedBox(width: 8),
                                          _buildSmallStat(isUrdu ? 'منافع' : 'Net', activeSeason.netProfit, AppTheme.themeColor, isUrdu, fontFamily),
                                        ],
                                      ),
                                    ),
                                  ),
                              const Divider(height: 1),
                              _buildTransactionsForSeason(context, databaseService, activeSeason, isUrdu, fontFamily, hideSummary: true),
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
                              color: AppTheme.themeColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.themeColor.withValues(alpha: 0.1), style: BorderStyle.solid),
                            ),
                            child: Column(
                              children: [
                                Icon(PhosphorIcons.calendarPlus(), size: 48, color: AppTheme.themeColor),
                                const SizedBox(height: 12),
                                Text(
                                  isUrdu ? 'کوئی جاری سیزن نہیں ہے' : 'No active season found',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontFamily: fontFamily),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isUrdu ? 'نیا سیزن شروع کریں تاکہ آپ اپنا حساب الگ رکھ سکیں۔' : 'Start a new season to keep your records organized.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontFamily: fontFamily),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _startNewSeasonSilently(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.themeColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(isUrdu ? 'نیا سیزن شروع کریں' : 'Start New Season', style: TextStyle(fontFamily: fontFamily)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (completedSeasons.isNotEmpty || (widget.masterProfession.totalIncome > 0 || widget.masterProfession.totalExpense > 0)) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.darkColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            isUrdu ? 'مکمل شدہ ریکارڈز (پرانے)' : 'Completed Records',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontFamily: fontFamily),
                          ),
                        ),
                      ),
                      
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0 && (widget.masterProfession.totalIncome > 0 || widget.masterProfession.totalExpense > 0)) {
                               return _buildCompactSeasonItem(
                                  context, 
                                  widget.masterProfession.copyWith(season: isUrdu ? 'بنیادی ریکارڈ' : 'Base Record'),
                                  isUrdu, fontFamily, databaseService
                               );
                            }
                            final season = completedSeasons[(widget.masterProfession.totalIncome > 0 || widget.masterProfession.totalExpense > 0) ? index - 1 : index];
                            return _buildCompactSeasonItem(context, season, isUrdu, fontFamily, databaseService);
                          },
                          childCount: (widget.masterProfession.totalIncome > 0 || widget.masterProfession.totalExpense > 0) 
                              ? completedSeasons.length + 1 : completedSeasons.length,
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
      floatingActionButton: Consumer<DatabaseService>(
        builder: (context, db, child) {
          final activeSeason = db.getSeasons(widget.masterProfession.id).where((s) => s.isActive ?? true).firstOrNull;
          if (activeSeason == null) return const SizedBox.shrink();
          
          return FloatingActionButton(
            onPressed: () => _navigateToAddTransaction(context, activeSeason),
            backgroundColor: AppTheme.darkColor,
            shape: const CircleBorder(),
            tooltip: isUrdu ? 'نیا اندراج' : 'Add Transaction',
            child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 30),
          );
        }
      ),
    );
  }

  Widget _buildCompactStatsHeader(BuildContext context, double income, double expense, double netProfit, bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          _buildHeaderStatItem(isUrdu ? "آمدنی" : "Income", income, Colors.white, fontFamily, AppTheme.incomeColor),
          _buildStatDivider(),
          _buildHeaderStatItem(isUrdu ? "خرچ" : "Expense", expense, Colors.white, fontFamily, AppTheme.expenseColor),
          _buildStatDivider(),
          _buildHeaderStatItem(isUrdu ? "بچت" : "Net", netProfit.abs(), Colors.white, fontFamily, netProfit >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor, isBold: true),
        ],
      ),
    );
  }

  Widget _buildHeaderStatItem(String label, double amount, Color color, String fontFamily, Color iconColor, {bool isBold = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: fontFamily)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text("Rs ${amount.toStringAsFixed(0)}", style: TextStyle(color: color, fontSize: isBold ? 18 : 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() => Container(height: 18, width: 1, color: Colors.white12);

  Widget _buildCompactSeasonItem(BuildContext context, Profession season, bool isUrdu, String fontFamily, DatabaseService db) {
    final isExpanded = _expandedSeasonId == season.id;
    final isBaseRecord = season.season == (isUrdu ? 'بنیادی ریکارڈ' : 'Base Record');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkColor.withValues(alpha: 0.05), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.1))
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedSeasonId = isExpanded ? null : season.id;
              });
            },
            onLongPress: () {
              _showSeasonOptions(context, season, isUrdu, fontFamily, db, isBaseRecord: isBaseRecord);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: _buildSmallStat(isUrdu ? 'آمدنی' : 'In', season.totalIncome, AppTheme.incomeColor, isUrdu, fontFamily)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildSmallStat(isUrdu ? 'خرچ' : 'Out', season.totalExpense, AppTheme.expenseColor, isUrdu, fontFamily)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildSmallStat(isUrdu ? 'منافع' : 'Net', season.netProfit, AppTheme.darkColor, isUrdu, fontFamily)),
                  if (!isBaseRecord) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.darkColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        season.season,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 13, 
                          fontFamily: '',
                          color: AppTheme.darkColor
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            _buildTransactionsForSeason(context, db, season, isUrdu, fontFamily, hideSummary: true),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsForSeason(BuildContext context, DatabaseService db, Profession season, bool isUrdu, String fontFamily, {bool hideSummary = false}) {
    final txs = db.getAllTransactions().where((t) => t.professionId == season.id).toList();
    txs.sort((a, b) => b.date.compareTo(a.date));

    if (txs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text(isUrdu ? 'کوئی ٹرانزیکشن نہیں' : 'No transactions', style: const TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }

    return Column(
      children: [
        if (!hideSummary) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: _buildSmallStat(isUrdu ? 'آمدنی' : 'Income', season.totalIncome, AppTheme.incomeColor, isUrdu, fontFamily)),
                Expanded(child: _buildSmallStat(isUrdu ? 'خرچ' : 'Expense', season.totalExpense, AppTheme.expenseColor, isUrdu, fontFamily)),
                Expanded(child: _buildSmallStat(isUrdu ? 'منافع' : 'Profit', season.netProfit, AppTheme.themeColor, isUrdu, fontFamily)),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: txs.length,
          itemBuilder: (context, index) {
            return _buildTransactionItem(context, txs[index], isUrdu, fontFamily, isLast: index == txs.length - 1);
          },
        ),
      ],
    );
  }

  Widget _buildTransactionListSliver(BuildContext context, DatabaseService db, Profession activeSeason, bool isUrdu, String fontFamily) {
    final txs = db.getAllTransactions().where((t) => t.professionId == activeSeason.id).toList();
    txs.sort((a, b) => b.date.compareTo(a.date));

    if (txs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(PhosphorIcons.receipt(), size: 48, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text(isUrdu ? 'کوئی ٹرانزیکشن نہیں' : 'No transactions', style: TextStyle(color: Colors.grey, fontFamily: fontFamily)),
              TextButton(
                onPressed: () => _navigateToAddTransaction(context, activeSeason),
                child: Text(isUrdu ? 'پہلا اندراج کریں' : 'Add First Transaction'),
              )
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final t = txs[index];
          return _buildTransactionItem(context, t, isUrdu, fontFamily, isLast: index == txs.length - 1);
        },
        childCount: txs.length,
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, transaction_model.Transaction t, bool isUrdu, String fontFamily, {bool isLast = false}) {
    final isIncome = t.type == 'income';
    final db = Provider.of<DatabaseService>(context, listen: false);
    final account = db.getAccount(t.accountId);
    
    // پارٹی کا نام اگر موجود ہو، ورنہ زمرہ
    final String displayName = account?.name ?? t.category;

    return Column(
      children: [
        ListTile(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TransactionReceiptScreen(transaction: t))),
          title: Text(
            t.description.isNotEmpty ? t.description : displayName, 
            style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.darkColor)
          ),
          subtitle: Row(
            children: [
              Text(DateFormat('dd MMM').format(t.date), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              if (t.description.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(color: AppTheme.themeColor, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: fontFamily),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else 
                const Spacer(), // اگر ڈسکرپشن نہیں ہے تو اسپیسر استعمال کریں
                
              if (t.description.isNotEmpty) const SizedBox(width: 8),
              
              // رقم اب تاریخ والی لائن میں ہی ہے لیکن دائیں طرف پش کی گئی ہے
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isIncome ? PhosphorIcons.arrowDownLeft() : PhosphorIcons.arrowUpRight(), 
                    color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor, 
                    size: 12
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Rs ${t.amount.toStringAsFixed(0)}', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 13, 
                      color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor
                    )
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 20, endIndent: 20, thickness: 0.5),
      ],
    );
  }

  void _navigateToAddTransaction(BuildContext context, Profession season) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddProfessionTransactionScreen(
      profession: season,
      incomeCategories: _incomeCategories, 
      expenseCategories: _expenseCategories,
    )));
  }

  void _navigateToCategoriesScreen(BuildContext context, bool isUrdu) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoriesManagementScreen(
      incomeCategories: _incomeCategories,
      expenseCategories: _expenseCategories,
      isUrdu: isUrdu, 
      onCategoriesUpdated: (inCats, outCats) async {
         setState(() {
            _incomeCategories = inCats;
            _expenseCategories = outCats;
         });

         List<String> allCategories = [];
         for (var c in inCats) allCategories.add('INC:$c');
         for (var c in outCats) allCategories.add('EXP:$c');

         final updatedProfession = widget.masterProfession.copyWith(
            categories: allCategories,
            updatedAt: DateTime.now()
         );
         
         await Provider.of<DatabaseService>(context, listen: false).updateProfession(updatedProfession);
      }
    )));
  }

  Future<void> _startNewSeasonSilently(BuildContext context) async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    
    setState(() => _expandedSeasonId = null); 

    String seasonName = DateFormat('yyyy').format(DateTime.now());
    
    final existingSeasons = databaseService.getSeasons(widget.masterProfession.id);
    int count = existingSeasons.where((s) => s.season.contains(seasonName)).length;
    if (count > 0) {
      seasonName = "$seasonName (${count + 1})";
    }

    final newSeason = Profession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: widget.masterProfession.name,
      categories: widget.masterProfession.categories,
      description: widget.masterProfession.description,
      totalProduction: 0,
      productionUnit: widget.masterProfession.productionUnit,
      season: seasonName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
      isMaster: false,
      parentId: widget.masterProfession.id,
    );

    try {
      await databaseService.addProfession(newSeason);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isUrdu ? 'نیا سیزن شروع کر دیا گیا ہے' : 'New season started successfully'),
        backgroundColor: AppTheme.themeColor,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCompleteSeasonDialog(BuildContext context, Profession season, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isUrdu ? 'سیزن مکمل کریں؟' : 'Complete Season?',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isUrdu 
            ? 'کیا آپ اس سیزن کو مکمل قرار دینا چاہتے ہیں؟ مکمل ہونے کے بعد یہ "مکمل شدہ ریکارڈز" میں منتقل ہو جائے گا۔' 
            : 'Do you want to mark this season as completed? It will move to "Completed Records".',
          style: TextStyle(fontFamily: fontFamily),
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
            text: isUrdu ? 'مکمل کریں' : 'Complete',
            icon: PhosphorIcons.checkCircle(),
            onPressed: () async {
              final databaseService = Provider.of<DatabaseService>(context, listen: false);
              final updated = season.copyWith(isActive: false, updatedAt: DateTime.now());
              await databaseService.updateProfession(updated);
              if (context.mounted) Navigator.pop(context);
            },
            color: AppTheme.incomeColor,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }

  void _showSeasonOptions(BuildContext context, Profession season, bool isUrdu, String fontFamily, DatabaseService db, {bool isBaseRecord = false}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                isBaseRecord 
                  ? (isUrdu ? 'بنیادی ریکارڈ کے اختیارات' : 'Base Record Options')
                  : '${isUrdu ? 'سیزن' : 'Season'}: ${season.season}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: fontFamily),
              ),
            ),
            if (!isBaseRecord && (season.isActive ?? true))
              ListTile(
                leading: Icon(PhosphorIcons.checkCircle(), color: AppTheme.incomeColor),
                title: Text(
                  isUrdu ? 'مکمل مارک کریں' : 'Mark as Completed',
                  style: TextStyle(fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCompleteSeasonDialog(context, season, isUrdu, fontFamily);
                },
              ),
            if (!isBaseRecord && !(season.isActive ?? true))
              ListTile(
                leading: Icon(PhosphorIcons.playCircle(), color: AppTheme.themeColor),
                title: Text(
                  isUrdu ? 'دوبارہ فعال کریں' : 'Reactivate',
                  style: TextStyle(fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _reactivateSeason(context, season, isUrdu, fontFamily, db);
                },
              ),
            ListTile(
              leading: Icon(PhosphorIcons.trash(), color: AppTheme.expenseColor),
              title: Text(
                isBaseRecord 
                  ? (isUrdu ? 'بنیادی ریکارڈ صاف کریں' : 'Clear Base Record')
                  : (isUrdu ? 'حذف کریں' : 'Delete'),
                style: TextStyle(fontFamily: fontFamily, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
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

  void _showClearBaseRecordDialog(BuildContext context, bool isUrdu, String fontFamily, DatabaseService db) {
    bool isConfirmed = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isUrdu ? 'بنیادی ریکارڈ صاف کریں؟' : 'Clear Base Record?',
            style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUrdu 
                  ? 'کیا آپ واقعی اس پیشے کا بنیادی ریکارڈ (وہ ٹرانزیکشنز جو کسی سیزن میں نہیں ہیں) صاف کرنا چاہتے ہیں؟ اس سے صرف پرانا ڈیٹا مٹے گا، نئے سیزنز محفوظ رہیں گے۔' 
                  : 'Are you sure you want to clear the base record (transactions not linked to any season)? This will only delete legacy data; active seasons will remain safe.',
                style: TextStyle(fontFamily: fontFamily, fontSize: 13),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: isConfirmed,
                onChanged: (val) => setDialogState(() => isConfirmed = val ?? false),
                title: Text(
                  isUrdu ? 'جی ہاں، میں مٹانا چاہتا ہوں' : 'Yes, I want to clear',
                  style: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.bold),
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
              onPressed: isConfirmed ? () async {
                // 1. Get transactions linked to master but NOT to any season
                final masterId = widget.masterProfession.id;
                final txs = db.getAllTransactions().where((t) => t.professionId == masterId).toList();
                
                for (var t in txs) {
                   await db.deleteTransaction(t.id);
                }
                
                // 2. Reset master totals
                final updatedMaster = widget.masterProfession.copyWith(
                  totalIncome: 0,
                  totalExpense: 0,
                  updatedAt: DateTime.now(),
                );
                await db.updateProfession(updatedMaster);
                
                if (context.mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                     content: Text(isUrdu ? 'بنیادی ریکارڈ صاف کر دیا گیا' : 'Base record cleared'),
                     backgroundColor: AppTheme.themeColor,
                   ));
                }
              } : null,
              color: AppTheme.expenseColor,
              size: AppButtonSize.small,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteSeasonDialog(BuildContext context, Profession season, bool isUrdu, String fontFamily) {
    bool isConfirmed = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isUrdu ? 'حذف کریں؟' : 'Delete Season?',
            style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
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
                  isUrdu ? 'جی ہاں، میں ڈیلیٹ کرنا چاہتا ہوں' : 'Yes, I want to delete',
                  style: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.bold),
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
              onPressed: isConfirmed ? () async {
                final databaseService = Provider.of<DatabaseService>(context, listen: false);
                await databaseService.deleteProfession(season.id);
                if (context.mounted) Navigator.pop(context);
              } : null,
              color: AppTheme.expenseColor,
              size: AppButtonSize.small,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reactivateSeason(BuildContext context, Profession season, bool isUrdu, String fontFamily, DatabaseService db) async {
    final allSeasons = db.getSeasons(widget.masterProfession.id);
    final activeSeason = allSeasons.where((s) => s.isActive ?? true).firstOrNull;

    if (activeSeason != null) {
      await db.updateProfession(activeSeason.copyWith(isActive: false));
    }

    await db.updateProfession(season.copyWith(isActive: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isUrdu ? 'سیزن دوبارہ فعال کر دیا گیا ہے' : 'Season reactivated successfully'),
        backgroundColor: AppTheme.themeColor,
      ));
    }
  }

  Widget _buildSmallStat(String label, double amount, Color color, bool isUrdu, String fontFamily) {
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
}
