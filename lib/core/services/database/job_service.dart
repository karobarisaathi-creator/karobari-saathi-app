import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/models/job_bid_model.dart';
import 'package:account_app/core/services/database/base_service.dart';

class JobService extends BaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // 1. نیا کام پوسٹ کریں (گاہک)
  // ====================
  Future<void> postJob(JobPost job) async {
    await _firestore.collection('jobs').doc(job.id).set(job.toMap());
  }

  Future<void> deleteJob(String jobId) async {
    await _firestore.collection('jobs').doc(jobId).delete();
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
        .map((snapshot) => snapshot.docs
            .map((doc) => JobPost.fromMap(doc.data()))
            .toList());
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
      query = query.where('category', isEqualTo: category);
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
        .map((snapshot) => snapshot.docs
            .map((doc) => JobPost.fromMap(doc.data()))
            .toList());
  }

  // ============================================================
  // 4. بولی لگائیں (کاریگر)
  // ====================
  Future<void> placeBid(JobBid bid) async {
    final bidRef = _firestore.collection('jobs').doc(bid.jobId).collection('bids').doc(bid.artisanId);
    
    // Check if bid already exists
    final doc = await bidRef.get();
    final bool exists = doc.exists;

    final batch = _firestore.batch();
    batch.set(bidRef, bid.toMap());

    if (!exists) {
      final jobRef = _firestore.collection('jobs').doc(bid.jobId);
      batch.update(jobRef, {'bidCount': FieldValue.increment(1)});
    }

    await batch.commit();
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
        .map((snapshot) => snapshot.docs
            .map((doc) => JobBid.fromMap(doc.data()))
            .toList());
  }

  // ============================================================
  // 6. بہترین بولی منتخب کریں (گاہک)
  // ====================
  Future<void> selectBid(String jobId, String bidId) async {
    await _firestore.collection('jobs').doc(jobId).collection('bids').doc(bidId).update({'status': 'accepted'});

    final bids = await _firestore.collection('jobs').doc(jobId).collection('bids').where('status', isEqualTo: 'pending').get();

    final batch = _firestore.batch();
    for (var doc in bids.docs) {
      batch.update(doc.reference, {'status': 'rejected'});
    }
    await batch.commit();

    await _firestore.collection('jobs').doc(jobId).update({
      'selectedBidId': bidId,
      'status': 'in_progress',
    });
  }
}
