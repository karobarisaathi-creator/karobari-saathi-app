// lib/features/artisans/controllers/job_post_controller.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:account_app/core/services/firebase_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/services/location_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/services/logging_service.dart';

enum JobPostStatus { idle, loading, success, error }

class JobPostController extends ChangeNotifier {
  final _logger = LoggingService();
  final JobPost? jobToEdit;
  bool _isDisposed = false;
  
  // Form Controllers
  final TextEditingController titleController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController daysController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController websiteController = TextEditingController();
  final TextEditingController companyController = TextEditingController();
  final List<TextEditingController> detailControllers = [];

  // State Variables
  Set<String> selectedCategories = {};
  List<dynamic> images = []; // File (new) or String (existing URL)
  
  String budgetUnit = 'total';
  String durationUnit = 'days';
  String detailBulletStyle = 'dot'; // 'dot', 'number', 'star'
  
  double? jobLatitude;
  double? jobLongitude;
  
  JobPostStatus postStatus = JobPostStatus.idle;
  String? errorMessage;
  bool isLoading = false;

  JobPostController({this.jobToEdit}) {
    _initialize();
  }

  void _initialize() {
    // شروع میں 1 تفصیل والا خانہ
    addDetailField();
    
    if (jobToEdit != null) {
      _loadJobData();
    }
  }

  void addDetailField() {
    detailControllers.add(TextEditingController());
    notifyListeners();
  }

  void removeDetailField(int index) {
    if (detailControllers.length <= 1) return;
    detailControllers.removeAt(index).dispose();
    notifyListeners();
  }

  void removeDetailFieldByController(TextEditingController controller) {
    final index = detailControllers.indexOf(controller);
    if (index != -1) {
      removeDetailField(index);
    }
  }

  void _loadJobData() {
    final job = jobToEdit!;
    titleController.text = job.title;
    selectedCategories = Set.from(job.categories);
    categoryController.text = selectedCategories.join(', ');
    areaController.text = job.location;
    budgetController.text = job.estimatedBudget?.toStringAsFixed(0) ?? '';
    daysController.text = job.estimatedDays?.toString() ?? '';
    budgetUnit = job.budgetUnit ?? 'total';
    durationUnit = job.durationUnit ?? 'days';
    websiteController.text = job.website ?? '';
    companyController.text = job.companyName ?? '';

    // تفصیلات لوڈ کریں اور اسٹائل پہچانیں
    final detailsText = job.detailedScope ?? job.description;
    final details = detailsText.split('\n');
    
    if (details.isNotEmpty) {
      if (details.first.startsWith('★')) {
        detailBulletStyle = 'star';
      } else if (details.first.startsWith('✓')) {
        detailBulletStyle = 'tick';
      } else if (RegExp(r'^\d+\.').hasMatch(details.first)) {
        detailBulletStyle = 'number';
      } else {
        detailBulletStyle = 'dot';
      }
    }

    // پرانے کنٹرولرز صاف کریں
    for (var c in detailControllers) {
      c.dispose();
    }
    detailControllers.clear();
    
    for (var d in details) {
      // تمام قسم کے نشانات (★, ✓, •, 1.) کو تحریر سے صاف کریں
      final cleanText = d.replaceAll(RegExp(r'^(•|★|✓|\d+\.)\s*'), '').trim();
      if (cleanText.isNotEmpty) {
        detailControllers.add(TextEditingController(text: cleanText));
      }
    }
    if (detailControllers.isEmpty) addDetailField();

    images = List.from(job.images);
    jobLatitude = job.latitude;
    jobLongitude = job.longitude;
  }

  void addImage(File image) {
    if (images.length >= 5) return;
    images.add(image);
    notifyListeners();
  }

  void removeImage(int index) {
    images.removeAt(index);
    notifyListeners();
  }

  void toggleCategory(String categoryId) {
    if (selectedCategories.contains(categoryId)) {
      selectedCategories.remove(categoryId);
    } else {
      selectedCategories.add(categoryId);
    }
    notifyListeners();
  }

  void toggleWholeCategory(List<String> categoryIds) {
    final allSelected = categoryIds.every((id) => selectedCategories.contains(id));
    if (allSelected) {
      // If all are selected, remove all of them
      for (var id in categoryIds) {
        selectedCategories.remove(id);
      }
    } else {
      // If some or none are selected, add all
      selectedCategories.addAll(categoryIds);
    }
    notifyListeners();
  }

  Future<void> getCurrentLocation({String language = 'ur'}) async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      jobLatitude = pos.latitude;
      jobLongitude = pos.longitude;
      
      // Nominatim reverse geocoding for Urdu support
      final address = await LocationService.reverseGeocode(
        pos.latitude, 
        pos.longitude, 
        language: language
      );

