import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/screen_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/marketplace/models/marketplace_categories.dart';
import 'package:account_app/features/marketplace/models/marketplace_listing.dart';
import 'package:account_app/features/marketplace/services/marketplace_service.dart';

class MarketplaceListingFormScreen extends StatefulWidget {
  final MarketplaceListing? listing;
  final MarketplaceService? service;

  const MarketplaceListingFormScreen({super.key, this.listing, this.service});

  @override
  State<MarketplaceListingFormScreen> createState() =>
      _MarketplaceListingFormScreenState();
}

class _MarketplaceListingFormScreenState
    extends State<MarketplaceListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = UrduAwareTextEditingController();
  final _descriptionController = UrduAwareTextEditingController();
  final _priceController = UrduAwareTextEditingController();
  final _areaController = UrduAwareTextEditingController();
  final _sellerNameController = UrduAwareTextEditingController();
  final _phoneController = UrduAwareTextEditingController();
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
      _phoneController.text = Formatters.formatPhoneNumber(listing.phoneNumber);
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
      _phoneController.text = Formatters.formatPhoneNumber(
        user?.phoneNumber ?? '',
      );
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required String? fontFamily,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: AppTheme.themeColor),
                ),
                const SizedBox(width: 8),
                UrduAwareText(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.backgroundColor,
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({
    required UrduAwareTextEditingController controller,
    required String label,
    required IconData icon,
    required bool isUrdu,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextDirection? textDirection,
    int maxLines = 1,
    int? maxLength,
    String? fontFamily,
  }) {
    controller.isUrdu = isUrdu;
    final effectiveDirection =
        textDirection ?? (isUrdu ? TextDirection.rtl : TextDirection.ltr);
    final fieldFontFamily =
        keyboardType == TextInputType.phone ? null : fontFamily;
    final labelContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        UrduAwareText(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkColor,
          ),
        ),
        if (maxLength != null) ...[
          const SizedBox(height: 2),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => UrduAwareText(
              '${value.text.runes.length}/$maxLength',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ],
    );
    final inputField = TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType ??
          (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      maxLines: maxLines,
      maxLength: maxLength,
      textDirection: effectiveDirection,
      textAlign: TextAlign.start,
      textAlignVertical:
          maxLines == 1 ? TextAlignVertical.center : TextAlignVertical.top,
      style: TextStyle(
        fontFamily: fieldFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.darkColor,
      ),
      decoration: InputDecoration(
        hint: Align(
          alignment: AlignmentDirectional.centerStart,
          child: UrduAwareText(
            hint ?? (isUrdu ? 'درج کریں...' : 'Enter...'),
            textDirection: effectiveDirection,
            style: TextStyle(
              fontFamily: fieldFontFamily,
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        counterText: '',
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: maxLines > 1
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.themeColor),
                    const SizedBox(width: 10),
                    Expanded(child: labelContent),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 28),
                  child: inputField,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: AppTheme.themeColor),
                const SizedBox(width: 10),
                Flexible(flex: 2, child: labelContent),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: inputField),
              ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.themeColor),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: UrduAwareText(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
                fontFamily: fontFamily,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: UrduAwareText(label),
                isExpanded: true,
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(bool isUrdu, String? fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.squaresFour(),
                  size: 18,
                  color: AppTheme.themeColor,
                ),
                const SizedBox(width: 10),
                UrduAwareText(
                  isUrdu ? 'قسم' : 'Category',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: marketplaceCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = marketplaceCategories[index];
                final selected = _category == category.id;
                return GestureDetector(
                  onTap: _isSaving
                      ? null
                      : () => setState(() => _category = category.id),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.themeColor : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? AppTheme.themeColor
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: UrduAwareText(
                      category.label(isUrdu),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.w600,
                        color: selected ? Colors.white : AppTheme.darkColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
          children: [
            _buildSectionCard(
              title: isUrdu ? 'چیز کی تصاویر' : 'Item Pictures',
              icon: PhosphorIcons.camera(),
              fontFamily: fontFamily,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ImageSelectorField(
                    label: isUrdu
                        ? 'تصاویر منتخب کریں (زیادہ سے زیادہ 5، اختیاری)'
                        : 'Select photos (up to 5, optional)',
                    selectedFiles: _selectedImages,
                    remoteUrls: _remoteImageUrls,
                    maxTotal: 5,
                    onFilesChanged: (files) {
                      setState(() {
                        _selectedImages
                          ..clear()
                          ..addAll(files);
                      });
                    },
                    onRemoteRemoved: (index) {
                      setState(() {
                        _removedImagePaths
                            .add(_remoteImagePaths.removeAt(index));
                        _remoteImageUrls.removeAt(index);
                      });
                    },
                  ),
                ),
              ],
            ),
            _buildSectionCard(
              title: isUrdu ? 'بنیادی معلومات' : 'Basic Information',
              icon: PhosphorIcons.package(),
              fontFamily: fontFamily,
              children: [
                _buildField(
                  controller: _titleController,
                  label: isUrdu ? 'چیز کا نام' : 'Item name',
                  icon: PhosphorIcons.tag(),
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  validator: (value) =>
                      _requiredText(value, english: 'Enter the item name'),
                  maxLength: 100,
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.backgroundColor,
                ),
                _buildCategorySelector(isUrdu, fontFamily),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.backgroundColor,
                ),
                _buildDropdownField(
                  label: isUrdu ? 'حالت' : 'Condition',
                  icon: PhosphorIcons.sparkle(),
                  value: _condition,
                  fontFamily: fontFamily,
                  items: [
                    DropdownMenuItem(
                      value: 'new',
                      child: UrduAwareText(isUrdu ? 'نئی' : 'New'),
                    ),
                    DropdownMenuItem(
                      value: 'used',
                      child: UrduAwareText(isUrdu ? 'استعمال شدہ' : 'Used'),
                    ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _condition = value);
                          }
                        },
                ),
              ],
            ),
            _buildSectionCard(
              title: isUrdu ? 'قیمت اور تفصیل' : 'Price & Details',
              icon: PhosphorIcons.money(),
              fontFamily: fontFamily,
              children: [
                _buildField(
                  controller: _priceController,
                  label: isUrdu ? 'قیمت (روپے)' : 'Price (PKR)',
                  icon: PhosphorIcons.money(),
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textDirection: TextDirection.ltr,
                  validator: (value) {
                    final amount = Formatters.tryParseAmount(
                      value ?? '',
                      allowDecimals: true,
                    );
                    if (amount == null || amount < 0) {
                      return isUrdu
                          ? 'درست قیمت درج کریں'
                          : 'Enter a valid price';
                    }
                    return null;
                  },
                ),
                Material(
                  color: Colors.white,
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: UrduAwareText(
                      isUrdu ? 'قیمت پر بات ہوسکتی ہے' : 'Price is negotiable',
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: _isNegotiable,
                    activeTrackColor: color,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _isNegotiable = value),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.backgroundColor,
                ),
                _buildField(
                  controller: _descriptionController,
                  label: isUrdu ? 'تفصیل' : 'Description',
                  hint: isUrdu
                      ? 'چیز کی حالت یا اہم معلومات لکھیں'
                      : 'Add condition details or other useful information',
                  icon: PhosphorIcons.notePencil(),
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  maxLines: 3,
                  maxLength: 1500,
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.backgroundColor,
                ),
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
              ],
            ),
            _buildSectionCard(
              title: isUrdu ? 'رابطہ معلومات' : 'Contact Information',
              icon: PhosphorIcons.user(),
              fontFamily: fontFamily,
              children: [
                _buildField(
                  controller: _sellerNameController,
                  label: isUrdu ? 'آپ کا نام' : 'Your name',
                  icon: PhosphorIcons.user(),
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  validator: (value) =>
                      _requiredText(value, english: 'Enter your name'),
                  maxLength: 80,
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.backgroundColor,
                ),
                _buildField(
                  controller: _phoneController,
                  label: isUrdu ? 'رابطہ فون نمبر' : 'Contact phone number',
                  icon: PhosphorIcons.phone(),
                  isUrdu: isUrdu,
                  fontFamily: null,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
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
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.backgroundColor,
                ),
                Material(
                  color: Colors.white,
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                ),
                if (_consentError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: UrduAwareText(
                      isUrdu
                          ? 'اشتہار شائع کرنے کے لیے فون نمبر دکھانے کی اجازت ضروری ہے'
                          : 'Consent is required to publish a listing with direct contact.',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
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
            ),
            AppButton(
              onPressed: () => _save(isUrdu),
              icon: Icons.publish_rounded,
              text: isUrdu
                  ? (_isEditing ? 'تبدیلی محفوظ کریں' : 'اشتہار شائع کریں')
                  : (_isEditing ? 'Save changes' : 'Publish listing'),
              loadingText: isUrdu
                  ? (_isEditing
                      ? 'تبدیلی محفوظ ہو رہی ہے...'
                      : 'اشتہار شائع ہو رہا ہے...')
                  : (_isEditing
                      ? 'Saving changes...'
                      : 'Publishing listing...'),
              isLoading: _isSaving,
              isFullWidth: true,
              size: AppButtonSize.large,
            ),
          ],
        ),
      ),
    );
  }
}
