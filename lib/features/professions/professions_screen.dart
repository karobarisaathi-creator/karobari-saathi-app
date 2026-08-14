import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'profession_detail_screen.dart';
import 'profession_dialog.dart';
import 'package:account_app/features/accounts/reports_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

class ProfessionsScreen extends StatefulWidget {
  @override
  _ProfessionsScreenState createState() => _ProfessionsScreenState();
}

class _ProfessionsScreenState extends State<ProfessionsScreen> {
  List<Profession> _professions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfessions();
  }

  Future<void> _loadProfessions() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final professions = await databaseService.getProfessions();
      if (mounted) {
        setState(() {
          _professions = professions;
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
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'پیشے/منصوبے' : 'Professions & Categories',
        showBackButton: false,
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.chartBar()),
            tooltip: isUrdu ? 'رپورٹس' : 'Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ReportsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<DatabaseService>(
        builder: (context, databaseService, child) {
          final professions = databaseService.getProfessions();
          
          if (professions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.briefcase(), size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text(
                    isUrdu ? 'کوئی پیشہ نہیں' : 'No Professions',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppTheme.darkColor,
                      fontFamily: fontFamily,
                      fontWeight: fontWeight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isUrdu ? 'پہلا پیشہ شامل کریں' : 'Add your first profession',
                    style: TextStyle(
                      color: AppTheme.darkColor.withOpacity(0.7),
                      fontFamily: fontFamily,
                      fontWeight: fontWeight,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => await databaseService.fetchFromFirebase(),
            color: AppTheme.themeColor,
            backgroundColor: Colors.white,
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: professions.length,
              itemBuilder: (context, index) {
                return _buildProfessionCard(professions[index], isUrdu, fontFamily, fontWeight);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'professions_fab',
        onPressed: () {
          _showAddProfessionDialog(context, isUrdu);
        },
        backgroundColor: AppTheme.darkColor,
        shape: const CircleBorder(),
        tooltip: isUrdu ? 'نیا پیشہ' : 'New Profession',
        child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildProfessionCard(Profession profession, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    String statusText = profession.isActive ? (isUrdu ? 'فعال' : 'Active') : (isUrdu ? 'مکمل' : 'Completed');
    Color statusColor = profession.isActive ? Colors.green : Colors.orange;

    IconData displayIcon = PhosphorIcons.briefcase(); 
    String subtitle = profession.description ?? '';

    if (profession.description != null && profession.description!.startsWith('ICON:')) {
      try {
        final parts = profession.description!.split('|');
        final iconName = parts[0].substring(5); 

        if (iconName == 'shop') displayIcon = PhosphorIcons.storefront();
        else if (iconName == 'agriculture') displayIcon = PhosphorIcons.leaf();
        else if (iconName == 'services') displayIcon = PhosphorIcons.wrench();
        else if (iconName == 'medical') displayIcon = PhosphorIcons.firstAid();
        else if (iconName == 'education') displayIcon = PhosphorIcons.graduationCap();
        else if (iconName == 'transport') displayIcon = PhosphorIcons.truck();
        else if (iconName == 'real_estate') displayIcon = PhosphorIcons.buildings();
        else if (iconName == 'livestock') displayIcon = PhosphorIcons.cow();
        else if (iconName == 'factory') displayIcon = PhosphorIcons.factory();
        else if (iconName == 'hammer') displayIcon = PhosphorIcons.hammer();
        else if (iconName == 'land') displayIcon = PhosphorIcons.mapPin();
        else if (iconName == 'tools') displayIcon = PhosphorIcons.wrench();
        else if (iconName == 'food') displayIcon = PhosphorIcons.cookingPot();
        else if (iconName == 'tech') displayIcon = PhosphorIcons.cpu();
        else if (iconName == 'finance') displayIcon = PhosphorIcons.bank();
        else if (iconName == 'cart') displayIcon = PhosphorIcons.shoppingCart();
        else if (iconName == 'vehicle') displayIcon = PhosphorIcons.car();
        else if (iconName == 'personal') displayIcon = PhosphorIcons.user();

        if (parts.length > 1) {
          subtitle = parts.sublist(1).join('|');
        } else {
          subtitle = '';
        }
      } catch (e) {}
    }

    if (subtitle.trim().isEmpty) {
      subtitle = isUrdu ? 'کوئی تفصیل نہیں' : 'No Description';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.themeColor.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfessionDetailScreen(profession: profession)),
            ).then((_) => _loadProfessions());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.themeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(displayIcon, color: AppTheme.themeColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profession.name,
                            style: TextStyle(
                              color: AppTheme.darkColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: fontFamily,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profession.season.isNotEmpty ? profession.season : subtitle,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(PhosphorIcons.dotsThreeVertical(), color: AppTheme.textSecondary),
                      onSelected: (value) => _handleProfessionAction(value, profession, isUrdu, fontFamily, fontWeight),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'reports', child: _buildPopupItem(isUrdu ? 'رپورٹس' : 'Reports', PhosphorIcons.chartBar(), AppTheme.themeColor, fontFamily, fontWeight)),
                        PopupMenuItem(value: 'edit', child: _buildPopupItem(isUrdu ? 'ترمیم' : 'Edit', PhosphorIcons.pencilLine(), AppTheme.themeColor, fontFamily, fontWeight)),
                        PopupMenuItem(value: profession.isActive ? 'complete' : 'activate', child: _buildPopupItem(profession.isActive ? (isUrdu ? 'مکمل کریں' : 'Mark Completed') : (isUrdu ? 'فعال کریں' : 'Activate'), profession.isActive ? PhosphorIcons.checkCircle() : PhosphorIcons.play(), AppTheme.themeColor, fontFamily, fontWeight)),
                        PopupMenuItem(value: 'delete', child: _buildPopupItem(isUrdu ? 'حذف' : 'Delete', PhosphorIcons.trash(), AppTheme.expenseColor, fontFamily, fontWeight)),
                      ],
                    ),
                  ],
                ),
                if (profession.description != null && profession.description!.isNotEmpty && !profession.description!.startsWith('ICON:'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      profession.description!,
                      style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.7), fontFamily: fontFamily, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.lightColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppTheme.darkColor.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      _buildStatItem(isUrdu ? 'آمدنی' : 'Income', profession.totalIncome, AppTheme.incomeColor, fontFamily, fontWeight, PhosphorIcons.arrowDownLeft(PhosphorIconsStyle.bold)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(width: 1, height: 35, color: Colors.grey.withOpacity(0.2)),
                      ),
                      _buildStatItem(isUrdu ? 'خرچ' : 'Expense', profession.totalExpense, AppTheme.expenseColor, fontFamily, fontWeight, PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(width: 1, height: 35, color: Colors.grey.withOpacity(0.2)),
                      ),
                      _buildStatItem(isUrdu ? 'منافع' : 'Profit', profession.netProfit, AppTheme.themeColor, fontFamily, fontWeight, PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: AppTheme.darkColor.withOpacity(0.2), thickness: 1.2),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorIcons.clock(), size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${isUrdu ? 'اپڈیٹ' : 'Upd'}: ${profession.updatedAt.day}/${profession.updatedAt.month} ${profession.updatedAt.hour}:${profession.updatedAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Icon(PhosphorIcons.calendar(), size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${profession.createdAt.day}/${profession.createdAt.month}/${profession.createdAt.year}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontFamily: fontFamily, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupItem(String text, IconData icon, Color color, String fontFamily, FontWeight fontWeight) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontWeight: fontWeight)),
      ],
    );
  }

  Widget _buildStatItem(String label, double amount, Color color, String fontFamily, FontWeight fontWeight, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: fontFamily, fontWeight: fontWeight)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Rs ${amount.abs().toStringAsFixed(0)}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  void _handleProfessionAction(String action, Profession profession, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    switch (action) {
      case 'reports':
        Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen(selectedProfession: profession)));
        break;
      case 'edit':
        _showEditProfessionDialog(profession, isUrdu);
        break;
      case 'complete':
      case 'activate':
        _toggleProfessionStatus(profession, isUrdu);
        break;
      case 'delete':
        _showDeleteProfessionDialog(profession, isUrdu, fontFamily, fontWeight);
        break;
    }
  }

  void _showAddProfessionDialog(BuildContext context, bool isUrdu) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfessionDialog(
      isUrdu: isUrdu,
      onSave: (name, categories, description, totalProduction, productionUnit, season, targetProduction, budgetLimits, benchmarkCostPerUnit) async {
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        final profession = Profession(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          categories: categories,
          description: description,
          totalProduction: totalProduction,
          productionUnit: productionUnit,
          season: season,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          targetProduction: targetProduction,
          budgetLimits: budgetLimits,
          benchmarkCostPerUnit: benchmarkCostPerUnit,
        );
        await databaseService.addProfession(profession);
        _loadProfessions();
        if (mounted) Navigator.pop(context);
      },
    )));
  }

  void _showEditProfessionDialog(Profession profession, bool isUrdu) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfessionDialog(
      isUrdu: isUrdu,
      profession: profession,
      onSave: (name, categories, description, totalProduction, productionUnit, season, targetProduction, budgetLimits, benchmarkCostPerUnit) async {
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        final updatedProfession = profession.copyWith(
          name: name,
          categories: categories,
          description: description,
          totalProduction: totalProduction,
          productionUnit: productionUnit,
          season: season,
          updatedAt: DateTime.now(),
          targetProduction: targetProduction,
          budgetLimits: budgetLimits,
          benchmarkCostPerUnit: benchmarkCostPerUnit,
        );
        await databaseService.updateProfession(updatedProfession);
        _loadProfessions();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isUrdu ? 'ترمیم محفوظ کر لی گئی' : 'Changes saved successfully', style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '')),
            backgroundColor: AppTheme.themeColor,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
    )));
  }

  void _toggleProfessionStatus(Profession profession, bool isUrdu) {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final updatedProfession = profession.copyWith(isActive: !profession.isActive, updatedAt: DateTime.now());
    databaseService.updateProfession(updatedProfession);
    _loadProfessions();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isUrdu ? 'پیشہ کی حیثیت تبدیل کر دی گئی' : 'Profession status updated', style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '')),
      backgroundColor: AppTheme.themeColor,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showDeleteProfessionDialog(Profession profession, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isUrdu ? 'پیشہ ڈیلیٹ کریں' : 'Delete Profession', style: TextStyle(fontFamily: fontFamily, color: AppTheme.darkColor, fontWeight: fontWeight)),
        content: Text(isUrdu ? 'کیا آپ واقعی "${profession.name}" پیشہ ڈیلیٹ کرنا چاہتے ہیں؟' : 'Are you sure you want to delete "${profession.name}"?', style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary, fontWeight: fontWeight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isUrdu ? 'منسوخ' : 'Cancel', style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () {
              final databaseService = Provider.of<DatabaseService>(context, listen: false);
              databaseService.deleteProfession(profession.id);
              _loadProfessions();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isUrdu ? 'پیشہ ڈیلیٹ کر دیا گیا' : 'Deleted successfully'), backgroundColor: AppTheme.expenseColor, behavior: SnackBarBehavior.floating));
            },
            child: Text(isUrdu ? 'ڈیلیٹ' : 'Delete', style: TextStyle(color: AppTheme.expenseColor, fontFamily: fontFamily, fontWeight: fontWeight)),
          ),
        ],
      ),
    );
  }
}