      if (address != null) {
        areaController.text = address;
      } else {
        // Fallback to geocoding package if Nominatim fails
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          areaController.text = "${placemarks[0].locality}, ${placemarks[0].subLocality}";
        }
      }
      notifyListeners();
    } catch (e) {
      _logger.error("Location error", e);
      errorMessage = 'Failed to get current location';
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> searchLocations(String query, {String language = 'ur'}) async {
    if (query.length < 3) return [];
    
    try {
      return await LocationService.searchLocations(query, language: language);
    } catch (e) {
      _logger.error("Location search error", e);
      return [];
    }
  }

  void onLocationChanged(String value) {
    areaController.text = value;
    if (jobLatitude != null || jobLongitude != null) {
      jobLatitude = null;
      jobLongitude = null;
      notifyListeners();
    }
  }

  List<String> getValidDetails() {
    return detailControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .toList();
  }

  String? validateDetails(bool isUrdu) {
    final validDetails = getValidDetails();
    if (validDetails.isEmpty) {
      return isUrdu 
          ? 'براہ کرم کم از کم ایک تفصیل درج کریں' 
          : 'Please enter at least one detail';
    }
    return null;
  }

  String? validateCategories(bool isUrdu) {
    if (selectedCategories.isEmpty) {
      return isUrdu 
          ? 'براہ کرم کم از کم ایک شعبہ منتخب کریں' 
          : 'Please select at least one category';
    }
    return null;
  }

  void setBulletStyle(String style) {
    detailBulletStyle = style;
    notifyListeners();
  }

  Future<bool> postJob() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      errorMessage = 'Please login first';
      notifyListeners();
      return false;
    }

    postStatus = JobPostStatus.loading;
    isLoading = true;
    notifyListeners();

    try {
      // خودکار لوکیشن سرچ
      if ((jobLatitude == null || jobLongitude == null) &&
          areaController.text.isNotEmpty) {
        await _geocodeAddress();
      }

      // تصاویر اپ لوڈ کریں
      final uploadedImageUrls = await _uploadImages();

      // تفصیلات تیار کریں
      final validDetails = getValidDetails();
      String details = "";
      if (validDetails.length > 1) {
        if (detailBulletStyle == 'star') {
          details = validDetails.map((d) => '★ $d').join('\n');
        } else if (detailBulletStyle == 'tick') {
          details = validDetails.map((d) => '✓ $d').join('\n');
        } else if (detailBulletStyle == 'number') {
          details = List.generate(validDetails.length, (i) => '${i + 1}. ${validDetails[i]}').join('\n');
        } else {
          details = validDetails.map((d) => '• $d').join('\n');
        }
      } else if (validDetails.isNotEmpty) {
        details = validDetails.first;
      }

      // جاب پوسٹ بنائیں
      final job = JobPost(
        id: jobToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: user.uid,
        customerName: user.displayName ?? 'User',
        customerPhone: user.phoneNumber ?? '',
        customerPhotoUrl: user.photoURL,
        title: titleController.text.trim(),
        description: details,
        location: areaController.text.trim(),
        categories: selectedCategories.toList(),
        estimatedBudget: double.tryParse(budgetController.text),
        images: uploadedImageUrls,
        createdAt: jobToEdit?.createdAt ?? DateTime.now(),
        status: jobToEdit?.status ?? 'open',
        detailedScope: details,
        scopeOfWork: details,
        exclusions: null,
        estimatedDays: int.tryParse(daysController.text),
        budgetUnit: budgetUnit,
        durationUnit: durationUnit,
        latitude: jobLatitude,
        longitude: jobLongitude,
        website: websiteController.text.trim().isEmpty ? null : websiteController.text.trim(),
        companyName: companyController.text.trim().isEmpty ? null : companyController.text.trim(),
      );

      await JobService().postJob(job);
      
      postStatus = JobPostStatus.success;
      isLoading = false;
      notifyListeners();
      return true;

    } catch (e, stack) {
      _logger.error("Job post error", e, stack);
      errorMessage = e.toString();
      postStatus = JobPostStatus.error;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _geocodeAddress() async {
    try {
      final locations = await locationFromAddress(areaController.text.trim());
      if (locations.isNotEmpty) {
        jobLatitude = locations.first.latitude;
        jobLongitude = locations.first.longitude;
      }
    } catch (e) {
      _logger.error("Geocoding failed", e);
    }
  }

  Future<List<String>> _uploadImages() async {
    final firebaseService = FirebaseService();
    List<String> uploadedImageUrls = [];
    
    // متوازی اپلوڈنگ
    final uploadFutures = images.map((item) async {
      if (item is File) {
        final fileName = "job_${DateTime.now().millisecondsSinceEpoch}_${images.indexOf(item)}.jpg";
        return await firebaseService.uploadFile(item.path, fileName);
      } else if (item is String) {
        return item; // پہلے سے اپ لوڈ شدہ URL
      }
      return null;
    }).toList();
    
    final results = await Future.wait(uploadFutures);
    uploadedImageUrls = results.whereType<String>().toList();
    
    return uploadedImageUrls;
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    titleController.dispose();
    categoryController.dispose();
    areaController.dispose();
    daysController.dispose();
    budgetController.dispose();
    websiteController.dispose();
    companyController.dispose();
    for (var c in detailControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
