import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart';
import 'security_service.dart';

class ChatService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecurityService _securityService = SecurityService();

  // Get current user ID
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Get or Create Chat Room ID (Deterministic)
  String getChatRoomId(String otherUserId) {
    List<String> ids = [currentUserId, otherUserId];
    ids.sort(); // Ensure same ID regardless of who starts the chat
    return ids.join('_');
  }

  // Send Message with End-to-End Encryption (simplified)
  Future<void> sendMessage(String receiverId, String message) async {
    if (message.trim().isEmpty) return;

    final String chatRoomId = getChatRoomId(receiverId);
    final timestamp = FieldValue.serverTimestamp();

    // ENTERPRISE: Encrypt message content before sending to cloud
    final encryptedMessage = _securityService.encryptData(message.trim());

    // 1. Add message to the sub-collection
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'message': encryptedMessage, // Encrypted content
      'isEncrypted': true,
      'timestamp': timestamp,
      'isRead': false,
    });

    // 2. Update chat room metadata for the inbox list
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': '[Encrypted Message]', // Masked for list view
      'lastMessageTime': timestamp,
      'participants': [currentUserId, receiverId],
      'unreadCount_$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // Stream Messages for a specific chat with Decryption
  Stream<List<ChatMessage>> getMessages(String otherUserId) {
    final String chatRoomId = getChatRoomId(otherUserId);
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              String content = data['message'] ?? '';
              
              // ENTERPRISE: Decrypt if the flag is present
              if (data['isEncrypted'] == true && content.isNotEmpty) {
                try {
                  content = _securityService.decryptData(content);
                } catch (e) {
                  content = '[Decryption Failed]';
                }
              }
              
              final decryptedData = Map<String, dynamic>.from(data);
              decryptedData['message'] = content;
              
              return ChatMessage.fromMap(decryptedData, doc.id);
            }).toList());
  }

  // Stream all active chats for the current user (Inbox)
  Stream<List<Map<String, dynamic>>> getChatRooms() {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Mark messages as read
  Future<void> markAsRead(String otherUserId) async {
    final String chatRoomId = getChatRoomId(otherUserId);
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'unreadCount_$currentUserId': 0,
    });
  }
}
