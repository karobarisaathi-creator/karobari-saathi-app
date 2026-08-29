import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/features/professions/profession_detail_screen.dart';
import 'package:account_app/features/professions/profession_dialog.dart';
import 'package:account_app/features/professions/profession_seasons_screen.dart';
import 'package:account_app/features/accounts/reports_screen.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';

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
      backgroundColor: AppTheme.backgroundColor,
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
          final professions = databaseService.getMasterProfessions();
          
          if (professions.isEmpty) {
            // Check for legacy/un-migrated professions
            final allProfessions = databaseService.getProfessions();
            if (allProfessions.isNotEmpty && allProfessions.every((p) => !p.isMaster && p.parentId == null)) {
               // Show all if none are marked as master yet (Migration helper)
               return _buildProfessionGrid(allProfessions, isUrdu, fontFamily, fontWeight);
            }

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
            child: _buildProfessionGrid(professions, isUrdu, fontFamily, fontWeight),
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

  Widget _buildProfessionGrid(List<Profession> professions, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: professions.length,
      itemBuilder: (context, index) {
        return _buildProfessionListItem(professions[index], isUrdu, fontFamily, fontWeight);
      },
    );
  }

  Widget _buildProfessionListItem(Profession profession, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    IconData displayIcon = PhosphorIcons.briefcase();
    String? cleanDescription;
    String categoryLabel = '';

    if (profession.description != null) {
      if (profession.description!.startsWith('ICON:')) {
        try {
          final parts = profession.description!.split('|');
          final iconKey = parts[0].substring(5);
          
          final Map<String, dynamic> iconMap = {
            'agriculture': {'icon': PhosphorIcons.tractor(), 'label': 'Agriculture', 'labelUr': 'زراعت'},
            'livestock': {'icon': PhosphorIcons.cow(), 'label': 'Livestock', 'labelUr': 'مال مویشی'},
            'transport': {'icon': PhosphorIcons.truck(), 'label': 'Transport', 'labelUr': 'گاڑی/ٹرک'},
            'shop': {'icon': PhosphorIcons.storefront(), 'label': 'Shop', 'labelUr': 'دکان'},
            'factory': {'icon': PhosphorIcons.factory(), 'label': 'Factory', 'labelUr': 'فیکٹری'},
            'hammer': {'icon': PhosphorIcons.hammer(), 'label': 'Construction', 'labelUr': 'تعمیرات'},
            'land': {'icon': PhosphorIcons.mapPin(), 'label': 'Land', 'labelUr': 'زمین/پلاٹ'},
            'tools': {'icon': PhosphorIcons.wrench(), 'label': 'Services', 'labelUr': 'خدمات'},
            'food': {'icon': PhosphorIcons.cookingPot(), 'label': 'Food', 'labelUr': 'کھانا'},
            'tech': {'icon': PhosphorIcons.cpu(), 'label': 'Tech', 'labelUr': 'ٹیکنالوجی'},
            'finance': {'icon': PhosphorIcons.bank(), 'label': 'Finance', 'labelUr': 'بینک'},
            'cart': {'icon': PhosphorIcons.shoppingCart(), 'label': 'Cart', 'labelUr': 'خریداری'},
          };

          if (iconMap.containsKey(iconKey)) {
            displayIcon = iconMap[iconKey]['icon'];
            categoryLabel = isUrdu ? iconMap[iconKey]['labelUr'] : iconMap[iconKey]['label'];
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
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
                      profession.name,
                      style: TextStyle(
                        color: AppTheme.darkColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                    if (categoryLabel.isNotEmpty)
                      Text(
                        categoryLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.themeColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: fontFamily,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(PhosphorIcons.dotsThreeVertical(), color: AppTheme.textSecondary, size: 28),
                padding: EdgeInsets.zero,
                onSelected: (value) => _handleProfessionAction(value, profession, isUrdu, fontFamily, fontWeight),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: _buildPopupItem(isUrdu ? 'ترمیم' : 'Edit', PhosphorIcons.pencilLine(), AppTheme.themeColor, fontFamily, fontWeight)),
                  PopupMenuItem(value: 'delete', child: _buildPopupItem(isUrdu ? 'حذف' : 'Delete', PhosphorIcons.trash(), AppTheme.expenseColor, fontFamily, fontWeight)),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(PhosphorIcons.calendar(), size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy').format(profession.createdAt),
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  if (profession.isMaster || profession.parentId == null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfessionSeasonsScreen(masterProfession: profession)),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfessionDetailScreen(profession: profession)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isUrdu ? 'کھولیں' : 'Open',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: fontFamily),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleProfessionAction(String action, Profession profession, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    switch (action) {
      case 'edit':
        _showEditProfessionDialog(profession, isUrdu);
        break;
      case 'delete':
        _showDeleteProfessionDialog(profession, isUrdu, fontFamily, fontWeight);
        break;
      case 'reports':
        Navigator.push(context, MaterialPageRoute(builder: (context) => ReportsScreen(selectedProfession: profession)));
        break;
      case 'complete':
      case 'activate':
        _toggleProfessionStatus(profession, isUrdu);
        break;
    }
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

  Widget _buildPopupItem(String text, IconData icon, Color color, String fontFamily, FontWeight fontWeight) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontWeight: fontWeight)),
      ],
    );
  }

  void _showAddProfessionDialog(BuildContext context, bool isUrdu) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfessionDialog(
      isUrdu: isUrdu,
      onSave: (name, categories, description, totalProduction, productionUnit, season, targetProduction, budgetLimits, benchmarkCostPerUnit, isMaster, parentId) async {
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
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfessionDialog(
      isUrdu: isUrdu,
      profession: profession,
      onSave: (name, categories, description, totalProduction, productionUnit, season, targetProduction, budgetLimits, benchmarkCostPerUnit, isMaster, parentId) async {
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
          isMaster: isMaster,
          parentId: parentId,
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

  void _showDeleteProfessionDialog(Profession profession, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    bool isConfirmed = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isUrdu ? 'پیشہ ڈیلیٹ کریں' : 'Delete Profession', 
            style: TextStyle(fontFamily: fontFamily, color: AppTheme.darkColor, fontWeight: fontWeight)
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUrdu 
                  ? 'کیا آپ واقعی "${profession.name}" پیشہ ڈیلیٹ کرنا چاہتے ہیں؟ اس سے منسلک تمام سیزنز اور ٹرانزیکشنز بھی حذف ہو جائیں گی۔' 
                  : 'Are you sure you want to delete "${profession.name}"? All its seasons and transactions will be deleted.', 
                style: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary, fontWeight: fontWeight)
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
              text: isUrdu ? 'ڈیلیٹ' : 'Delete',
              onPressed: isConfirmed ? () {
                final databaseService = Provider.of<DatabaseService>(context, listen: false);
                databaseService.deleteProfession(profession.id);
                _loadProfessions();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isUrdu ? 'پیشہ ڈیلیٹ کر دیا گیا' : 'Deleted successfully'), 
                  backgroundColor: AppTheme.expenseColor, 
                  behavior: SnackBarBehavior.floating
                ));
              } : null,
              color: AppTheme.expenseColor,
              size: AppButtonSize.small,
            ),
          ],
        ),
      ),
    );
  }
}
