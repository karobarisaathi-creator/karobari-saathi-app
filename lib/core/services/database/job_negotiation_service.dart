import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/models/job_negotiation_model.dart';

class JobNegotiationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<List<NegotiationMessage>> getNegotiationMessages(
      String jobId, String artisanId,
      {bool isDirect = false}) {
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
      
      // Update the main document with the latest message for preview
      final Map<String, dynamic> updates = {
        'workDescription': message,
        'lastMessageSenderId': currentUserId,
        'isLastMessageRead': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (proposedAmount != null) {
        updates['amount'] = proposedAmount;
      }
      batch.update(orderRef, updates);
      
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

  Future<void> deleteNegotiationMessage({
    required String jobId,
    required String artisanId,
    required String messageId,
    bool isDirect = false,
  }) async {
    if (isDirect) {
      await _firestore
          .collection('artisans')
          .doc(artisanId)
          .collection('work_orders')
          .doc(jobId)
          .collection('negotiations')
          .doc(messageId)
          .delete();
    } else {
      await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .doc(artisanId)
          .collection('negotiations')
          .doc(messageId)
          .delete();
    }
  }

  Future<void> markConversationAsRead({
    required String jobId,
    required String artisanId,
    bool isDirect = false,
  }) async {
    final CollectionReference messagesRef;
    if (isDirect) {
      messagesRef = _firestore
          .collection('artisans')
          .doc(artisanId)
          .collection('work_orders')
          .doc(jobId)
          .collection('negotiations');
    } else {
      messagesRef = _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .doc(artisanId)
          .collection('negotiations');
    }

    // We avoid composite index by only filtering isRead on server
    // and filtering senderId locally.
    final querySnapshot = await messagesRef
        .where('isRead', isEqualTo: false)
        .get();

    final unreadDocs = querySnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data != null && data['senderId'] != currentUserId;
    }).toList();

    if (unreadDocs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in unreadDocs) {
      batch.update(doc.reference, {'isRead': true});
    }

    if (isDirect) {
      batch.update(
          _firestore
              .collection('artisans')
              .doc(artisanId)
              .collection('work_orders')
              .doc(jobId),
          {'isLastMessageRead': true});
    }

    await batch.commit();
  }

  Future<void> deleteDirectConversation({
    required String jobId,
    required String artisanId,
  }) async {
    if (currentUserId.isEmpty) throw Exception('Unauthorized');

    final orderRef = _firestore
        .collection('artisans')
        .doc(artisanId)
        .collection('work_orders')
        .doc(jobId);
    final messages = await orderRef.collection('negotiations').get();

    for (var index = 0; index < messages.docs.length; index += 450) {
      final batch = _firestore.batch();
      final end = (index + 450 < messages.docs.length)
          ? index + 450
          : messages.docs.length;
      for (final doc in messages.docs.sublist(index, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
