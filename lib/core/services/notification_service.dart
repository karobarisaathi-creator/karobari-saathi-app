import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';
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
        .snapshots()
        .listen((snapshot) {
      debugPrint(
          'Notification snapshot received with ${snapshot.docs.length} docs');
      List<AppNotification> newNotifications = [];
      for (var doc in snapshot.docs) {
        try {
          var data = doc.data();
          data['id'] = doc.id;
          var notification = AppNotification.fromMap(data);
          newNotifications.add(notification);
        } catch (e) {
          debugPrint('Error parsing notification ${doc.id}: $e');
        }
      }

      _notifications = newNotifications;
      _updateUnreadCount();
      notifyListeners();

      // Trigger local notification for NEW arrivals while app is foreground
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            final notification = AppNotification.fromMap(data);
            // Only show if it's less than 1 minute old (avoids old data triggering on load)
            if (DateTime.now().difference(notification.timestamp).inMinutes <
                1) {
              _showLocalNotificationRaw(
                title: notification.title,
                body: notification.message,
                payload: notification.type.name,
                dataPayload: notification.data,
              );
            }
          }
        }
      }
    }, onError: (e) {
      debugPrint('Firestore Notification Listener Error: $e');
    });
  }

  void _stopFirestoreListener() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  void refreshListener() {
    _stopFirestoreListener();
    _startFirestoreListener();
  }

  Future<void> loadFromCloud() async {
    if (_auth.currentUser != null) {
      refreshListener();
    }
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
      importance: Importance.max,
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
        final userDocRef =
            _firestore.collection('users').doc(_auth.currentUser!.uid);
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
      debugPrint("Error setting up FCM: $e");
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleBackgroundMessage(message);
      _handleNotificationTap(message.data['type'], message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleTerminatedMessage(message);
        _handleNotificationTap(message.data['type'], message.data);
      }
    });
  }

  void _handleNotificationTap(String? type,
      [Map<String, dynamic>? data]) async {
    if (_navigatorKey == null) return;

    String? accountId = data?['accountId'] ?? data?['relatedAccountId'];

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
        debugPrint('Navigation error: $e');
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
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .doc(accountId)
            .get();
        if (doc.exists) {
          return Account.fromMap(doc.data()!);
        }
      }
    } catch (e) {
      debugPrint('Error fetching account: $e');
    }
    return null;
  }

  Future<void> _loadStoredNotifications() async {
    // Implementation handled by Listener
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  void _handleBackgroundMessage(RemoteMessage message) {}

  void _handleTerminatedMessage(RemoteMessage? message) {}

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
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    String fullPayload = payload;
    if (dataPayload != null) {
      String accId =
          dataPayload['accountId'] ?? dataPayload['relatedAccountId'] ?? '';
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

  void _addNotificationFromMessage(RemoteMessage message) {}

  NotificationType _getNotificationTypeFromString(String type) {
    switch (type) {
      case 'transaction':
        return NotificationType.transaction;
      case 'share':
        return NotificationType.share;
      case 'account_share':
        return NotificationType.share;
      case 'reminder':
        return NotificationType.reminder;
      case 'report':
        return NotificationType.report;
      case 'price_drop':
        return NotificationType.report;
      case 'artisan_request':
        return NotificationType.general;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.general;
    }
  }

  Future<void> sendArtisanWorkRequest({
    required String artisanUid,
    required String customerName,
    required String workDescription,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final String requestId = "${currentUser.uid}_$artisanUid";

      await _firestore.collection('artisan_requests').doc(requestId).set({
        'customerUid': currentUser.uid,
        'artisanUid': artisanUid,
        'status': 'pending',
        'workDescription': workDescription,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final notifId = "artisan_req_${DateTime.now().millisecondsSinceEpoch}";
      final notification = AppNotification(
        id: notifId,
        title: 'کام کی درخواست',
        message:
            '$customerName آپ سے کام کے بارے میں پوچھ رہے ہیں۔ کیا آپ دستیاب ہیں؟',
        type: NotificationType.general,
        isRead: false,
        timestamp: DateTime.now(),
        data: {
          'type': 'artisan_request',
          'senderName': customerName,
          'senderUid': currentUser.uid,
          'senderPhone': currentUser.phoneNumber,
          'senderPhotoUrl': currentUser.photoURL,
          'isSenderVerified': currentUser.emailVerified,
          'artisanUid': artisanUid,
          'customerUid': currentUser.uid,
          'requestId': requestId,
          'workDescription': workDescription,
          'status': 'pending',
          'needsAction': true,
        },
      );

      await _firestore
          .collection('users')
          .doc(artisanUid)
          .collection('notifications')
          .doc(notifId)
          .set(notification.toMap());
    } catch (e) {
      debugPrint('Error sending artisan request: $e');
    }
  }

  Future<void> respondToArtisanRequest({
    required String customerUid,
    required String artisanName,
    required bool accepted,
    required String notificationId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final String requestId = "${customerUid}_${currentUser.uid}";
      final requestDoc = await _firestore.collection('artisan_requests').doc(requestId).get();
      final requestData = requestDoc.data();

      await _firestore.collection('artisan_requests').doc(requestId).set({
        'status': accepted ? 'accepted' : 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      updateNotificationData(
          notificationId, {'responded': true, 'accepted': accepted});

      if (accepted) {
        // خودکار آرڈر بنائیں
        final orderId = "order_${DateTime.now().millisecondsSinceEpoch}";
        final order = ArtisanWorkOrder(
          id: orderId,
          artisanId: currentUser.uid,
          customerId: customerUid,
          customerName: requestData?['customerName'] ?? 'گاہک',
          customerPhone: requestData?['customerPhone'] ?? '',
          workDescription: requestData?['workDescription'] ?? 'کام کی تفصیل',
          status: 'negotiating', // ڈیل ہو رہی ہے
          createdAt: DateTime.now(),
          artisanAgreed: true, // کاریگر نے "ہاں" کر کے اپنی طرف سے سائن کر دیا
        );

        await _firestore
            .collection('artisans')
            .doc(currentUser.uid)
            .collection('work_orders')
            .doc(orderId)
            .set(order.toMap());
      }

      final notifId = "artisan_res_${DateTime.now().millisecondsSinceEpoch}";
      final notification = AppNotification(
        id: notifId,
        title: accepted ? 'کام کی منظوری!' : 'معذرت',
        message: accepted
            ? '$artisanName نے آپ کی کام کی درخواست قبول کر لی ہے۔ اب آپ رابطہ کر سکتے ہیں۔'
            : '$artisanName اس وقت کام کے لیے دستیاب نہیں ہیں۔',
        type: NotificationType.general,
        isRead: false,
        timestamp: DateTime.now(),
        data: {
          'type': 'artisan_response',
          'artisanName': artisanName,
          'artisanUid': currentUser.uid,
          'customerUid': customerUid,
          'accepted': accepted,
          'requestId': requestId,
        },
      );

      await _firestore
          .collection('users')
          .doc(customerUid)
          .collection('notifications')
          .doc(notifId)
          .set(notification.toMap());
    } catch (e) {
      debugPrint('Error responding to artisan request: $e');
    }
  }

  Future<void> sendQuoteNotification({
    required String customerUid,
    required String artisanName,
    required double amount,
    required String workOrderId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final notifId = "quote_${DateTime.now().millisecondsSinceEpoch}";
      final notification = AppNotification(
        id: notifId,
        title: 'قیمت کی تفصیل',
        message: '$artisanName نے آپ کے کام کے لیے Rs. $amount کی قیمت دی ہے۔',
        type: NotificationType.general,
        isRead: false,
        timestamp: DateTime.now(),
        data: {
          'type': 'artisan_quote',
          'artisanName': artisanName,
          'artisanUid': currentUser.uid,
          'amount': amount,
          'workOrderId': workOrderId,
        },
      );

      await _firestore
          .collection('users')
          .doc(customerUid)
          .collection('notifications')
          .doc(notifId)
          .set(notification.toMap());
    } catch (e) {
      debugPrint('Error sending quote notification: $e');
    }
  }

  Future<void> sendBidStatusNotification({
    required String artisanUid,
    required String jobTitle,
    required bool accepted,
  }) async {
    try {
      final notifId = "bid_${accepted ? 'acc' : 'rej'}_${DateTime.now().millisecondsSinceEpoch}";
      final notification = AppNotification(
        id: notifId,
        title: accepted ? 'بولی قبول کر لی گئی!' : 'بولی مسترد',
        message: accepted
            ? 'آپ کی "$jobTitle" کے لیے لگائی گئی بولی قبول کر لی گئی ہے!'
            : 'معذرت، "$jobTitle" کے لیے آپ کی بولی قبول نہیں کی گئی۔',
        type: NotificationType.general,
        isRead: false,
        timestamp: DateTime.now(),
        data: {
          'type': 'bid_status',
          'accepted': accepted,
          'jobTitle': jobTitle,
        },
      );

      await _firestore
          .collection('users')
          .doc(artisanUid)
          .collection('notifications')
          .doc(notifId)
          .set(notification.toMap());
    } catch (e) {
      debugPrint('Error sending bid status notification: $e');
    }
  }

  Future<String?> getArtisanRequestStatus(String artisanUid) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection('artisan_requests')
          .doc("${user.uid}_$artisanUid")
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final String status = data['status'] as String;
        final Timestamp? timestamp = data['respondedAt'] as Timestamp? ??
            data['timestamp'] as Timestamp?;

        if (timestamp != null) {
          final DateTime lastAction = timestamp.toDate();
          final DateTime now = DateTime.now();
          final Duration difference = now.difference(lastAction);

          if (status == 'accepted' && difference.inHours >= 24) {
            return null;
          }
          if (status == 'rejected' && difference.inHours >= 12) {
            return null;
          }
          if (status == 'pending' && difference.inHours >= 48) {
            return null;
          }
        }
        return status;
      }
    } catch (e) {
      debugPrint('Error checking request status: $e');
    }
    return null;
  }

  Stream<String?> artisanRequestStatusStream(String artisanUid) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<String?>.value(null);
    }

    return _firestore
        .collection('artisan_requests')
        .doc("${user.uid}_$artisanUid")
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final String status = data['status'] as String? ?? '';
      final Timestamp? timestamp =
          data['respondedAt'] as Timestamp? ?? data['timestamp'] as Timestamp?;

      if (timestamp != null) {
        final DateTime lastAction = timestamp.toDate();
        final DateTime now = DateTime.now();
        final Duration difference = now.difference(lastAction);

        if (status == 'accepted' && difference.inHours >= 24) {
          return null;
        }
        if (status == 'rejected' && difference.inHours >= 12) {
          return null;
        }
        if (status == 'pending' && difference.inHours >= 48) {
          return null;
        }
      }
      return status.isEmpty ? null : status;
    }).handleError((e) {
      debugPrint('Error listening artisan request status: $e');
    });
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index].isRead = true;
      _updateUnreadCount();
      notifyListeners();

      if (_auth.currentUser != null) {
        _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('notifications')
            .doc(notificationId)
            .update({'isRead': true}).catchError(
                (e) => debugPrint("Error marking read: $e"));
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
        final ref = _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('notifications')
            .doc(n.id);
        batch.update(ref, {'isRead': true});
      }
      batch
          .commit()
          .catchError((e) => debugPrint("Error marking all read: $e"));
    }
  }

  void deleteNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _updateUnreadCount();
    notifyListeners();

    if (_auth.currentUser != null) {
      _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete()
          .catchError((e) => debugPrint("Error deleting notification: $e"));
    }
  }

  void updateNotificationData(
      String notificationId, Map<String, dynamic> newData) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final oldData = _notifications[index].data ?? {};
      final mergedData = {...oldData, ...newData};

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

      if (_auth.currentUser != null) {
        _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('notifications')
            .doc(notificationId)
            .update({'data': mergedData}).catchError(
                (e) => debugPrint("Error updating notification data: $e"));
      }
    }
  }

  void clearAll() {
    if (_auth.currentUser != null && _notifications.isNotEmpty) {
      final batch = _firestore.batch();
      final collectionRef = _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('notifications');

      for (var n in _notifications) {
        batch.delete(collectionRef.doc(n.id));
      }

      batch.commit().catchError((e) =>
          debugPrint("Error clearing all notifications from Firestore: $e"));
    }

    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

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
    if (targetPhone.startsWith('03'))
      targetPhone = '+92${targetPhone.substring(1)}';
    else if (targetPhone.startsWith('3'))
      targetPhone = '+92$targetPhone';
    else if (targetPhone.startsWith('92')) targetPhone = '+$targetPhone';

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: targetPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final targetUserId = querySnapshot.docs.first.id;
        if (targetUserId == currentUser.uid) return;

        final dbService = DatabaseService();
        bool isVerified = await dbService.isUserVerified(currentUser.uid);

        String typeText = transactionType == 'income' ? 'رقم لی' : 'رقم دی';
        String messageBody =
            '$myName نے آپ کے ساتھ Rs. $amount کا لین دین درج کیا ہے ($typeText)۔';

        final notifId = DateTime.now().millisecondsSinceEpoch.toString();
        final notification = AppNotification(
          id: notifId,
          title: 'نیا لین دین',
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
            'isSenderVerified': isVerified,
            'description': description ?? '',
            'items': items ?? [],
          },
        );

        await _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('notifications')
            .doc(notifId)
            .set(notification.toMap());
      }
    } catch (e) {
      debugPrint('Error notifying party: $e');
    }
  }

  Future<void> sendReminderNotification({
    required String accountId,
    required String accountName,
    required double pendingAmount,
  }) async {}

  Future<void> sendReportNotification(String period) async {}
}
