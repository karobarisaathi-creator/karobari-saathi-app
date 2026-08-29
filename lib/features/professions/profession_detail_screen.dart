import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as transaction_model;
import 'package:account_app/features/accounts/transaction_receipt_screen.dart';
import 'add_profession_transaction_screen.dart';
import 'categories_management_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';

class ProfessionDetailScreen extends StatefulWidget {
  final Profession profession;

  const ProfessionDetailScreen({super.key, required this.profession});

  @override
  _ProfessionDetailScreenState createState() => _ProfessionDetailScreenState();
}

class _ProfessionDetailScreenState extends State<ProfessionDetailScreen> {
  late Profession _profession;
  List<String> _incomeCategories = ['تنخواہ', 'فری لانس', 'کاروبار', 'دیگر'];
  List<String> _expenseCategories = ['کرایہ', 'بجلی', 'پانی', 'ٹرانسپورٹ', 'دیگر'];
  List<transaction_model.Transaction> _transactions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isAscending = false;
  final TextEditingController _searchController = TextEditingController();

  // Defined Colors (Deprecated - using AppTheme)
  // final Color _lightColor = const Color(0xFFE0DFE1);
  // final Color _themeColor = const Color(0xFF387198);
  // final Color _darkColor = const Color(0xFF123248);
  // final Color _goldColor = const Color(0xFFDAAD51);

  @override
  void initState() {
    super.initState();
    _profession = widget.profession;
    _parseCategories(); // Load saved categories
    _loadData();
  }

  void _parseCategories() {
    if (_profession.categories.isNotEmpty) {
      List<String> loadedIncome = [];
      List<String> loadedExpense = [];
      bool hasData = false;

      for (var cat in _profession.categories) {
        if (cat.startsWith('INC:')) {
          loadedIncome.add(cat.substring(4));
          hasData = true;
        } else if (cat.startsWith('EXP:')) {
          loadedExpense.add(cat.substring(4));
          hasData = true;
        }
      }

      if (hasData) {
        _incomeCategories = loadedIncome;
        _expenseCategories = loadedExpense;
      }
    }
  }

