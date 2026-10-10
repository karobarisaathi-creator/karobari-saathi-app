import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/features/professions/profession_dialog.dart';
import 'package:account_app/features/professions/profession_seasons_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/config/professions_config.dart';

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
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);
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
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isUrdu ? 'پیشے/منصوبے' : 'Professions & Categories',
          style: TextStyle(
            color: Colors.white,
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddProfessionDialog(context, isUrdu),
            icon: Icon(PhosphorIcons.plusCircle(), color: Colors.white, size: 26),
            tooltip: isUrdu ? 'نیا پیشہ' : 'New Profession',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DatabaseService>(
        builder: (context, databaseService, child) {
          var professions = databaseService.getMasterProfessions();
          final allProfessions = databaseService.getProfessions();

          if (professions.isEmpty && allProfessions.isNotEmpty) {
            professions = allProfessions
                .where((p) =>
                    (p.isMaster ?? false) ||
                    p.parentId == null ||
                    p.parentId!.trim().isEmpty)
                .toList();
            if (professions.isEmpty) {
              professions = allProfessions;
            }
          }

          double profIncome = 0;
          double profExpense = 0;
          for (var p in allProfessions) {
            if (!(p.isMaster ?? false)) {
              profIncome += p.totalIncome;
              profExpense += p.totalExpense;
            }
          }
          double profProfit = profIncome - profExpense;

          return Column(
            children: [
              // ═══ یکساں ڈارک ہیڈر (100% ڈیش بورڈ جیسا) ═══
              _buildLargeDarkHeader(
                profIncome: profIncome,
                profExpense: profExpense,
                profProfit: profProfit,
                showStats: allProfessions.isNotEmpty,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),

              // ═══ CONTENT ═══
              Expanded(
                child: professions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIcons.briefcase(),
                                size: 80, color: Colors.grey[400]),
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
                              isUrdu
                                  ? 'پہلا پیشہ شامل کریں'
                                  : 'Add your first profession',
                              style: TextStyle(
                                color: AppTheme.darkColor.withValues(alpha: 0.7),
                                fontFamily: fontFamily,
                                fontWeight: fontWeight,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            await databaseService.fetchFromFirebase(),
                        color: AppTheme.themeColor,
                        backgroundColor: Colors.white,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: professions.length,
                          itemBuilder: (context, index) {
                            return _buildProfessionListItem(
                              professions[index],
                              isUrdu,
                              fontFamily,
                              fontWeight,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLargeDarkHeader({
    required double profIncome,
    required double profExpense,
    required double profProfit,
    required bool showStats,
    required bool isUrdu,
    required String fontFamily,
  }) {
    String profNetLabel = isUrdu ? "میزان" : "Net";
    if (profProfit > 0) {
      profNetLabel = isUrdu ? "بچت" : "Profit";
    } else if (profProfit < 0) {
      profNetLabel = isUrdu ? "خسارہ" : "Loss";
    }

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 60,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
      ),
      child: showStats
          ? Row(
              children: [
                _buildHeaderStatItem(
                  isUrdu ? 'آمدنی' : 'Income',
                  profIncome,
                  Colors.white70,
                  fontFamily,
                  PhosphorIcons.arrowDownLeft(),
                ),
                _buildStatDivider(),
                _buildHeaderStatItem(
                  isUrdu ? 'خرچ' : 'Expense',
                  profExpense,
                  Colors.white70,
                  fontFamily,
                  PhosphorIcons.arrowUpRight(),
                ),
                _buildStatDivider(),
                _buildHeaderStatItem(
                  profNetLabel,
                  profProfit.abs(),
                  Colors.white70,
                  fontFamily,
                  PhosphorIcons.trendUp(),
                  isBold: true,
                ),
              ],
            )
          : const SizedBox(height: 8),
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

  Widget _buildStatDivider() {
    return Container(height: 20, width: 1, color: Colors.white12);
  }

  Widget _buildProfessionListItem(Profession profession, bool isUrdu,
      String fontFamily, FontWeight fontWeight) {
    IconData displayIcon = PhosphorIcons.briefcase();
    String? cleanDescription;
    String categoryLabel = '';
    String displayName = profession.name;

    if (profession.description != null) {
      if (profession.description!.startsWith('ICON:')) {
        try {
          final parts = profession.description!.split('|');
          final iconKey = parts[0].substring(5);

          if (ProfessionsConfig.iconMap.containsKey(iconKey)) {
            displayIcon = ProfessionsConfig.iconMap[iconKey]!;

            // Try to find Urdu label from config if possible
            final groupMatch = ProfessionsConfig.professionGroups
                .where((group) => group.id == iconKey)
                .firstOrNull;
            final configMatch = ProfessionsConfig.allProfessions
                .where((p) => p.id == iconKey)
                .firstOrNull;
            if (groupMatch != null) {
              categoryLabel = isUrdu ? groupMatch.nameUrdu : groupMatch.name;
              displayName = categoryLabel;
            } else if (configMatch != null) {
              categoryLabel = isUrdu
                  ? configMatch.name
                  : configMatch.id[0].toUpperCase() +
                      configMatch.id.substring(1);
            } else {
              // Fallback labels
              final Map<String, String> labels = {
                'agriculture': isUrdu ? 'زراعت' : 'Agriculture',
                'livestock': isUrdu ? 'مال مویشی' : 'Livestock',
                'transport': isUrdu ? 'گاڑی/ٹرک' : 'Transport',
                'shop': isUrdu ? 'دکان' : 'Shop',
                'factory': isUrdu ? 'فیکٹری' : 'Factory',
                'hammer': isUrdu ? 'تعمیرات' : 'Construction',
                'land': isUrdu ? 'زمین/پلاٹ' : 'Land',
                'tools': isUrdu ? 'خدمات' : 'Services',
                'food': isUrdu ? 'کھانا' : 'Food',
                'tech': isUrdu ? 'ٹیکنالوجی' : 'Tech',
                'finance': isUrdu ? 'بینک' : 'Finance',
                'cart': isUrdu ? 'خریداری' : 'Cart',
              };
              categoryLabel = labels[iconKey] ?? (isUrdu ? 'دیگر' : 'Other');
            }
          }

          if (parts.length > 1) {
            cleanDescription = parts.sublist(1).join('|');
          }
        } catch (e) {}
      } else {
        cleanDescription = profession.description;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(displayIcon, color: AppTheme.themeColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: AppTheme.darkColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                    if (categoryLabel.isNotEmpty &&
                        categoryLabel != displayName)
                      Text(
                        categoryLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.themeColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: fontFamily,
                        ),
                      ),
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.calendar(),
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy')
                              .format(profession.createdAt),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(PhosphorIcons.dotsThreeVertical(),
                    color: AppTheme.textSecondary, size: 28),
                padding: EdgeInsets.zero,
                onSelected: (value) => _handleProfessionAction(
                    value, profession, isUrdu, fontFamily, fontWeight),
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'edit',
                      child: _buildPopupItem(
                          isUrdu ? 'ترمیم' : 'Edit',
                          PhosphorIcons.pencilLine(),
                          AppTheme.themeColor,
                          fontFamily,
                          fontWeight)),
                  PopupMenuItem(
                      value: 'delete',
                      child: _buildPopupItem(
                          isUrdu ? 'حذف' : 'Delete',
                          PhosphorIcons.trash(),
                          AppTheme.expenseColor,
                          fontFamily,
                          fontWeight)),
                ],
              ),
            ],
          ),
          if (cleanDescription != null && cleanDescription.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.5),
            ),
            Text(
              cleanDescription,
              style: TextStyle(
                fontSize: 15, // Increased font size
                color: AppTheme.darkColor.withValues(alpha: 0.8),
                fontFamily: fontFamily,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () {
                // اب تمام پیشے براہ راست سیزن سکرین پر کھلیں گے تاکہ ایک ہی طرز کا لیجر استعمال ہو
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfessionSeasonsScreen(
                        masterProfession: profession.parentId == null
                            ? profession
                            : Provider.of<DatabaseService>(context,
                                        listen: false)
                                    .getProfession(profession.parentId!) ??
                                profession),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                isUrdu ? 'کھولیں' : 'Open',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: fontFamily),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleProfessionAction(String action, Profession profession,
      bool isUrdu, String fontFamily, FontWeight fontWeight) {
    switch (action) {
      case 'edit':
        _showEditProfessionDialog(profession, isUrdu);
        break;
      case 'delete':
        _showDeleteProfessionDialog(profession, isUrdu, fontFamily, fontWeight);
        break;
      case 'complete':
      case 'activate':
        _toggleProfessionStatus(profession, isUrdu);
        break;
    }
  }

  void _toggleProfessionStatus(Profession profession, bool isUrdu) {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    final updatedProfession = profession.copyWith(
        isActive: !(profession.isActive ?? true), updatedAt: DateTime.now());
    databaseService.updateProfession(updatedProfession);
    _loadProfessions();
    AppToast.info(
      context,
      isUrdu ? 'پیشہ کی حیثیت تبدیل کر دی گئی' : 'Profession status updated',
    );
  }

  Widget _buildPopupItem(String text, IconData icon, Color color,
      String fontFamily, FontWeight fontWeight) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
                fontWeight: fontWeight)),
      ],
    );
  }

  void _showAddProfessionDialog(BuildContext context, bool isUrdu) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ProfessionDialog(
                  isUrdu: isUrdu,
                  onSave: (name,
                      categories,
                      description,
                      totalProduction,
                      productionUnit,
                      season,
                      targetProduction,
                      budgetLimits,
                      benchmarkCostPerUnit,
                      categoryType,
                      isMaster,
                      parentId) async {
                    final databaseService =
                        Provider.of<DatabaseService>(context, listen: false);
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
                      categoryType: categoryType,
                      isMaster: isMaster,
                      parentId: parentId,
                    );
                    await databaseService.addProfession(profession);
                    _loadProfessions();
                    if (mounted) Navigator.pop(context);
                  },
                )));
  }

  void _showEditProfessionDialog(Profession profession, bool isUrdu) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ProfessionDialog(
                  isUrdu: isUrdu,
                  profession: profession,
                  onSave: (name,
                      categories,
                      description,
                      totalProduction,
                      productionUnit,
                      season,
                      targetProduction,
                      budgetLimits,
                      benchmarkCostPerUnit,
                      categoryType,
                      isMaster,
                      parentId) async {
                    final databaseService =
                        Provider.of<DatabaseService>(context, listen: false);
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
                      categoryType: categoryType,
                      isMaster: isMaster,
                      parentId: parentId,
                    );
                    await databaseService.updateProfession(updatedProfession);
                    _loadProfessions();
                    if (mounted) {
                      Navigator.pop(context);
                      AppToast.success(
                        context,
                        isUrdu
                            ? 'ترمیم محفوظ کر لی گئی'
                            : 'Changes saved successfully',
                      );
                    }
                  },
                )));
  }

  void _showDeleteProfessionDialog(Profession profession, bool isUrdu,
      String fontFamily, FontWeight fontWeight) {
    bool isConfirmed = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isUrdu ? 'پیشہ ڈیلیٹ کریں' : 'Delete Profession',
              style: TextStyle(
                  fontFamily: fontFamily,
                  color: AppTheme.darkColor,
                  fontWeight: fontWeight)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  isUrdu
                      ? 'کیا آپ واقعی "${profession.name}" پیشہ ڈیلیٹ کرنا چاہتے ہیں؟ اس سے منسلک تمام سیزنز اور ٹرانزیکشنز بھی حذف ہو جائیں گی۔'
                      : 'Are you sure you want to delete "${profession.name}"? All its seasons and transactions will be deleted.',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      color: AppTheme.textSecondary,
                      fontWeight: fontWeight)),
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
              text: isUrdu ? 'ڈیلیٹ' : 'Delete',
              onPressed: isConfirmed
                  ? () {
                      final databaseService =
                          Provider.of<DatabaseService>(context, listen: false);
                      databaseService.deleteProfession(profession.id);
                      _loadProfessions();
                      Navigator.pop(context);
                      AppToast.success(
                        context,
                        isUrdu
                            ? 'پیشہ ڈیلیٹ کر دیا گیا'
                            : 'Deleted successfully',
                      );
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
}
