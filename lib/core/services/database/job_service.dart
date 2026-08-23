import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/models/job_bid_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/database/base_service.dart';
import 'package:flutter/foundation.dart';

class JobService extends BaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // 1. نیا کام پوسٹ کریں (گاہک)
  // ====================
  Future<void> postJob(JobPost job) async {
    final user = auth.currentUser;
    if (user == null || job.customerId != user.uid) {
      throw Exception('Only the job owner can post this job');
    }
    if (job.title.trim().isEmpty ||
        job.description.trim().isEmpty ||
        job.location.trim().isEmpty ||
        job.categories.isEmpty) {
      throw ArgumentError(
          'Job title, description, location and category are required');
    }

    // 1. Save locally (Instant)
    await jobsBox?.put(job.id, job);
    notifyListeners();

    // 2. Background Cloud Sync
    if (auth.currentUser != null) {
      firestore
          .collection('jobs')
          .doc(job.id)
          .set(job.toMap())
          .catchError((e) => debugPrint("Offline Sync: Job addition delayed"));
    }
  }

  Future<void> deleteJob(String jobId) async {
    // 1. Delete locally (Instant)
    await jobsBox?.delete(jobId);
    notifyListeners();

    // 2. Background Cloud Delete
    if (auth.currentUser != null) {
      firestore
          .collection('jobs')
          .doc(jobId)
          .delete()
          .catchError((e) => debugPrint("Offline Sync: Job deletion delayed"));
    }
  }

  /// Get Jobs with Local First approach
  List<JobPost> getJobsLocal() {
    return jobsBox?.values.toList() ?? [];
  }

  /// Sync Jobs from Cloud to Local
  Future<void> syncJobsFromCloud() async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'open')
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Clear local open jobs before sync (optional, or merge)
        final openJobIds = snapshot.docs.map((doc) => doc.id).toSet();

        for (var doc in snapshot.docs) {
          final job = JobPost.fromMap(doc.data());
          await jobsBox?.put(job.id, job);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error syncing jobs: $e");
    }
  }

  Future<void> appendJobDetail(String jobId, String newDetail) async {
    final docRef = _firestore.collection('jobs').doc(jobId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    String currentScope = data['detailedScope'] ?? data['description'] ?? '';

    // Just append with a double newline
    final updatedScope = "$currentScope\n\n$newDetail";

    await docRef.update({
      'description':
          updatedScope, // Update main description too so cards show it
      'detailedScope': updatedScope,
      'clarifications': FieldValue.arrayUnion([newDetail]),
    });
  }

  // ============================================================
  // 2. تمام کھلے کام (کاریگر کے لیے) - ریئل ٹائم
  // ====================
  Stream<List<JobPost>> getOpenJobs() {
    return _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => JobPost.fromMap(doc.data())).toList());
  }

  // ============================================================
  // 2b. پیجینیشن کے ساتھ کام لوڈ کریں (ایکس کی طرح)
  // ====================
  Future<QuerySnapshot<Map<String, dynamic>>> getJobsBatch({
    required int limit,
    DocumentSnapshot? startAfter,
    String? category,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (category != null && category != 'all') {
      query = query.where('categories', arrayContains: category);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return await query.get();
  }

  // ============================================================
  // 3. گاہک کے تمام کام
  // ====================
  Stream<List<JobPost>> getCustomerJobs(String customerId) {
    return _firestore
        .collection('jobs')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => JobPost.fromMap(doc.data())).toList());
  }

  // ============================================================
  // 4. بولی لگائیں (کاریگر)
  // ====================
  Future<void> placeBid(JobBid bid) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Unauthorized');
    if (bid.artisanId != user.uid ||
        bid.amount <= 0 ||
        bid.estimatedDays <= 0) {
      throw ArgumentError('Invalid bid');
    }

    final artisanProfile = await ArtisanService().getProfile(user.uid);
    if (artisanProfile == null || !artisanProfile.isActive) {
      throw StateError('An active artisan profile is required to bid');
    }

    final jobDoc = await _firestore.collection('jobs').doc(bid.jobId).get();
    final jobData = jobDoc.data();
    if (!jobDoc.exists || jobData?['status'] != 'open') {
      throw StateError('This job is no longer open');
    }
    if (jobData?['customerId'] == user.uid) {
      throw StateError('A customer cannot bid on their own job');
    }

    await bidsBox?.put("${bid.jobId}_${bid.artisanId}", bid);

    final bidRef = _firestore
        .collection('jobs')
        .doc(bid.jobId)
        .collection('bids')
        .doc(bid.artisanId);

    // Attempt Cloud Sync
    if (auth.currentUser != null) {
      try {
        // Check if bid already exists (for bidCount increment)
        final doc = await bidRef.get();
        final bool exists = doc.exists;

        final batch = _firestore.batch();
        batch.set(bidRef, bid.toMap());

        if (!exists) {
          final jobRef = _firestore.collection('jobs').doc(bid.jobId);
          batch.update(jobRef, {'bidCount': FieldValue.increment(1)});
        }

        await batch.commit();

        // 🆕 بولی کا نوٹیفکیشن مالک کو بھیجیں
        try {
          final jobDoc =
              await _firestore.collection('jobs').doc(bid.jobId).get();
          if (jobDoc.exists) {
            final jobData = jobDoc.data()!;
            final customerId = jobData['customerId'] as String;

            // 🆕 کاریگر کی معلومات حاصل کریں تاکہ نوٹیفکیشن میں دکھائی جا سکیں
            final artisanDoc = await _firestore
                .collection('artisans')
                .doc(bid.artisanId)
                .get();
            String artisanProfession = '';
            String? artisanPhotoUrl = bid.artisanPhotoUrl;
            if (artisanDoc.exists) {
              artisanProfession = artisanDoc.data()?['professionUrdu'] ??
                  artisanDoc.data()?['profession'] ??
                  '';
              artisanPhotoUrl ??= artisanDoc.data()?['profileImage'];
            }

            final jobTitle = jobData['categories'] != null &&
                    (jobData['categories'] as List).isNotEmpty
                ? (jobData['categories'] as List).first as String
                : (jobData['category'] as String? ?? 'کام');

            final notifId = "bid_recv_${DateTime.now().millisecondsSinceEpoch}";

            // 🆕 پیغام میں صرف رقم اور کمنٹ دکھائیں (کیونکہ گاہک کو کام کا پتہ ہوتا ہے)
            String messageBody = 'ریٹ: Rs. ${bid.amount.toStringAsFixed(0)}';
            if (bid.message.isNotEmpty) {
              messageBody += "\n${bid.message}";
            }

            final notification = AppNotification(
              id: notifId,
              title: 'نئی بولی موصول ہوئی!',
              message: messageBody,
              type: NotificationType.general,
              isRead: false,
              timestamp: DateTime.now(),
              data: {
                'type': 'new_bid',
                'jobId': bid.jobId,
                'jobTitle': jobTitle,
                'artisanName': bid.artisanName,
                'artisanPhone': bid.artisanPhone,
                'artisanProfession': artisanProfession,
                'artisanPhotoUrl': artisanPhotoUrl,
                'amount': bid.amount.toString(),
                'bidComment': bid.message,
              },
            );

            await _firestore
                .collection('users')
                .doc(customerId)
                .collection('notifications')
                .doc(notifId)
                .set(notification.toMap());
          }
        } catch (e) {
          debugPrint("Error sending bid notification: $e");
        }
      } catch (e) {
        debugPrint("Bid Cloud Sync failed (offline): $e");
      }
    }
    notifyListeners();
  }

  Future<JobBid?> getArtisanBid(String jobId, String artisanId) async {
    final doc = await _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(artisanId)
        .get();

    if (doc.exists && doc.data() != null) {
      return JobBid.fromMap(doc.data()!);
    }
    return null;
  }

  Stream<bool> hasArtisanBid(String jobId, String artisanId) {
    return _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(artisanId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // ============================================================
  // 5. بولیوں کی لسٹ (گاہک کے لیے)
  // ====================
  Stream<List<JobBid>> getJobBids(String jobId) {
    return _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => JobBid.fromMap(doc.data())).toList());
  }

  // ============================================================
  // 6. بہترین بولی منتخب کریں (گاہک)
  // ====================
  Future<void> selectBid(String jobId, String bidId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('Unauthorized');

    try {
      final jobRef = _firestore.collection('jobs').doc(jobId);
      final bidRef = jobRef.collection('bids').doc(bidId);
      final jobSnapshot = await jobRef.get();
      final bidSnapshot = await bidRef.get();
      final jobData = jobSnapshot.data();
      final bidData = bidSnapshot.data();

      if (!jobSnapshot.exists || jobData?['customerId'] != user.uid) {
        throw StateError('Only the job owner can accept a bid');
      }
      if (jobData?['status'] != 'open') {
        throw StateError('This job is no longer open');
      }
      if (!bidSnapshot.exists || bidData?['status'] != 'pending') {
        throw StateError('This bid is no longer available');
      }
      if (bidData?['artisanId'] == user.uid) {
        throw StateError('You cannot hire yourself');
      }

      // 1. Update the accepted bid status
      await bidRef.update({'status': 'accepted'});

      // 2. Reject all other pending bids
      final bids = await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = _firestore.batch();
      for (var doc in bids.docs) {
        batch.update(doc.reference, {'status': 'rejected'});
      }
      await batch.commit();

      // 3. Update job status to in_progress
      await jobRef.update({
        'selectedBidId': bidId,
        'status': 'in_progress',
      });

      // 4. Create an ArtisanWorkOrder so the artisan sees it in their dashboard
      final bidDoc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .doc(bidId)
          .get();
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();

      if (bidDoc.exists && jobDoc.exists) {
        final bid = JobBid.fromMap(bidDoc.data()!);
        final job = JobPost.fromMap(jobDoc.data()!);

        final orderId = "order_${DateTime.now().millisecondsSinceEpoch}";

        // Construct detailed locked scope including exclusions in Urdu/English
        String fullScope =
            bid.proposedScope ?? job.detailedScope ?? job.description;
        if (job.exclusions != null && job.exclusions!.isNotEmpty) {
          fullScope +=
              "\n\n${job.exclusions!.contains(RegExp(r'[^\x00-\x7F]')) ? 'اس کام میں شامل نہیں ہے:' : 'NOT INCLUDED:'}\n${job.exclusions}";
        }

        final workOrder = ArtisanWorkOrder(
          id: orderId,
          artisanId: bid.artisanId,
          customerId: job.customerId,
          customerName: job.customerName,
          customerPhone: job.customerPhone,
          workDescription: job.description,
          status: 'confirmed', // Accepted bid means confirmed work
          createdAt: DateTime.now(),
          amount: bid.amount,
          location: job.location,
          artisanAgreed: true,
          customerAgreed: true,
          customerAcceptedTerms: true,
          artisanAcceptedTerms: true,
          agreedAt: DateTime.now(),
          lockedScope:
              fullScope, // Lock the agreed full scope including exclusions
          contractTerms: "Legal Agreement / قانونی معاہدہ",
        );

        await _firestore
            .collection('artisans')
            .doc(bid.artisanId)
            .collection('work_orders')
            .doc(orderId)
            .set(workOrder.toMap());

        // 🆕 لوکل ڈیٹا بیس میں بھی محفوظ کریں تاکہ فوری نظر آئے
        await workOrdersBox?.put(orderId, workOrder);

        // 🆕 کاریگر کو نوٹیفکیشن بھیجیں کہ اس کی بولی قبول ہو گئی ہے
        final notifId = "bid_acc_${DateTime.now().millisecondsSinceEpoch}";
        final notification = AppNotification(
          id: notifId,
          title: 'مبارک ہو! ڈیل فائنل ہو گئی',
          message:
              'آپ کی "${job.categories.isNotEmpty ? job.categories.first : ''}" کے کام پر لگائی گئی بولی قبول کر لی گئی ہے۔ کام شروع کرنے کے لیے گاہک سے رابطہ کریں۔',
          type: NotificationType.general,
          isRead: false,
          timestamp: DateTime.now(),
          data: {
            'type': 'bid_accepted',
            'jobId': jobId,
            'orderId': orderId,
            'customerUid': job.customerId, // ضروری ہے چیٹ کے لیے
            'customerName': job.customerName,
          },
        );

        await _firestore
            .collection('users')
            .doc(bid.artisanId)
            .collection('notifications')
            .doc(notifId)
            .set(notification.toMap());
      }
      // Update local state only after the cloud write succeeds.
      final localJob = jobsBox?.get(jobId);
      if (localJob != null) {
        await jobsBox?.put(
          jobId,
          localJob.copyWith(status: 'in_progress', selectedBidId: bidId),
        );
      }
    } catch (e) {
      debugPrint("Error selecting bid: $e");
      rethrow;
    }
    notifyListeners();
  }
}