  Future<void> _loadData() async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    try {
      final allTransactions = databaseService.getAllTransactions();
      final professionTransactions = allTransactions.where((t) => t.professionId == _profession.id).toList();
      professionTransactions.sort((a, b) => b.date.compareTo(a.date));

      // Calculate totals locally to ensure accuracy
      double totalIncome = 0;
      double totalExpense = 0;
      for (var t in professionTransactions) {
        if (t.type == 'income') {
          totalIncome += t.amount;
        } else {
          totalExpense += t.amount;
        }
      }

      // Update Profession Object with real-time calculations
      // This ensures Cost/Unit and other getters work correctly based on actual transactions
      final updatedProfession = _profession.copyWith(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );

      // Save to DB if there's a discrepancy (self-healing)
      if ((_profession.totalIncome - totalIncome).abs() > 1.0 ||
          (_profession.totalExpense - totalExpense).abs() > 1.0) {
        databaseService.updateProfession(updatedProfession);
      }

      if (mounted) {
        setState(() {
          _transactions = professionTransactions;
          _profession = updatedProfession; // Update local state with fresh calculations
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

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Consumer<DatabaseService>(
      builder: (context, databaseService, child) {
        // Get the most up-to-date profession object from the DB
        final latestProfession = databaseService.getProfession(_profession.id) ?? _profession;
        
        // Get all transactions for this profession
        final allTransactions = databaseService.getAllTransactions();
        final professionTransactions = allTransactions
            .where((t) => t.professionId == latestProfession.id)
            .toList();
        
        // Sort: newest first
        professionTransactions.sort((a, b) => b.date.compareTo(a.date));

        final filteredTransactions = professionTransactions.where((t) {
          final matchesSearch = t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.category.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesSearch;
        }).toList();

        if (_isAscending) {
          filteredTransactions.sort((a, b) => a.date.compareTo(b.date));
        }

        // Real-time totals for the summary card
        double totalIncome = 0;
        double totalExpense = 0;
        for (var t in professionTransactions) {
          if (t.type == 'income') {
            totalIncome += t.amount;
          } else {
            totalExpense += t.amount;
          }
        }
        final netProfit = totalIncome - totalExpense;

        return Scaffold(
          backgroundColor: AppTheme.lightColor,
          appBar: CustomAppBar(
            title: latestProfession.name,
            actions: [
              if (latestProfession.parentId != null)
                IconButton(
                  icon: Icon(PhosphorIcons.calendar()),
                  onPressed: () => _showSeasonSwitcher(context, databaseService, isUrdu, fontFamily),
                  tooltip: isUrdu ? 'سیزن تبدیل کریں' : 'Switch Season',
                ),
              IconButton(
                icon: Icon(PhosphorIcons.plusCircle()),
                onPressed: () => _navigateToCategoriesScreen(isUrdu),
                tooltip: isUrdu ? 'زمرے مینج کریں' : 'Manage Categories',
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Summary Card (Now using local live totals)
                _buildNewSummaryCard(latestProfession, isUrdu, fontFamily, totalIncome, totalExpense, netProfit),

                // Search & Filter Bar
                SearchSortBar(
                  controller: _searchController,
                  onSearchChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onSortToggled: () {
                    setState(() {
                      _isAscending = !_isAscending;
                    });
                  },
                  isAscending: _isAscending,
                ),

                // Transactions List Card
                if (filteredTransactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTransactions.length,
                      separatorBuilder: (context, index) => Divider(
                        color: AppTheme.darkColor.withOpacity(0.4),
                        height: 1,
                        thickness: 1.0,
                      ),
                      itemBuilder: (context, index) {
                        return _buildTransactionItem(filteredTransactions[index], isUrdu, fontFamily);
                      },
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: Column(
                      children: [
                        Icon(PhosphorIcons.receipt(), size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          isUrdu ? 'کوئی ٹرانزیکشن نہیں' : 'No Transactions',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600], fontFamily: fontFamily),
                        ),
                      ],
                    ),
                  ),
                  
                const SizedBox(height: 80), // More space for FAB
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'profession_detail_fab',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddProfessionTransactionScreen(
                    profession: latestProfession,
                    incomeCategories: _incomeCategories,
                    expenseCategories: _expenseCategories,
                  ),
                ),
              );
            },
            backgroundColor: AppTheme.darkColor,
            shape: const CircleBorder(),
            elevation: 4,
            child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 30),
          ),
        );
      },
    );
  }

  Widget _buildNewSummaryCard(Profession profession, bool isUrdu, String fontFamily, double totalIncome, double totalExpense, double netProfit) {
    // Profit Status Logic
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    String profitStatus = netProfit >= 0
        ? (isUrdu ? 'منافع' : 'Profit')
        : (isUrdu ? 'نقصان' : 'Loss');
    Color statusColor = netProfit >= 0 ? Colors.green : AppTheme.expenseColor;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.themeColor.withOpacity(0.8),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUrdu ? 'مالیاتی خلاصہ' : 'Financial Summary',
                    style: TextStyle(
                      color: AppTheme.darkColor,
                      fontSize: 16,
                      fontWeight: fontWeight,
                      fontFamily: fontFamily,
                    ),
                  ),
                  if (profession.season.isNotEmpty)
                    Text(
                      profession.season,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: '',
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  profitStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: fontWeight,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: AppTheme.darkColor.withOpacity(0.08), height: 1, thickness: 0.8),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(isUrdu ? 'آمدنی' : 'Income', totalIncome, AppTheme.incomeColor, fontFamily, fontWeight, PhosphorIcons.arrowDownLeft(PhosphorIconsStyle.bold)),
              _buildSummaryItem(isUrdu ? 'خرچ' : 'Expense', totalExpense, AppTheme.expenseColor, fontFamily, fontWeight, PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold)),
              _buildSummaryItem(isUrdu ? 'بیلنس' : 'Balance', netProfit, AppTheme.themeColor, fontFamily, fontWeight, PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold)),
            ],
          ),

          if (profession.totalProduction > 0) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem('Cost/لاگت', profession.costPerUnit, AppTheme.darkColor, fontFamily, fontWeight, PhosphorIcons.tag()),
                _buildSummaryItem('Profit/منافع', profession.profitPerUnit, AppTheme.darkColor, fontFamily, fontWeight, PhosphorIcons.trendUp()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color, String fontFamily, FontWeight fontWeight, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Text(
            'Rs ${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: '',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color.withOpacity(0.8)),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontFamily: fontFamily,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Transaction Item inside the Card
  Widget _buildTransactionItem(transaction_model.Transaction transaction, bool isUrdu, String fontFamily) {
    final bool isIncome = transaction.type == 'income';
    final Color amountColor = isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    final db = Provider.of<DatabaseService>(context, listen: false);
    final account = db.getAccount(transaction.accountId);
    final accountName = account?.name ?? (isUrdu ? 'نامعلوم پارٹی' : 'Unknown Party');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionReceiptScreen(
              transaction: transaction,
            ),
          ),
        ).then((_) => _loadData());
      },
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: amountColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isIncome ? PhosphorIcons.arrowDownLeft() : PhosphorIcons.arrowUpRight(),
          color: amountColor,
          size: 20,
        ),
      ),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  transaction.description.isNotEmpty ? transaction.description : (isUrdu ? 'ٹرانزیکشن' : 'Transaction'),
                  style: TextStyle(
                    fontWeight: fontWeight,
                    fontFamily: fontFamily,
                    color: AppTheme.darkColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rs ${transaction.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                  fontSize: 16,
                  fontFamily: '',
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      transaction.category,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                        fontWeight: fontWeight,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        accountName,
                        style: TextStyle(
                          color: AppTheme.themeColor,
                          fontFamily: fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(transaction.date),
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontFamily: '',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSeasonSwitcher(BuildContext context, DatabaseService db, bool isUrdu, String fontFamily) {
    final seasons = db.getSeasons(_profession.parentId!);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUrdu ? 'سیزن منتخب کریں' : 'Select Season',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily),
            ),
            const SizedBox(height: 15),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: seasons.length,
                itemBuilder: (context, index) {
                  final s = seasons[index];
                  final isCurrent = s.id == _profession.id;
                  return ListTile(
                    leading: Icon(
                      isCurrent ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.calendar(),
                      color: isCurrent ? AppTheme.themeColor : AppTheme.textSecondary,
                    ),
                    title: Text(
                      s.season,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? AppTheme.themeColor : AppTheme.darkColor,
                        fontFamily: fontFamily,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (!isCurrent) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => ProfessionDetailScreen(profession: s)),
                        );
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

  void _navigateToCategoriesScreen(bool isUrdu) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoriesManagementScreen(
          incomeCategories: _incomeCategories,
          expenseCategories: _expenseCategories,
          isUrdu: isUrdu,
          onCategoriesUpdated: (incomeCats, expenseCats) async {
            setState(() {
              _incomeCategories = incomeCats;
              _expenseCategories = expenseCats;
            });

            // Save changes to Database
            List<String> allCategories = [];
            for (var c in incomeCats) {
              allCategories.add('INC:$c');
            }
            for (var c in expenseCats) {
              allCategories.add('EXP:$c');
            }

            final updatedProfession = _profession.copyWith(
                categories: allCategories,
                updatedAt: DateTime.now()
            );
            
            // Update Local
            setState(() {
                _profession = updatedProfession;
            });

            final databaseService = Provider.of<DatabaseService>(context, listen: false);
            await databaseService.updateProfession(updatedProfession);
          },
        ),
      ),
    );
  }
}
