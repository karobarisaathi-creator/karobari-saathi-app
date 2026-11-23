import 'dart:io';

import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/marketplace/models/marketplace_categories.dart';
import 'package:account_app/features/marketplace/models/marketplace_listing.dart';
import 'package:account_app/features/marketplace/services/marketplace_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MarketplaceListingFormScreen extends StatefulWidget {
  final MarketplaceListing? listing;
  final MarketplaceService? service;

  const MarketplaceListingFormScreen({
    super.key,
    this.listing,
    this.service,
  });

  @override
  State<MarketplaceListingFormScreen> createState() =>
      _MarketplaceListingFormScreenState();
}

class _MarketplaceListingFormScreenState
    extends State<MarketplaceListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _areaController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _remoteImageUrls = [];
  final List<String> _remoteImagePaths = [];
  final List<String> _removedImagePaths = [];

  late final MarketplaceService _service;
  String _category = 'other';
  String _condition = 'used';
  bool _isNegotiable = true;
  bool _phoneShared = false;
  bool _consentError = false;
  bool _isSaving = false;

  bool get _isEditing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MarketplaceService();
    final listing = widget.listing;
    if (listing != null) {
      _titleController.text = listing.title;
      _descriptionController.text = listing.description;
      _priceController.text = listing.price.toString();
      _areaController.text = listing.area;
      _sellerNameController.text = listing.sellerName;
      _phoneController.text = listing.phoneNumber;
      _category =
          marketplaceCategories.any((item) => item.id == listing.category)
              ? listing.category
              : 'other';
      _condition = listing.condition == 'new' ? 'new' : 'used';
      _isNegotiable = listing.isNegotiable;
      _phoneShared = listing.phoneShared;
      _remoteImageUrls.addAll(listing.imageUrls);
      _remoteImagePaths.addAll(listing.imagePaths);
    } else {
      final user = FirebaseAuth.instance.currentUser;
      _sellerNameController.text = user?.displayName ?? '';
      _phoneController.text = user?.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _areaController.dispose();
    _sellerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value, {required String english}) {
    if (value == null || value.trim().isEmpty) {
      final isUrdu = context.read<LanguageService>().isUrdu;
      return isUrdu ? 'یہ خانہ ضروری ہے' : english;
    }
    return null;
  }

  Future<void> _save(bool isUrdu) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_phoneShared) {
      setState(() => _consentError = true);
      return;
    }

    final price = Formatters.tryParseAmount(
      _priceController.text,
      allowDecimals: true,
    );
    if (price == null || price < 0) return;

    setState(() => _isSaving = true);
    try {
      final previous = widget.listing;
      final listing = previous?.copyWith(
            sellerName: _sellerNameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            phoneShared: _phoneShared,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            condition: _condition,
            area: _areaController.text.trim(),
            price: price,
            isNegotiable: _isNegotiable,
            imageUrls: List.of(_remoteImageUrls),
            imagePaths: List.of(_remoteImagePaths),
            updatedAt: DateTime.now(),
          ) ??
          MarketplaceListing(
            id: '',
            ownerId: FirebaseAuth.instance.currentUser?.uid ?? '',
            sellerName: _sellerNameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            phoneShared: _phoneShared,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            condition: _condition,
            area: _areaController.text.trim(),
            price: price,
            isNegotiable: _isNegotiable,
            imageUrls: List.of(_remoteImageUrls),
            imagePaths: List.of(_remoteImagePaths),
            status: 'active',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
      await _service.saveListing(
        listing: listing,
        newImages: List.of(_selectedImages),
        removedImagePaths: List.of(_removedImagePaths),
      );
      if (!mounted) return;
      AppToast.success(
        context,
        isUrdu
            ? (_isEditing ? 'اشتہار اپ ڈیٹ ہوگیا' : 'اشتہار شائع ہوگیا')
            : (_isEditing ? 'Listing updated' : 'Listing published'),
      );
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'marketplace listing form',
          context: ErrorDescription('while saving a listing'),
        ),
      );
      if (mounted) {
        AppToast.error(
          context,
          isUrdu
              ? 'اشتہار محفوظ نہیں ہوسکا، دوبارہ کوشش کریں'
              : 'Could not save the listing. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isUrdu,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? fontFamily,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        color: AppTheme.darkColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: fontFamily, color: AppTheme.textSecondary),
        hintText: hint,
        hintStyle: TextStyle(fontFamily: fontFamily),
        prefixIcon: Icon(icon, color: AppTheme.themeColor, size: 20),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
    String? fontFamily,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: fontFamily, color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.themeColor, size: 20),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = context.watch<LanguageService>().isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final color = AppTheme.themeColor;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ScreenAppBar(
        title: isUrdu
            ? (_isEditing ? 'اشتہار میں ترمیم' : 'چیز فروخت کریں')
            : (_isEditing ? 'Edit Listing' : 'Sell an Item'),
        isUrdu: isUrdu,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: UrduAwareText(
                isUrdu
                    ? 'خریدار سے رابطہ، ادائیگی اور ڈیلیوری آپس میں طے ہوگی؛ یہ ایپ ادائیگی وصول نہیں کرتی۔'
                    : 'Buyers and sellers arrange contact, payment, and delivery directly. This app does not collect payment.',
                style: TextStyle(fontFamily: fontFamily, fontSize: 13),
              ),
            ),
            const SizedBox(height: 18),
            ImageSelectorField(
              label: isUrdu ? 'تصاویر (زیادہ سے زیادہ 5)' : 'Photos (up to 5)',
              selectedFiles: _selectedImages,
              remoteUrls: _remoteImageUrls,
              maxTotal: 5,
              isVertical: true,
              onFilesChanged: (files) {
                setState(() {
                  _selectedImages
                    ..clear()
                    ..addAll(files);
                });
              },
              onRemoteRemoved: (index) {
                setState(() {
                  _removedImagePaths.add(_remoteImagePaths.removeAt(index));
                  _remoteImageUrls.removeAt(index);
                });
              },
            ),
            const SizedBox(height: 18),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFD1D5DB), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.darkColor.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildField(
                    controller: _titleController,
                    label: isUrdu ? 'چیز کا نام' : 'Item name',
                    icon: PhosphorIcons.tag(),
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    validator: (value) => _requiredText(
                      value,
                      english: 'Enter the item name',
                    ),
                    maxLength: 100,
                  ),
                  const Divider(height: 1),
                  _buildDropdownField(
                    label: isUrdu ? 'قسم' : 'Category',
                    icon: PhosphorIcons.squaresFour(),
                    value: _category,
                    fontFamily: fontFamily,
                    items: marketplaceCategories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.label(isUrdu)),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _category = value);
                          },
                  ),
                  const Divider(height: 1),
                  _buildDropdownField(
                    label: isUrdu ? 'حالت' : 'Condition',
                    icon: PhosphorIcons.sparkle(),
                    value: _condition,
                    fontFamily: fontFamily,
                    items: [
                      DropdownMenuItem(
                        value: 'new',
                        child: Text(isUrdu ? 'نئی' : 'New'),
                      ),
                      DropdownMenuItem(
                        value: 'used',
                        child: Text(isUrdu ? 'استعمال شدہ' : 'Used'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _condition = value);
                          },
                  ),
                  const Divider(height: 1),
                  _buildField(
                    controller: _priceController,
                    label: isUrdu ? 'قیمت (روپے)' : 'Price (PKR)',
                    icon: PhosphorIcons.money(),
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final amount = Formatters.tryParseAmount(
                        value ?? '',
                        allowDecimals: true,
                      );
                      if (amount == null || amount < 0) {
                        return isUrdu ? 'درست قیمت درج کریں' : 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const Divider(height: 1),
                  _buildField(
                    controller: _descriptionController,
                    label: isUrdu ? 'تفصیل' : 'Description',
                    hint: isUrdu
                        ? 'چیز کی حالت یا اہم معلومات لکھیں'
                        : 'Add condition details or other useful information',
                    icon: PhosphorIcons.notePencil(),
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    maxLines: 4,
                    maxLength: 1500,
                  ),
                  const Divider(height: 1),
                  _buildField(
                    controller: _areaController,
                    label: isUrdu ? 'شہر / علاقہ' : 'City / area',
                    icon: PhosphorIcons.mapPin(),
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    validator: (value) => _requiredText(
                      value,
                      english: 'Enter your city or area',
                    ),
                    maxLength: 100,
                  ),
                  const Divider(height: 1),
                  _buildField(
                    controller: _sellerNameController,
                    label: isUrdu ? 'آپ کا نام' : 'Your name',
                    icon: PhosphorIcons.user(),
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    validator: (value) => _requiredText(
                      value,
                      english: 'Enter your name',
                    ),
                    maxLength: 80,
                  ),
                  const Divider(height: 1),
                  _buildField(
                    controller: _phoneController,
                    label: isUrdu ? 'رابطہ فون نمبر' : 'Contact phone number',
                    icon: PhosphorIcons.phone(),
                    isUrdu: isUrdu,
                    fontFamily: fontFamily,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final phone = value?.trim() ?? '';
                      final digits = phone.replaceAll(RegExp(r'\D'), '');
                      if (phone.length < 7 ||
                          phone.length > 30 ||
                          digits.length < 7 ||
                          !RegExp(r'^[+0-9 ()-]+$').hasMatch(phone)) {
                        return isUrdu
                            ? 'درست فون نمبر درج کریں'
                            : 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: UrduAwareText(
                isUrdu ? 'قیمت پر بات ہوسکتی ہے' : 'Price is negotiable',
                style: TextStyle(fontFamily: fontFamily),
              ),
              value: _isNegotiable,
              activeTrackColor: color,
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _isNegotiable = value),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _phoneShared,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _phoneShared = value ?? false;
                        _consentError = false;
                      });
                    },
              title: UrduAwareText(
                isUrdu
                    ? 'میں خریداروں کو یہ فون نمبر دکھانے کی اجازت دیتا/دیتی ہوں'
                    : 'I agree to show this phone number to buyers',
                style: TextStyle(fontFamily: fontFamily, fontSize: 13),
              ),
            ),
            if (_consentError)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  isUrdu
                      ? 'اشتہار شائع کرنے کے لیے فون نمبر دکھانے کی اجازت ضروری ہے'
                      : 'Consent is required to publish a listing with direct contact.',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : () => _save(isUrdu),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_rounded),
                label: Text(
                  isUrdu
                      ? (_isEditing ? 'تبدیلی محفوظ کریں' : 'اشتہار شائع کریں')
                      : (_isEditing ? 'Save changes' : 'Publish listing'),
                  style: TextStyle(fontFamily: fontFamily),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
