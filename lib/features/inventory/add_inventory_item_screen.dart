import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_filter_chip.dart';
import 'package:account_app/core/widgets/image_grid_viewer.dart';
import 'widgets/mobile_sell_form.dart';
import 'widgets/vehicle_sell_form.dart';
import 'widgets/electronics_sell_form.dart';
import 'widgets/clothing_sell_form.dart';
import 'widgets/furniture_sell_form.dart';
import 'widgets/real_estate_sell_form.dart';
import 'widgets/livestock_sell_form.dart';
import 'widgets/agriculture_sell_form.dart';
import 'widgets/food_sell_form.dart';
import 'widgets/medical_sell_form.dart';
import 'widgets/stationery_sell_form.dart';
import 'widgets/services_sell_form.dart';
import 'widgets/hardware_sell_form.dart';
import 'widgets/construction_sell_form.dart';
import 'widgets/transport_sell_form.dart';
import 'widgets/raw_material_sell_form.dart';
import 'widgets/assets_sell_form.dart';
import 'widgets/other_sell_form.dart';
import 'widgets/general_sell_form.dart';

class AddInventoryItemScreen extends StatefulWidget {
  final InventoryItem? itemToEdit;
  final String? initialCategory;

  const AddInventoryItemScreen({super.key, this.itemToEdit, this.initialCategory});

