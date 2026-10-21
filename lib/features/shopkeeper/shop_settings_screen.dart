// lib/features/shopkeeper/shop_settings_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/features/order/widgets/shop_card_widget.dart';

class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  // Loading State
  bool _isSaving = false;

  // Switches State
  bool _isOpen = true;
  bool _showOwnerName = true;
  bool _showArea = true;
  bool _showDistance = true;
  bool _showDeliveryInfo = true;
  bool _showRating = true;
  bool _showItemsCount = true;
  bool _showTags = true;

  // Urdu Aware Controllers for Inputs
  late UrduAwareTextEditingController _shopNameCtrl;
  late UrduAwareTextEditingController _ownerNameCtrl;
  late UrduAwareTextEditingController _areaCtrl;
  late UrduAwareTextEditingController _deliveryTimeCtrl;
  late UrduAwareTextEditingController _deliveryFeeCtrl;
  late UrduAwareTextEditingController _minOrderCtrl;
  late UrduAwareTextEditingController _customTagCtrl;

  // Tags selection
  final List<String> _availableTags = [
    'تازہ',
    'مفت ڈیلیوری',
    '24/7',
    'کیش آن ڈیلیوری',
    'آرگینک',
    'خاص رعایت',
    'پریمیم کوالٹی',
    'تازہ ڈیری',
  ];
  final Set<String> _selectedTags = {'تازہ', 'مفت ڈیلیوری', 'کیش آن ڈیلیوری'};

  @override
  void initState() {
    super.initState();
    _shopNameCtrl = UrduAwareTextEditingController(isUrdu: true);
    _ownerNameCtrl = UrduAwareTextEditingController(isUrdu: true);
    _areaCtrl = UrduAwareTextEditingController(isUrdu: true);
    _deliveryTimeCtrl = UrduAwareTextEditingController(isUrdu: true);
    _deliveryFeeCtrl = UrduAwareTextEditingController(isUrdu: true);
    _minOrderCtrl = UrduAwareTextEditingController(isUrdu: true);
    _customTagCtrl = UrduAwareTextEditingController(isUrdu: true);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        FirebaseFirestore.instance.collection('public_shops').doc(user.uid).get(),
      ]);
      if (!mounted) return;
      final profile = results[0].data() ?? {};
      final settings = results[1].data() ?? {};
      setState(() {
        _shopNameCtrl.text =
            (settings['shopName'] ?? profile['shopName'] ?? '').toString();
        _ownerNameCtrl.text =
            (settings['ownerName'] ?? profile['displayName'] ?? '').toString();
        _areaCtrl.text = (settings['businessAddress'] ??
                profile['businessAddress'] ??
                '')
            .toString();
        _deliveryTimeCtrl.text =
            (settings['deliveryTime'] ?? '').toString();
        _deliveryFeeCtrl.text = (settings['deliveryFee'] ?? '').toString();
        _minOrderCtrl.text = (settings['minOrder'] ?? '').toString();
        _isOpen = settings['isOpen'] != false;
        _showOwnerName = settings['showOwnerName'] != false;
        _showArea = settings['showArea'] != false;
        _showDistance = settings['showDistance'] == true;
        _showDeliveryInfo = settings['showDeliveryInfo'] == true;
        _showRating = settings['showRating'] == true;
        _showItemsCount = settings['showItemsCount'] != false;
        _showTags = settings['showTags'] == true;
        final tags = settings['tags'];
        if (tags is List) {
          _selectedTags
            ..clear()
            ..addAll(tags.map((tag) => tag.toString()));
        }
      });
    } catch (error) {
      if (!mounted) return;
      final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
      AppToast.error(
        context,
        isUrdu ? 'شاپ سیٹنگز لوڈ نہیں ہو سکیں: $error' : 'Unable to load shop settings: $error',
      );
    }
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _areaCtrl.dispose();
    _deliveryTimeCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _minOrderCtrl.dispose();
    _customTagCtrl.dispose();
    super.dispose();
  }

  void _addCustomTag() {
    final newTag = _customTagCtrl.text.trim();
    if (newTag.isNotEmpty) {
      setState(() {
        if (!_availableTags.contains(newTag)) {
          _availableTags.add(newTag);
        }
        _selectedTags.add(newTag);
        _customTagCtrl.clear();
      });
      final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
      AppToast.success(
        context,
        isUrdu ? 'نیا کسٹم ٹیگ شامل ہو گیا' : 'Custom tag added',
      );
    }
  }

  void _deleteTag(String tag) {
    setState(() {
      _availableTags.remove(tag);
      _selectedTags.remove(tag);
    });
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    AppToast.info(
      context,
      isUrdu ? 'ٹیگ ختم کر دیا گیا' : 'Tag deleted',
    );
  }

  Shop _getPreviewShop() {
    final stockService = Provider.of<StockService>(context);
    final publicItems = stockService.items
        .where((item) => !item.isArchived)
        .map(
          (item) => ShopItem(
            id: item.id,
            stockItemId: item.id,
            name: item.name,
            nameUrdu: item.nameUrdu,
            description: item.description,
            rate: item.sellingPrice,
            unit: item.unit,
            emoji: '📦',
            category: item.categoryName.isEmpty ? 'عام' : item.categoryName,
            imageUrl: item.imagePath,
            stock: item.trackStock
                ? stockService.calculateCurrentStock(item.id)
                : 1000000000,
            rating: 0,
          ),
        )
        .toList();

    return Shop(
      id: 'preview',
      name: _shopNameCtrl.text.trim().isNotEmpty
          ? _shopNameCtrl.text.trim()
          : 'کریانہ اسٹور',
      logoEmoji: '🛒',
      owner: _showOwnerName ? _ownerNameCtrl.text.trim() : '',
      area: _showArea ? _areaCtrl.text.trim() : '',
      distance: '',
      distanceVal: double.infinity,
      rating: 0,
      reviews: 0,
      deliveryTime: _showDeliveryInfo ? _deliveryTimeCtrl.text.trim() : '',
      timeVal: int.tryParse(
            RegExp(r'\d+')
                    .firstMatch(_deliveryTimeCtrl.text.trim())
                    ?.group(0) ??
                '',
          ) ??
          0,
      minOrder: _showDeliveryInfo ? _minOrderCtrl.text.trim() : '',
      deliveryFee: _showDeliveryInfo ? _deliveryFeeCtrl.text.trim() : '',
      isOpen: _isOpen,
      tags: _showTags ? _selectedTags.toList() : [],
      items: publicItems,
      itemCount: publicItems.length,
      showOwnerName: _showOwnerName,
      showArea: _showArea,
      showDistance: _showDistance,
      showDeliveryInfo: _showDeliveryInfo,
      showRating: _showRating,
      showItemsCount: _showItemsCount,
      showTags: _showTags,
    );
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    if (_shopNameCtrl.text.trim().isEmpty) {
      AppToast.error(
        context,
        isUrdu ? 'دکان کا نام درج کرنا ضروری ہے' : 'Shop name is required',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppToast.error(context, 'Please sign in first');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'shopName': _shopNameCtrl.text.trim(),
        'displayName': _ownerNameCtrl.text.trim(),
        'businessAddress': _areaCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_shopNameCtrl.text.trim().isNotEmpty) {
        final payload = {
          'uid': user.uid,
          'shopName': _shopNameCtrl.text.trim(),
          'ownerName': _ownerNameCtrl.text.trim(),
          'businessAddress': _areaCtrl.text.trim(),
          'displayName': _ownerNameCtrl.text.trim(),
          'isOpen': _isOpen,
          'distance': '',
          'distanceVal': null,
          'deliveryTime': _showDeliveryInfo ? _deliveryTimeCtrl.text.trim() : '',
          'timeVal': int.tryParse(
                RegExp(r'\d+')
                        .firstMatch(_deliveryTimeCtrl.text.trim())
                        ?.group(0) ??
                    '',
              ) ??
              0,
          'minOrder': _showDeliveryInfo ? _minOrderCtrl.text.trim() : '',
          'deliveryFee': _showDeliveryInfo ? _deliveryFeeCtrl.text.trim() : '',
          'tags': _showTags ? _selectedTags.toList() : [],
          'showOwnerName': _showOwnerName,
          'showArea': _showArea,
          'showDistance': _showDistance,
          'showDeliveryInfo': _showDeliveryInfo,
          'showRating': _showRating,
          'showItemsCount': _showItemsCount,
          'showTags': _showTags,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('public_shops')
            .doc(user.uid)
            .set(payload, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('public_shops').doc(user.uid).delete();
      }
      if (!mounted) return;
      await Provider.of<StockService>(context, listen: false).syncPublicCatalog();

      if (!mounted) return;
      setState(() => _isSaving = false);

      AppToast.success(
        context,
        isUrdu
            ? 'شاپ کارڈ کی سیٹنگز کامیابی سے محفوظ ہو گئیں'
            : 'Shop card settings saved successfully',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.error(
        context,
        isUrdu ? 'شاپ سیٹنگز محفوظ نہیں ہو سکی: $error' : 'Unable to save shop settings: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    // Synchronize controller isUrdu property
    _shopNameCtrl.isUrdu = isUrdu;
    _ownerNameCtrl.isUrdu = isUrdu;
    _areaCtrl.isUrdu = isUrdu;
    _deliveryTimeCtrl.isUrdu = isUrdu;
    _deliveryFeeCtrl.isUrdu = isUrdu;
    _minOrderCtrl.isUrdu = isUrdu;
    _customTagCtrl.isUrdu = isUrdu;

    final previewShop = _getPreviewShop();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'شاپ سیٹنگز' : 'Shop Settings',
        backgroundColor: AppTheme.darkColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Preview Section
            _buildSectionHeader(
              icon: PhosphorIcons.eye(),
              title: isUrdu ? 'کارڈ لائیو پریویو' : 'Live Card Preview',
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 10),

            // Live Shop Card Preview Widget
            AbsorbPointer(
              child: ShopCardWidget(
                shop: previewShop,
                onTap: () {},
              ),
            ),

            const SizedBox(height: 20),

            // Section 1: Shop Information Inputs & Visibility
            _buildSectionHeader(
              icon: PhosphorIcons.sliders(),
              title: isUrdu
                  ? 'بنیادی معلومات اور نمائش'
                  : 'Basic Information & Display',
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 10),
            _buildCardContainer([
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _shopNameCtrl,
                      label: isUrdu ? 'دکان کا نام' : 'Shop Name',
                      fontFamily: fontFamily,
                      icon: PhosphorIcons.storefront(),
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _ownerNameCtrl,
                      label: isUrdu ? 'مالک کا نام' : 'Owner Name',
                      fontFamily: fontFamily,
                      icon: PhosphorIcons.user(),
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _areaCtrl,
                      label: isUrdu ? 'علاقہ / پتہ' : 'Area / Location',
                      fontFamily: fontFamily,
                      icon: PhosphorIcons.mapPin(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: isUrdu ? 'دکان کا سٹیٹس (کھلی / بند)' : 'Shop Open / Closed Status',
                subtitle: isUrdu
                    ? 'کارڈ پر دکان کا لائیو سٹیٹس دکھائیں'
                    : 'Display open/closed badge on card',
                value: _isOpen,
                onChanged: (v) => setState(() => _isOpen = v),
                fontFamily: fontFamily,
                icon: PhosphorIcons.storefront(),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: isUrdu ? 'مالک کا نام دکھائیں' : 'Show Owner Name',
                subtitle: isUrdu
                    ? 'پروفائل کارڈ پر مالک کا نام دکھائیں'
                    : 'Display owner name on shop card',
                value: _showOwnerName,
                onChanged: (v) => setState(() => _showOwnerName = v),
                fontFamily: fontFamily,
                icon: PhosphorIcons.user(),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: isUrdu ? 'علاقہ اور پتہ دکھائیں' : 'Show Area & Location',
                subtitle: isUrdu
                    ? 'کارڈ پر دکان کا علاقہ دکھائیں'
                    : 'Display shop area and location',
                value: _showArea,
                onChanged: (v) => setState(() => _showArea = v),
                fontFamily: fontFamily,
                icon: PhosphorIcons.mapPin(),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: isUrdu ? 'فاصلہ (Distance) دکھائیں' : 'Show Distance',
                subtitle: isUrdu
                    ? 'صارف سے دکان کا فاصلہ دکھائیں'
                    : 'Display estimated distance',
                value: _showDistance,
                onChanged: (v) => setState(() => _showDistance = v),
                fontFamily: fontFamily,
                icon: PhosphorIcons.navigationArrow(),
                isLast: true,
              ),
            ]),

            const SizedBox(height: 20),

            // Section 2: Delivery & Service Settings
            _buildSectionHeader(
              icon: PhosphorIcons.truck(),
              title: isUrdu
                  ? 'ڈیلیوری اور سروسز کی ترتیبات'
                  : 'Delivery & Service Settings',
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 10),
            _buildCardContainer([
              _buildSwitchTile(
                title: isUrdu ? 'ڈیلیوری کی معلومات دکھائیں' : 'Show Delivery Info',
                subtitle: isUrdu
                    ? 'وقت، چارجز اور کم از کم آرڈر'
                    : 'Time, fee, and min order',
                value: _showDeliveryInfo,
                onChanged: (v) => setState(() => _showDeliveryInfo = v),
                fontFamily: fontFamily,
                icon: PhosphorIcons.truck(),
              ),
              if (_showDeliveryInfo) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _deliveryTimeCtrl,
                        label: isUrdu ? 'ڈیلیوری کا وقت' : 'Delivery Time',
                        fontFamily: fontFamily,
                        icon: PhosphorIcons.clock(),
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _deliveryFeeCtrl,
                        label: isUrdu ? 'ڈیلیوری فیس / چارجز' : 'Delivery Fee',
                        fontFamily: fontFamily,
                        icon: PhosphorIcons.truck(),
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        controller: _minOrderCtrl,
                        label: isUrdu ? 'کم از کم آرڈر رقم' : 'Minimum Order',
                        fontFamily: fontFamily,
                        icon: PhosphorIcons.money(),
                      ),
                    ],
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 20),

            // Section 3: Ratings & Items Count
            _buildSectionHeader(
              icon: PhosphorIcons.star(),
              title: isUrdu ? 'ریٹنگ اور دستیاب پروڈکٹس' : 'Ratings & Products',
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 10),
            _buildCardContainer([
              _buildSwitchTile(
                title: isUrdu ? 'اسٹار ریٹنگ اور ریویوز دکھائیں' : 'Show Rating & Reviews',
                subtitle: isUrdu
                    ? 'کارڈ پر اسٹار ریٹنگ اور ریویوز دکھائیں'
                    : 'Display star rating and reviews on card',
                value: _showRating,
                onChanged: (v) => setState(() => _showRating = v),
                fontFamily: fontFamily,
                icon: PhosphorIcons.star(),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                title: isUrdu ? 'دستیاب آئٹمز کی تعداد دکھائیں' : 'Show Items Count',
                subtitle: isUrdu
                    ? 'دکان پر دستیاب کل پروڈکٹس کی تعداد'
                    : 'Display available items count on card',
                value: _showItemsCount,
                onChanged: (v) => setState(() => _showItemsCount = v),
                fontFamily: fontFamily,
                icon: PhosphorIcons.package(),
                isLast: true,
              ),
            ]),

            const SizedBox(height: 20),

            // Section 4: Tags & Features (Custom Tags & Delete Options)
            _buildSectionHeader(
              icon: PhosphorIcons.tag(),
              title: isUrdu ? 'خصوصی ٹیگز اور کسٹم ٹیگز' : 'Tags & Custom Tags',
              fontFamily: fontFamily,
            ),
            const SizedBox(height: 10),
            _buildCardContainer([
              _buildSwitchTile(
                title: isUrdu ? 'خصوصی ٹیگز دکھائیں' : 'Show Promotional Tags',
                subtitle: isUrdu
                    ? 'کارڈ پر دکان کی خصوصیات کی فہرست'
                    : 'Display tags on shop card',
                value: _showTags,
                onChanged: (v) => setState(() => _showTags = v),
                fontFamily: fontFamily,
                icon: PhosphorIcons.tag(),
              ),
              if (_showTags) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Custom Tag Input Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _customTagCtrl,
                              label: isUrdu
                                  ? 'نیا کسٹم ٹیگ لکھیں...'
                                  : 'Type custom tag...',
                              fontFamily: fontFamily,
                              icon: PhosphorIcons.tag(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _addCustomTag,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: UrduAwareText(
                              isUrdu ? 'شامل کریں' : 'Add',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tags Input Chips with Delete Button (x)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTags.map((tag) {
                          final isSelected = _selectedTags.contains(tag);
                          return InputChip(
                            selected: isSelected,
                            label: UrduAwareText(
                              tag,
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.darkColor,
                              ),
                            ),
                            selectedColor: AppTheme.themeColor,
                            backgroundColor: const Color(0xFFF5F7FA),
                            checkmarkColor: Colors.white,
                            deleteIcon: Icon(
                              Icons.cancel_rounded,
                              size: 15,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.grey[500],
                            ),
                            onDeleted: () => _deleteTag(tag),
                            onPressed: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedTags.remove(tag);
                                } else {
                                  _selectedTags.add(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 30),

            // Save Settings Button with Spinning Progress Indicator
            AppButton(
              text: isUrdu ? 'سیٹنگز محفوظ کریں' : 'Save Settings',
              onPressed: _saveSettings,
              isLoading: _isSaving,
              isFullWidth: true,
              size: AppButtonSize.large,
              color: AppTheme.darkColor,
              icon: PhosphorIcons.floppyDisk(),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String fontFamily,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.themeColor),
          const SizedBox(width: 8),
          UrduAwareText(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.backgroundColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String fontFamily,
    IconData? icon,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: value
                        ? AppTheme.themeColor.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: value ? AppTheme.themeColor : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UrduAwareText(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkColor,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                    UrduAwareText(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppTheme.themeColor,
                thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Icon(Icons.check, size: 14, color: Colors.white);
                  }
                  return const Icon(Icons.close, size: 14, color: Colors.grey);
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String fontFamily,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: fontFamily,
        color: AppTheme.darkColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          fontFamily: fontFamily,
          color: AppTheme.textSecondary,
        ),
        prefixIcon: Icon(icon, size: 16, color: AppTheme.themeColor),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.themeColor, width: 1.5),
        ),
      ),
    );
  }
}
