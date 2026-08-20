import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/models/job_negotiation_model.dart';

class JobNegotiationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<List<NegotiationMessage>> getNegotiationMessages(String jobId, String artisanId, {bool isDirect = false}) {
    if (isDirect) {
      return _firestore
          .collection('artisans')
          .doc(artisanId)
          .collection('work_orders')
          .doc(jobId)
          .collection('negotiations')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => NegotiationMessage.fromMap(doc.data()))
              .toList());
    }

    return _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(artisanId)
        .collection('negotiations')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NegotiationMessage.fromMap(doc.data()))
            .toList());
  }

  Future<void> sendNegotiationMessage({
    required String jobId,
    required String artisanId,
    required String message,
    double? proposedAmount,
    bool isDirect = false,
  }) async {
    final docId = DateTime.now().millisecondsSinceEpoch.toString();
    final msg = NegotiationMessage(
      id: docId,
      senderId: currentUserId,
      message: message,
      proposedAmount: proposedAmount,
      timestamp: DateTime.now(),
    );

    if (isDirect) {
      final orderRef = _firestore
          .collection('artisans')
          .doc(artisanId)
          .collection('work_orders')
          .doc(jobId);

      final batch = _firestore.batch();
      batch.set(orderRef.collection('negotiations').doc(docId), msg.toMap());
      if (proposedAmount != null) {
        batch.update(orderRef, {'amount': proposedAmount});
      }
      await batch.commit();
      return;
    }

    final bidRef = _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(artisanId);

    final batch = _firestore.batch();
    
    // 1. Add message
    batch.set(bidRef.collection('negotiations').doc(docId), msg.toMap());

    // 2. If a new amount is proposed, update the bid's main amount
    if (proposedAmount != null) {
      batch.update(bidRef, {'amount': proposedAmount});
    }

    await batch.commit();
  }
}