  @override
  State<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends State<AddInventoryItemScreen> {
  String? _selectedCategory;
  List<String> _currentImages = [];
  Map<String, dynamic> _formData = {};
  
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _commonDescController = TextEditingController();
  bool _isNegotiable = false;
  bool _isFetchingLocation = false;
  
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  final List<AppCategory> _categories = AppFilterChip.productCategories;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.itemToEdit?.category ?? widget.initialCategory ?? 'general';
    _currentImages = List.from(widget.itemToEdit?.imagePaths ?? []);
    _locationController.text = widget.itemToEdit?.location ?? '';
    _isNegotiable = widget.itemToEdit?.isNegotiable ?? false;
    _commonDescController.text = widget.itemToEdit?.description ?? '';
    
    if (widget.itemToEdit != null) {
      _formData = widget.itemToEdit!.toMap();
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _commonDescController.dispose();
    super.dispose();
  }

  Future<void> _pickImages(ImageSource source, bool isUrdu) async {
    if (_currentImages.length >= 5) return;
    final pickedImages = source == ImageSource.gallery ? await _picker.pickMultiImage(imageQuality: 50) : null;
    XFile? camImage;
    if (source == ImageSource.camera) camImage = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    final List<XFile> imagesToProcess = pickedImages ?? (camImage != null ? [camImage] : []);
    
    if (imagesToProcess.isNotEmpty) {
      for (var img in imagesToProcess) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: img.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [AndroidUiSettings(toolbarTitle: isUrdu ? 'تصویر تراشیں' : 'Crop Image', toolbarColor: AppTheme.darkColor, toolbarWidgetColor: Colors.white)],
        );
        if (croppedFile != null) {
          final directory = await getApplicationDocumentsDirectory();
          final fileName = 'item_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final permanentFile = await File(croppedFile.path).copy('${directory.path}/$fileName');
          setState(() => _currentImages.add(permanentFile.path));
        }
      }
    }
  }

  void _showImageSourceSheet(bool isUrdu, String fontFamily) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(PhosphorIcons.camera(), color: AppTheme.themeColor),
              title: Text(isUrdu ? 'کیمرہ' : 'Camera', style: TextStyle(fontFamily: fontFamily, fontSize: isUrdu ? 17 : 14)),
              onTap: () { Navigator.pop(context); _pickImages(ImageSource.camera, isUrdu); },
            ),
            ListTile(
              leading: Icon(PhosphorIcons.image(), color: AppTheme.themeColor),
              title: Text(isUrdu ? 'گیلری' : 'Gallery', style: TextStyle(fontFamily: fontFamily, fontSize: isUrdu ? 17 : 14)),
              onTap: () { Navigator.pop(context); _pickImages(ImageSource.gallery, isUrdu); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks[0];
        setState(() => _locationController.text = "${p.locality}, ${p.subLocality}");
      }
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _handleSave() async {
    if (_currentImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add images')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      List<String> finalImagePaths = [];
      for (String path in _currentImages) {
        if (path.startsWith('http')) {
          finalImagePaths.add(path);
        } else {
          final ref = FirebaseStorage.instance.ref().child('inventory_images').child('${user?.uid}_${DateTime.now().millisecondsSinceEpoch}_${finalImagePaths.length}.jpg');
          await ref.putFile(File(path));
          finalImagePaths.add(await ref.getDownloadURL());
        }
      }
      
      final newItem = InventoryItem(
        id: widget.itemToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _formData['model'] ?? _formData['name'] ?? _formData['title'] ?? 'Untitled Item',
        unit: _formData['unit'] ?? _formData['areaUnit'] ?? 'pcs',
        defaultRate: double.tryParse(_formData['price']?.toString() ?? '0') ?? 0,
        description: _commonDescController.text,
        imagePaths: finalImagePaths,
        createdAt: widget.itemToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        accountId: user?.uid,
        category: _selectedCategory,
        brand: _formData['brand'] ?? '',
        condition: _formData['condition'] ?? 'New',
        location: _locationController.text.isNotEmpty ? _locationController.text : (_formData['location'] ?? _formData['registration'] ?? 'Pakistan'),
        isNegotiable: _isNegotiable,
        sku: _formData['serial'] ?? _formData['sku'],
        
        // MOBILE
        ram: _formData['ram'], 
        storage: _formData['storage'],
        processor: _formData['processor'],
        ptaStatus: _formData['ptaStatus'],
        batteryHealth: _formData['batteryHealth'],
        screenCondition: _formData['screenCondition'],
        bodyCondition: _formData['bodyCondition'],
        accessories: _formData['accessories'],
        
        // VEHICLE
        engine: _formData['engine'],
        mileage: _formData['mileage'],
        fuelType: _formData['fuelType'],
        transmission: _formData['transmission'],
        registration: _formData['registration'],
        accidentHistory: _formData['accidentHistory'],
        ownerCount: _formData['ownerCount'],
        
        // REAL ESTATE
        area: _formData['area'] != null ? "${_formData['area']} ${_formData['areaUnit'] ?? ''}" : null,
        bedrooms: _formData['bedrooms'],
        bathrooms: _formData['bathrooms'],
        propertyType: _formData['propertyType'] ?? _formData['purpose'],
        
        // LIVESTOCK
        breed: _formData['breed'],
        age: _formData['age'],
        weight: _formData['weight'],
        milkCapacity: _formData['milk'],
        vaccination: _formData['vaccinated'],
        
        // ELECTRONICS
        model: _formData['model'],
        power: _formData['power'],
        warrantyType: _formData['warrantyType'] ?? _formData['warrantyPeriod'],
        
        // CLOTHING
        size: _formData['size'],
        fabric: _formData['fabric'],
        
        // FURNITURE
        material: _formData['material'],
        dimensions: _formData['dimensions'],
        assembly: _formData['assembly'],
        
        // AGRICULTURE
        cropType: _formData['productType'],
        season: _formData['season'],
        quality: _formData['quality'],
        
        // FOOD
        foodWeight: _formData['weight'],
        expiryDate: _formData['expiry'],
        storageType: _formData['storageType'],
        halal: _formData['isHalal'],
        
        // MEDICAL
        strength: _formData['strength'],
        medicineQuantity: _formData['quantity'],
        prescriptionRequired: _formData['prescriptionRequired'],
        
        // STATIONERY
        stationeryMaterial: _formData['material'],
        stationerySize: _formData['size'],
        
        // SERVICES
        serviceType: _formData['serviceType'],
        experience: _formData['experience'] ?? _formData['experienceLevel'],
        availability: _formData['availability'],
        
        // HARDWARE
        hardwareMaterial: _formData['material'],
        hardwareSize: _formData['size'],
        
        // CONSTRUCTION
        grade: _formData['grade'],
        constructionUnit: _formData['unit'],
        
        // TRANSPORT
        capacity: _formData['capacity'],
        routes: _formData['routes'],
        
        // RAW MATERIAL
        origin: _formData['origin'],
        specifications: _formData['specification'] ?? _formData['specs'],
        
        // ASSETS
        assetModel: _formData['model'],
        serialNumber: _formData['serial'],
        depreciation: _formData['depreciation'],
      );

      if (widget.itemToEdit == null) { await dbService.addInventoryItem(newItem); } else { await dbService.updateInventoryItem(newItem); }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Save error: $e");
    } finally { if (mounted) setState(() => _isUploading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: CustomAppBar(title: isUrdu ? 'اشتہار پوسٹ کریں' : 'Post Ad'),
      body: _isUploading ? const Center(child: CircularProgressIndicator(color: AppTheme.themeColor))
        : Column(children: [
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
              _buildCategoryHeader(isUrdu, fontFamily),
              const SizedBox(height: 16),
              _buildFormCard(isUrdu: isUrdu, title: isUrdu ? 'تصاویر' : 'Media', icon: PhosphorIcons.image(), child: _buildImageUploader(isUrdu, fontFamily)),
              const SizedBox(height: 16),
              _buildCategorySpecificForm(isUrdu, fontFamily),
              const SizedBox(height: 16),
              _buildCommonFields(isUrdu, fontFamily),
              const SizedBox(height: 100),
            ]))),
            _buildSaveButton(isUrdu, fontFamily),
          ]),
    );
  }

  Widget _buildCommonFields(bool isUrdu, String fontFamily) {
    return _buildFormCard(
      isUrdu: isUrdu,
      title: isUrdu ? 'دیگر معلومات' : 'Common Details',
      icon: PhosphorIcons.info(),
      child: Column(
        children: [
          _buildTextField(
            controller: _locationController,
            label: isUrdu ? 'لوکیشن (شہر / علاقہ)' : 'Location (City / Area)',
            hint: 'Lahore, Karachi...',
            icon: PhosphorIcons.mapPin(),
            fontFamily: fontFamily,
            isUrdu: isUrdu,
            suffix: IconButton(
              icon: _isFetchingLocation ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.my_location, color: AppTheme.themeColor, size: 18),
              onPressed: _getCurrentLocation,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [Icon(PhosphorIcons.tag(), size: 18, color: AppTheme.themeColor), const SizedBox(width: 12), Text(isUrdu ? 'قیمت میں کمی بیشی ہو سکتی ہے' : 'Price is Negotiable', style: TextStyle(fontFamily: isUrdu ? fontFamily : '', fontSize: isUrdu ? 15 : 12))]),
                Switch(value: _isNegotiable, onChanged: (v) => setState(() => _isNegotiable = v), activeThumbColor: AppTheme.themeColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _commonDescController,
            label: isUrdu ? 'مزید تفصیل' : 'Extra Description',
            hint: isUrdu ? 'آئٹم کے بارے میں مزید بتائیں...' : 'Tell more about the item...',
            icon: PhosphorIcons.article(),
            fontFamily: fontFamily,
            isUrdu: isUrdu,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, required IconData icon, int maxLines = 1, required String fontFamily, required bool isUrdu, Widget? suffix}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label, hintText: hint, 
        labelStyle: TextStyle(fontFamily: isUrdu ? fontFamily : '', fontSize: isUrdu ? 15 : 12), 
        prefixIcon: Icon(icon, size: 18, color: AppTheme.themeColor), suffixIcon: suffix,
        filled: true, fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.themeColor)),
      ),
    );
  }

  Widget _buildImageUploader(bool isUrdu, String fontFamily) {
    return GestureDetector(
      onTap: _currentImages.isEmpty ? () => _showImageSourceSheet(isUrdu, fontFamily) : null,
      child: Container(
        height: 180, width: double.infinity,
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: _currentImages.isEmpty 
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(PhosphorIcons.camera(), size: 40, color: Colors.grey[400]), const SizedBox(height: 8), Text(isUrdu ? 'تصاویر شامل کریں' : 'Upload Images', style: TextStyle(fontFamily: fontFamily, color: Colors.grey[500], fontSize: isUrdu ? 16 : 13))]))
            : Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: ImageGridViewer(imagePaths: _currentImages, isReadOnly: false, onRemove: (i) => setState(() => _currentImages.removeAt(i)))), Positioned(right: 8, bottom: 8, child: CircleAvatar(backgroundColor: AppTheme.themeColor, radius: 18, child: IconButton(icon: const Icon(Icons.add_a_photo, color: Colors.white, size: 16), onPressed: () => _showImageSourceSheet(isUrdu, fontFamily))))]),
      ),
    );
  }

  Widget _buildCategorySpecificForm(bool isUrdu, String fontFamily) {
    final save = (Map<String, dynamic> data) => _formData = data;
    switch (_selectedCategory) {
      case 'mobiles': return MobileSellForm(onChanged: save, data: _formData);
      case 'vehicles': return VehicleSellForm(onSave: save, initialData: _formData);
      case 'electronics': return ElectronicsSellForm(onSave: save, initialData: _formData);
      case 'clothing': return ClothingSellForm(onSave: save, initialData: _formData);
      case 'furniture': return FurnitureSellForm(onSave: save, initialData: _formData);
      case 'real_estate': return RealEstateSellForm(onChanged: save, data: _formData);
      case 'livestock': return LivestockSellForm(onChanged: save, data: _formData);
      case 'agriculture': return AgricultureSellForm(onChanged: save, data: _formData);
      case 'food': return FoodSellForm(onChanged: save, data: _formData);
      case 'medical': return MedicalSellForm(onChanged: save, data: _formData);
      case 'stationery': return StationerySellForm(onChanged: save, data: _formData);
      case 'services': return ServicesSellForm(onChanged: save, data: _formData);
      case 'hardware': return HardwareSellForm(onChanged: save, data: _formData);
      case 'construction': return ConstructionSellForm(onChanged: save, data: _formData);
      case 'transport': return TransportSellForm(onChanged: save, data: _formData);
      case 'raw_material': return RawMaterialSellForm(onChanged: save, data: _formData);
      case 'assets': return AssetsSellForm(onChanged: save, data: _formData);
      case 'general': return GeneralSellForm(onChanged: save, data: _formData);
      case 'other': return OtherSellForm(onChanged: save, data: _formData);
      default: return Center(child: Text(isUrdu ? 'اس کیٹیگری کا فارم جلد آ رہا ہے' : 'Form coming soon', style: TextStyle(fontFamily: fontFamily, fontSize: isUrdu ? 16 : 13)));
    }
  }

  Widget _buildCategoryHeader(bool isUrdu, String fontFamily) {
    final cat = _categories.firstWhere((c) => c.id == _selectedCategory, orElse: () => _categories.first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.themeColor.withValues(alpha: 0.2))),
      child: Row(children: [Icon(cat.icon, color: AppTheme.themeColor, size: 20), const SizedBox(width: 12), Text(isUrdu ? cat.labelUr : cat.labelEn, style: TextStyle(fontSize: isUrdu ? 18 : 15, fontWeight: FontWeight.bold, color: AppTheme.themeColor, fontFamily: fontFamily)), const Spacer(), TextButton(onPressed: () => Navigator.pop(context), child: Text(isUrdu ? 'تبدیل کریں' : 'Change', style: TextStyle(fontSize: isUrdu ? 14 : 12, fontFamily: isUrdu ? fontFamily : '')))]),
    );
  }

  Widget _buildFormCard({required String title, required IconData icon, required Widget child, required bool isUrdu}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 20, color: AppTheme.themeColor), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: isUrdu ? 17 : 14, fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontFamily: isUrdu ? 'NooriNastaleeq' : ''))]), const SizedBox(height: 16), child]),
    );
  }

  Widget _buildSaveButton(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
      child: SafeArea(child: SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _handleSave, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isUrdu ? 'پوسٹ کریں' : 'Post Now', style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: isUrdu ? 19 : 16, color: Colors.white))))),
    );
  }
}
