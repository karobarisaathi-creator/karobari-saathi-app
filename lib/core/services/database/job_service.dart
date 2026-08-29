import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
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

    if (auth.currentUser != null) {
      await firestore.collection('jobs').doc(job.id).set(job.toMap());
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
}
