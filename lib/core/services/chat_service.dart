import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart';
import 'security_service.dart';

class ChatService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SecurityService _securityService = SecurityService();

  // Rate Limiting Map (Memory based for session)
  final Map<String, List<DateTime>> _messageTimestamps = {};

  String get currentUserId => _auth.currentUser?.uid ?? '';

  String getChatRoomId(String otherUserId) {
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    return ids.join('_');
  }

  Future<void> setTypingStatus(String otherUserId, bool isTyping) async {
    final String chatRoomId = getChatRoomId(otherUserId);
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'typing_$currentUserId': isTyping,
    }, SetOptions(merge: true));
  }

  Stream<bool> getTypingStatus(String otherUserId) {
    final String chatRoomId = getChatRoomId(otherUserId);
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      return snapshot.data()?['typing_$otherUserId'] ?? false;
    });
  }

  Stream<bool> getOnlineStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data();
      if (data == null) return false;
      
      final lastActive = data['lastActive'];
      if (lastActive == null) return false;
      
      final DateTime lastActiveTime = (lastActive as Timestamp).toDate();
      return DateTime.now().difference(lastActiveTime).inMinutes < 5;
    });
  }

  Future<void> updateLastActive() async {
    if (currentUserId.isEmpty) return;
    await _firestore.collection('users').doc(currentUserId).set({
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendMessage(String receiverId, String message) async {
    if (message.trim().isEmpty) return;

    // --- ENTERPRISE RATE LIMITING ---
    final now = DateTime.now();
    _messageTimestamps.putIfAbsent(currentUserId, () => []);
    _messageTimestamps[currentUserId]!.removeWhere((t) => now.difference(t).inMinutes > 1);
    
    if (_messageTimestamps[currentUserId]!.length >= 10) {
      throw Exception("Slow down! You are sending messages too fast.");
    }
    _messageTimestamps[currentUserId]!.add(now);

    final String chatRoomId = getChatRoomId(receiverId);
    final timestamp = FieldValue.serverTimestamp();

    // --- END-TO-END ENCRYPTION ---
    final encryptedMessage = _securityService.encryptData(message.trim());

    await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'message': encryptedMessage,
      'isEncrypted': true,
      'timestamp': timestamp,
      'isRead': false,
      'status': 'sent', // sent, delivered, read
    });

    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'lastMessage': '[Encrypted Message]',
      'lastMessageTime': timestamp,
      'participants': [currentUserId, receiverId],
      'unreadCount_$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

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
              
              if (data['isEncrypted'] == true && content.isNotEmpty) {
                try { content = _securityService.decryptData(content); } catch (_) { content = '[Decryption Failed]'; }
              }
              
              final decryptedData = Map<String, dynamic>.from(data);
              decryptedData['message'] = content;
              return ChatMessage.fromMap(decryptedData, doc.id);
            }).toList());
  }

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

  Future<void> markAsRead(String otherUserId) async {
    final String chatRoomId = getChatRoomId(otherUserId);
    
    // Update individual messages
    final messages = await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();
        
    for (var doc in messages.docs) {
      await doc.reference.update({'isRead': true, 'status': 'read'});
    }

    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'unreadCount_$currentUserId': 0,
    });
  }
}