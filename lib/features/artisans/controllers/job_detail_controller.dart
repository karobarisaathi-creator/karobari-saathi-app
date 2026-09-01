// lib/features/artisans/controllers/job_detail_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/services/database/job_negotiation_service.dart';
import 'package:account_app/core/services/logging_service.dart';

enum JobDetailStatus { idle, loading, negotiating, success, error }

class JobDetailController extends ChangeNotifier {
  final _logger = LoggingService();
  final JobPost initialJob;
  final ArtisanService _artisanService = ArtisanService();
  final ArtisanWorkOrderService _workOrderService = ArtisanWorkOrderService();
  final JobNegotiationService _negotiationService = JobNegotiationService();
  final JobService _jobService = JobService();
  
  JobPost? _currentJob;
  JobPost? get currentJob => _currentJob;
  
  bool canContact = false;
  bool isOwner = false;
  bool isFavorite = false;
  
  JobDetailStatus status = JobDetailStatus.idle;
  String? errorMessage;
  
  StreamSubscription<DocumentSnapshot>? _jobSubscription;
  StreamSubscription<bool>? _favoriteSubscription;

  JobDetailController({required this.initialJob}) {
    _currentJob = initialJob;
    _initialize();
  }

  Future<void> _initialize() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    isOwner = initialJob.customerId == userId;
    
    // جاب کی لائیو اپڈیٹس سنیں
    _listenToJobUpdates();
    
    // پسندیدہ اسٹیٹس سنیں
    _listenToFavoriteStatus(userId);
    
    // رابطے کی اجازت چیک کریں
    await _checkContactPermission(userId);
    
    notifyListeners();
  }

  void _listenToJobUpdates() {
    _jobSubscription = FirebaseFirestore.instance
        .collection('jobs')
        .doc(initialJob.id)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          _currentJob = JobPost.fromMap(snapshot.data()!);
          notifyListeners();
        }
      },
      onError: (error) {
        _logger.error("Job stream error", error);
      },
    );
  }

  void _listenToFavoriteStatus(String userId) {
    _favoriteSubscription = _artisanService
        .isFavorite(initialJob.customerId)
        .listen(
      (isFav) {
        isFavorite = isFav;
        notifyListeners();
      },
      onError: (error) {
        _logger.error("Favorite stream error", error);
      },
    );
  }

  Future<void> _checkContactPermission(String userId) async {
    try {
      final profile = await _artisanService.getProfile(userId);
      canContact = profile != null && profile.isActive;
      notifyListeners();
    } catch (e) {
      _logger.error("Contact permission check error", e);
    }
  }

  Future<bool> startNegotiation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentJob == null) return false;
    
    status = JobDetailStatus.negotiating;
    notifyListeners();

    try {
      final job = _currentJob!;
      final orderId = 'job_neg_${job.id}';
      
      // موجودہ آرڈر چیک کریں
      final existingOrder = await FirebaseFirestore.instance
          .collection('artisans')
          .doc(user.uid)
          .collection('work_orders')
          .doc(orderId)
          .get();

      if (!existingOrder.exists) {
        // نیا آرڈر بنائیں
        final order = ArtisanWorkOrder(
          id: orderId,
          artisanId: user.uid,
          artisanName: user.displayName ?? 'Artisan',
          customerId: job.customerId,
          customerName: job.customerName,
          customerPhone: '',
          title: job.title,
          workDescription: job.description,
          status: 'negotiating',
          amount: 0.0, // تخمینی بجٹ کو کل رقم میں نہیں ڈالیں گے جب تک کام پکا نہ ہو جائے
          createdAt: DateTime.now(),
          artisanAgreed: true,
        );

        await _workOrderService.addWorkOrder(order);

        // ابتدائی پیغام بھیجیں
        await _negotiationService.sendNegotiationMessage(
          jobId: order.id,
          artisanId: user.uid,
          message: 'Salam! I am interested in your job "${job.title}". Can we discuss this?',
          isDirect: true,
        );
      }

      status = JobDetailStatus.success;
      notifyListeners();
      return true;

    } catch (e, stack) {
      _logger.error("Negotiation error", e, stack);
      errorMessage = e.toString();
      status = JobDetailStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteJob() async {
    if (_currentJob == null) return;
    
    status = JobDetailStatus.loading;
    notifyListeners();
    
    try {
      await _jobService.deleteJob(_currentJob!.id);
      status = JobDetailStatus.success;
      notifyListeners();
    } catch (e) {
      _logger.error("Delete job error", e);
      errorMessage = e.toString();
      status = JobDetailStatus.error;
      notifyListeners();
    }
  }

  Future<void> addClarification(String text) async {
    if (_currentJob == null || text.trim().isEmpty) return;
    
    try {
      await _jobService.appendJobDetail(_currentJob!.id, text.trim());
    } catch (e) {
      _logger.error("Add clarification error", e);
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _favoriteSubscription?.cancel();
    super.dispose();
  }
}
