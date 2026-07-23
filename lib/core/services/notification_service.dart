import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';
import 'package:account_app/features/inventory/item_detail_screen.dart';
import 'package:account_app/features/visual_finder/visual_finder_screen.dart';
import 'database_service.dart';
import 'auto_sync_service.dart';

class NotificationService with ChangeNotifier {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  
  GlobalKey<NavigatorState>? _navigatorKey;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  NotificationService() {
    _initNotifications();
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _startFirestoreListener();
      } else {
        _stopFirestoreListener();
      }
    });
  }
  
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> _initNotifications() async {
    await _setupLocalNotifications();
    await _setupFirebaseMessaging();
    await _loadStoredNotifications();
    
    if (_auth.currentUser != null) {
      _startFirestoreListener();
    }
  }

  void _startFirestoreListener() {
    if (_firestoreSubscription != null) return;
    final user = _auth.currentUser;
    if (user == null) return;

    _firestoreSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      
      List<AppNotification> newNotifications = [];
      for (var doc in snapshot.docs) {
         try {
           var data = doc.data();
           // Ensure ID matches document ID so deletion works
           data['id'] = doc.id;
           var notification = AppNotification.fromMap(data);
           newNotifications.add(notification);
         } catch (e) {
           print('Error parsing notification: $e');
         }
      }
      
      _notifications = newNotifications;
      _updateUnreadCount();
      notifyListeners();
      
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
           final data = change.doc.data();
           if (data != null) {
             final notification = AppNotification.fromMap(data);
             if (DateTime.now().difference(notification.timestamp).inMinutes < 2) {
                 _showLocalNotificationRaw(
                   title: notification.title,
                   body: notification.message,
                   payload: notification.type.toString().split('.').last,
                   dataPayload: notification.data,
                 );
             }
           }
        }
      }
    });
  }

  void _stopFirestoreListener() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
         _handleNotificationTap(response.payload);
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'account_channel',
      'Account Notifications',
      description: 'Notifications for account activities',
      importance: Importance.max, // Changed to max for heads-up
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _setupFirebaseMessaging() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    try {
      final String? fcmToken = await _firebaseMessaging.getToken();
      if (_auth.currentUser != null && fcmToken != null) {
        // Check if document exists before updating to avoid NOT_FOUND error
        final userDocRef = _firestore.collection('users').doc(_auth.currentUser!.uid);
        final userDoc = await userDocRef.get();
        if (userDoc.exists) {
           await userDocRef.update({
             'fcmToken': fcmToken,
           });
        } else {
           await userDocRef.set({
             'fcmToken': fcmToken,
           }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print("Error setting up FCM: $e");
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
       _handleBackgroundMessage(message);
       _handleNotificationTap(message.data['type'], message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then(
      (message) {
        if (message != null) {
           _handleTerminatedMessage(message);
           _handleNotificationTap(message.data['type'], message.data);
        }
      }
    );
  }
  
  void _handleNotificationTap(String? type, [Map<String, dynamic>? data]) async {
    if (_navigatorKey == null) return;
    
    String? accountId = data?['accountId'] ?? data?['relatedAccountId'];
    String? productId = data?['productId'] ?? data?['itemId'];
    
    if (productId != null) {
      // Find the item first or navigate to detail directly if we have it
      // For price drop, we likely want to see the item detail
      _navigateToProductDetail(productId);
      return;
    }

    if (accountId != null) {
       try {
         final context = _navigatorKey!.currentState!.context;
         await Future.delayed(Duration(milliseconds: 500));
         
         _navigatorKey!.currentState!.push(
           MaterialPageRoute(
             builder: (context) => _buildDestinationScreen(accountId),
           ),
         );
       } catch (e) {
         print('Navigation error: $e');
       }
    }
  }
  
  Widget _buildDestinationScreen(String? accountId) {
     return Scaffold(
       body: FutureBuilder<Account?>(
         future: _fetchAccountForNavigation(accountId),
         builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.done) {
             if (snapshot.data != null) {
               return PartyDetailScreen(party: snapshot.data!);
             } else {
               return Scaffold(
                 appBar: AppBar(title: Text('Details')),
                 body: Center(child: Text('Account details not found.')),
               );
             }
           }
           return Center(child: CircularProgressIndicator());
         },
       ),
     );
  }
  
  Future<Account?> _fetchAccountForNavigation(String? accountId) async {
     if (accountId == null) return null;
     try {
       final user = _auth.currentUser;
       if (user != null) {
          final doc = await _firestore.collection('users').doc(user.uid).collection('accounts').doc(accountId).get();
          if (doc.exists) {
            return Account.fromMap(doc.data()!);
          }
       }
     } catch (e) {
       print('Error fetching account: $e');
     }
     return null;
  }

  Future<void> _loadStoredNotifications() async {
    // Implementation handled by Listener
  }

  // Compatibility method to fix error in NotificationsScreen
  Future<void> loadFromCloud() async {
    if (_auth.currentUser != null) {
      // Simply restart listener if needed or just let it be
      _startFirestoreListener();
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {
  }

  void _handleTerminatedMessage(RemoteMessage? message) {
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    await _showLocalNotificationRaw(
      title: message.notification?.title ?? 'نیا نوٹیفیکیشن',
      body: message.notification?.body ?? '',
      payload: message.data['type'] ?? 'general',
      dataPayload: message.data,
    );
  }

  Future<void> _showLocalNotificationRaw({
    required String title,
    required String body,
    required String payload,
    Map<String, dynamic>? dataPayload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'account_channel',
          'Account Notifications',
          channelDescription: 'Notifications for account activities',
          importance: Importance.max, // Increased to Max
          priority: Priority.max,     // Increased to Max
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,     // Added to wake screen
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    String fullPayload = payload;
    if (dataPayload != null) {
       String accId = dataPayload['accountId'] ?? dataPayload['relatedAccountId'] ?? '';
       if (accId.isNotEmpty) fullPayload = "$payload|$accId";
    }

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: fullPayload,
    );
  }

  void _addNotificationFromMessage(RemoteMessage message) {
  }

  NotificationType _getNotificationTypeFromString(String type) {
    switch (type) {
      case 'transaction': return NotificationType.transaction;
      case 'share': return NotificationType.share;
      case 'account_share': return NotificationType.share;
      case 'reminder': return NotificationType.reminder;
      case 'report': return NotificationType.report;
      case 'price_drop': return NotificationType.report; // Use report or add new type
      case 'system': return NotificationType.system;
      default: return NotificationType.general;
    }
  }

  // --- Notification Actions with Persistence ---

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index].isRead = true;
      _updateUnreadCount();
      notifyListeners();
      
      if (_auth.currentUser != null) {
        _firestore.collection('users').doc(_auth.currentUser!.uid)
            .collection('notifications').doc(notificationId).update({'isRead': true})
            .catchError((e) => print("Error marking read: $e"));
      }
    }
  }

  void markAllAsRead() {
    for (var notification in _notifications) {
      notification.isRead = true;
    }
    _unreadCount = 0;
    notifyListeners();
    
    if (_auth.currentUser != null) {
      final batch = _firestore.batch();
      for (var n in _notifications) {
         final ref = _firestore.collection('users').doc(_auth.currentUser!.uid)
             .collection('notifications').doc(n.id);
         batch.update(ref, {'isRead': true});
      }
      batch.commit().catchError((e) => print("Error marking all read: $e"));
    }
  }

  void deleteNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _updateUnreadCount();
    notifyListeners();
    
    if (_auth.currentUser != null) {
      _firestore.collection('users').doc(_auth.currentUser!.uid)
          .collection('notifications').doc(notificationId).delete()
          .catchError((e) => print("Error deleting notification: $e"));
    }
  }

  void updateNotificationData(String notificationId, Map<String, dynamic> newData) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final oldData = _notifications[index].data ?? {};
      final mergedData = {...oldData, ...newData};
      
      // Update local state
      _notifications[index] = AppNotification(
        id: _notifications[index].id,
        title: _notifications[index].title,
        message: _notifications[index].message,
        type: _notifications[index].type,
        isRead: _notifications[index].isRead,
        timestamp: _notifications[index].timestamp,
        data: mergedData,
        relatedAccountId: _notifications[index].relatedAccountId,
        relatedTransactionId: _notifications[index].relatedTransactionId,
      );
      
      notifyListeners();
      
      // Update Firestore
      if (_auth.currentUser != null) {
        _firestore.collection('users').doc(_auth.currentUser!.uid)
            .collection('notifications').doc(notificationId)
            .update({'data': mergedData})
            .catchError((e) => print("Error updating notification data: $e"));
      }
    }
  }

  void clearAll() {
    if (_auth.currentUser != null && _notifications.isNotEmpty) {
      final batch = _firestore.batch();
      final collectionRef = _firestore.collection('users').doc(_auth.currentUser!.uid)
          .collection('notifications');
      
      for (var n in _notifications) {
        batch.delete(collectionRef.doc(n.id));
      }
      
      batch.commit().catchError((e) => print("Error clearing all notifications from Firestore: $e"));
    }

    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

  // --- Sending Logic ---

  Future<void> notifyPartyByPhone({
    required String partyPhoneNumber,
    required double amount,
    required String transactionType,
    String? description,
    List<Map<String, dynamic>>? items,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    String myName = currentUser.displayName ?? '';
    if (myName.isEmpty) myName = currentUser.phoneNumber ?? 'ایک صارف';

    String targetPhone = partyPhoneNumber.replaceAll(RegExp(r'[\s-]+'), '');
    if (targetPhone.startsWith('03')) targetPhone = '+92${targetPhone.substring(1)}';
    else if (targetPhone.startsWith('3')) targetPhone = '+92$targetPhone';
    else if (targetPhone.startsWith('92')) targetPhone = '+$targetPhone';
    
    try {
       final querySnapshot = await _firestore.collection('users')
           .where('phoneNumber', isEqualTo: targetPhone).limit(1).get();

       if (querySnapshot.docs.isNotEmpty) {
         final targetUserId = querySnapshot.docs.first.id;
         if (targetUserId == currentUser.uid) return;

         String typeText = transactionType == 'income' ? 'رقم لی' : 'رقم دی';
         String messageBody = '$myName نے آپ کے ساتھ Rs. $amount کا لین دین درج کیا ہے ($typeText)۔';

         final notifId = DateTime.now().millisecondsSinceEpoch.toString();
         final notification = AppNotification(
            id: notifId,
            title: 'نیا لین دین (Karobari Saathi)',
            message: messageBody,
            type: NotificationType.transaction,
            isRead: false,
            timestamp: DateTime.now(),
            data: {
              'amount': amount.toString(),
              'transactionType': transactionType,
              'senderName': myName,
              'senderPhone': currentUser.phoneNumber,
              'senderUid': currentUser.uid,
              'senderPhotoUrl': currentUser.photoURL,
              'description': description ?? '',
              'items': items ?? [],
            },
         );

         await _firestore.collection('users').doc(targetUserId)
             .collection('notifications').doc(notifId).set(notification.toMap());
       }
    } catch (e) {
      print('Error notifying party: $e');
    }
  }

  Future<void> sendShareNotification({
    required String accountId,
    required String accountName,
    required String sharedWithPhone,
  }) async {
  }
  
  Future<void> sendReminderNotification({
    required String accountId,
    required String accountName,
    required double pendingAmount,
  }) async {
  }

  Future<void> sendReportNotification(String period) async {
  }

  void _navigateToProductDetail(String itemId) async {
    if (_navigatorKey == null) return;
    
    // We need to fetch the item first
    try {
      final db = DatabaseService(); // This is a bit hacky, better use provider if possible
      // Actually, we can fetch from Firestore directly here or use a helper
      final doc = await FirebaseFirestore.instance.collectionGroup('inventory_items')
          .where('id', isEqualTo: itemId).limit(1).get();
          
      if (doc.docs.isNotEmpty) {
        final item = InventoryItem.fromMap({...doc.docs.first.data(), 'id': doc.docs.first.id});
        _navigatorKey!.currentState!.push(
          MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
        );
      }
    } catch (e) {
      print("Navigation to item error: $e");
    }
  }
}
