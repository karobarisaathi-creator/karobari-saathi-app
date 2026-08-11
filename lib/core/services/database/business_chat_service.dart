// lib/features/business_chat/services/business_chat_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:account_app/core/services/database/base_service.dart';
import 'package:account_app/core/models/business_chat_model.dart';

class BusinessChatService extends BaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get currentUserId => auth.currentUser?.uid ?? '';

  // ============================================================
  // 1. چیٹ روم آئی ڈی
  // ============================================================

  String getChatRoomId(String otherUserId) {
    if (currentUserId.isEmpty || otherUserId.isEmpty) {
      throw Exception('User IDs required');
    }
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    return ids.join('_');
  }

  // ============================================================
  // 2. میسج بھیجیں
  // ============================================================

  Future<void> sendMessage({
    required String receiverId,
    required String message,
    String messageType = 'text',
    String? fileUrl,
    String? fileName,
    String? fileSize,
    String? orderId,
  }) async {
    if (message.trim().isEmpty && fileUrl == null) return;

    final String chatRoomId = getChatRoomId(receiverId);
    final timestamp = FieldValue.serverTimestamp();

    final msgData = {
      'senderId': currentUserId,
      'receiverId': receiverId,
      'message': message.trim(),
      'messageType': messageType,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'isRead': false,
      'isDelivered': true,
      'timestamp': timestamp,
      'orderId': orderId,
    };

    // میسج شامل کریں
    await firestore
        .collection('business_chats')
        .doc(chatRoomId)
        .collection('messages')
        .add(msgData);

    // چیٹ روم اپ ڈیٹ کریں
    await firestore.collection('business_chats').doc(chatRoomId).set({
      'participants': [currentUserId, receiverId],
      'lastMessage': message.trim().isNotEmpty ? message.trim() : (fileUrl != null ? '📎 فائل' : ''),
      'lastMessageTime': timestamp,
      'lastSenderId': currentUserId,
      'unreadCount_$receiverId': FieldValue.increment(1),
      'updatedAt': timestamp,
    }, SetOptions(merge: true));
  }

  // ============================================================
  // 3. فائل اپ لوڈ کریں
  // ============================================================

  Future<Map<String, String>> uploadFile(File file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = _storage.ref().child('chat_files').child(fileName);

      // کمپریس کریں اگر تصویر ہے
      final fileSize = await file.length();
      final isImage = ['.jpg', '.jpeg', '.png', '.gif'].any((ext) => file.path.toLowerCase().endsWith(ext));

      String uploadPath = file.path;
      if (isImage && fileSize > 200000) {
        // تصویر کو کمپریس کریں (یہاں ImageUtils استعمال کریں)
        // uploadPath = await ImageUtils.compressImage(file, quality: 70);
      }

      await ref.putFile(File(uploadPath));
      final url = await ref.getDownloadURL();

      return {
        'url': url,
        'name': file.path.split('/').last,
        'size': _formatFileSize(fileSize),
        'type': isImage ? 'image' : 'file',
      };
    } catch (e) {
      throw Exception('File upload failed: $e');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  // ============================================================
  // 4. میسجز حاصل کریں
  // ============================================================

  Stream<List<BusinessChatMessage>> getMessages(String otherUserId) {
    final String chatRoomId = getChatRoomId(otherUserId);
    return firestore
        .collection('business_chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BusinessChatMessage.fromMap({
      ...doc.data(),
      'id': doc.id,
    }))
        .toList());
  }

  // ============================================================
  // 5. چیٹ رومز حاصل کریں
  // ============================================================

  Stream<List<BusinessChatRoom>> getChatRooms() {
    return firestore
        .collection('business_chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BusinessChatRoom.fromMap({
      ...doc.data(),
      'id': doc.id,
    }))
        .toList());
  }

  // ============================================================
  // 6. میسج پڑھا ہوا مارک کریں
  // ============================================================

  Future<void> markAsRead(String otherUserId) async {
    final String chatRoomId = getChatRoomId(otherUserId);

    final messages = await firestore
        .collection('business_chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in messages.docs) {
      await doc.reference.update({'isRead': true});
    }

    await firestore.collection('business_chats').doc(chatRoomId).update({
      'unreadCount_$currentUserId': 0,
    });
  }

  // ============================================================
  // 7. چیٹ روم ڈیلیٹ کریں
  // ============================================================

  Future<void> deleteChatRoom(String otherUserId) async {
    final String chatRoomId = getChatRoomId(otherUserId);
    final messages = await firestore
        .collection('business_chats')
        .doc(chatRoomId)
        .collection('messages')
        .get();

    if (messages.docs.isNotEmpty) {
      final batch = firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await firestore.collection('business_chats').doc(chatRoomId).delete();
  }

  // ============================================================
  // 8. کوئیک ریپلائز (پہلے سے طے شدہ)
  // ============================================================

  static List<String> getQuickReplies() {
    return [
      'شکریہ! میں جلد جواب دوں گا۔',
      'کیا آپ کوئی اور معلومات چاہتے ہیں؟',
      'براہ کرم اپنا آرڈر نمبر شیئر کریں۔',
      'کیا قیمت میں کمی ہو سکتی ہے؟',
      'کیا آپ ڈیلیوری کرتے ہیں؟',
      'مجھے آپ کے کام کی تفصیل چاہیے۔',
      'کیا آپ کل دستیاب ہیں؟',
      'برائے مہربانی تصویر بھیجیں۔',
      'آپ کا کیا مشورہ ہے؟',
      'شکریہ! بہت اچھا کام کیا ہے۔',
    ];
  }
}