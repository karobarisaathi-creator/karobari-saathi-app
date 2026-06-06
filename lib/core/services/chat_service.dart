import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/models/chat_model.dart';

class ChatService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send message
  Future<void> sendMessage(
    ChatMessage message,
    String targetPhoneNumber,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('chats')
        .doc(message.chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toMap());

    // Update last message in chat document
    await _firestore.collection('chats').doc(message.chatId).set({
      'lastMessage': message.message,
      'lastMessageTime': message.timestamp,
      'lastSenderId': message.senderId,
      'participants': [user.uid, targetPhoneNumber],
      'updatedAt': DateTime.now(),
    }, SetOptions(merge: true));

    // Send push notification to target user
    await _sendPushNotification(message, targetPhoneNumber);
    notifyListeners();
  }

  // Get chat messages
  Stream<List<ChatMessage>> getChatMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<List<ChatMessage>> getChatMessages(String chatId) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList();
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
    notifyListeners();
  }

  // Get all chats for current user
  Stream<List<Chat>> getChatsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Chat.fromMap(doc.data())).toList(),
        );
  }

  // Create new chat
  Future<void> createChat(Chat chat) async {
    await _firestore.collection('chats').doc(chat.id).set(chat.toMap());
    notifyListeners();
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    // Delete all messages first
    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete chat document
    batch.delete(_firestore.collection('chats').doc(chatId));

    await batch.commit();
    notifyListeners();
  }

  // Send push notification for new message
  Future<void> _sendPushNotification(
    ChatMessage message,
    String targetPhoneNumber,
  ) async {
    // Find target user's FCM token
    final usersSnapshot = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: targetPhoneNumber)
        .get();

    if (usersSnapshot.docs.isNotEmpty) {
      final targetUser = usersSnapshot.docs.first;
      final fcmToken = targetUser.data()['fcmToken'];

      if (fcmToken != null) {
        // Send notification via FCM
        await _firestore.collection('notifications').add({
          'to': fcmToken,
          'notification': {'title': 'نیا پیغام', 'body': message.message},
          'data': {
            'type': 'chat_message',
            'chatId': message.chatId,
            'messageId': message.id,
          },
        });
      }
    }
  }

  // Get unread message count
  Stream<int> getUnreadMessageCount(String chatId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Search messages
  Future<List<ChatMessage>> searchMessages(String chatId, String query) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    return snapshot.docs
        .map((doc) => ChatMessage.fromMap(doc.data()))
        .where(
          (message) =>
              message.message.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  // Delete message
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
    notifyListeners();
  }

  // Update message
  Future<void> updateMessage(
    String chatId,
    String messageId,
    String newText,
  ) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
          'message': newText,
          'isEdited': true,
          'updatedAt': DateTime.now(),
        });
    notifyListeners();
  }
}
