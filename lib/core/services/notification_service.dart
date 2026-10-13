import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/widgets/in_app_notification_banner.dart';
import 'package:account_app/features/accounts/party_detail_screen.dart';

class NotificationService with ChangeNotifier {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  String? _fcmToken;
  String? _activeUserId;
  bool _isDisposed = false;

  GlobalKey<NavigatorState>? _navigatorKey;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  NotificationService() {
    _initNotifications();
    _authStateSubscription =
        _auth.authStateChanges().listen(_handleAuthStateChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopFirestoreListener();
    _authStateSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _openedMessageSubscription?.cancel();
    super.dispose();
  }

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> _initNotifications() async {
    try {
      await _setupLocalNotifications();
    } catch (error, stackTrace) {
      debugPrint('Local notification setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _setupFirebaseMessaging();
    } catch (error, stackTrace) {
      debugPrint('Firebase Messaging setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    await _loadStoredNotifications();

    if (!_isDisposed && _auth.currentUser != null) {
      _handleAuthStateChanged(_auth.currentUser);
    }
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (_isDisposed) return;
    final userId = user?.uid;
    if (_activeUserId == userId) return;

    _activeUserId = userId;
    await _firestoreSubscription?.cancel();
    _firestoreSubscription = null;

    if (userId == null) {
      _notifications = [];
      _updateUnreadCount();
      notifyListeners();
      return;
    }

    _startFirestoreListener();
    await _registerCurrentToken(userId);
  }

  Future<void> _registerCurrentToken(String userId) async {
    try {
      final token = _fcmToken ?? await _firebaseMessaging.getToken();
      if (token == null || _auth.currentUser?.uid != userId) return;
      _fcmToken = token;
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      debugPrint('Unable to register FCM token for user $userId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleTokenRefresh(String token) async {
    final previousToken = _fcmToken;
    _fcmToken = token;
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final userRef = _firestore.collection('users').doc(userId);
      if (previousToken != null && previousToken != token) {
        await userRef.set({
          'fcmTokens': FieldValue.arrayRemove([previousToken]),
        }, SetOptions(merge: true));
      }
      await userRef.set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      debugPrint('Unable to update refreshed FCM token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> unregisterCurrentDeviceToken() async {
    final userId = _auth.currentUser?.uid;
    final token = _fcmToken;
    if (userId == null || token == null) return;

    Object? unregisterError;
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final updates = <String, dynamic>{
        'fcmTokens': FieldValue.arrayRemove([token]),
      };
      if (userDoc.data()?['fcmToken'] == token) {
        updates['fcmToken'] = FieldValue.delete();
      }
      await userRef.set(updates, SetOptions(merge: true));
    } catch (error, stackTrace) {
      unregisterError = error;
      debugPrint('Unable to unregister FCM token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
    } catch (error, stackTrace) {
      debugPrint('Unable to delete local FCM token: $error');
      debugPrintStack(stackTrace: stackTrace);
      unregisterError ??= error;
    }

    if (unregisterError != null) {
      throw Exception(
          'Unable to safely unregister device notifications: $unregisterError');
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
        _handleLocalNotificationTap(response.payload);
      },
    );

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _handleLocalNotificationTap(
        launchDetails?.notificationResponse?.payload,
      );
    }

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
    _foregroundMessageSubscription ??=
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _openedMessageSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data['type']?.toString(), message.data);
    });
    _tokenRefreshSubscription ??=
        _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);

    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error, stackTrace) {
      debugPrint('Notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      _fcmToken = await _firebaseMessaging.getToken();
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _registerCurrentToken(userId);
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to obtain FCM token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleNotificationTap(
          initialMessage.data['type']?.toString(),
          initialMessage.data,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to process initial FCM notification: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleNotificationTap(
    String? _type, [
    Map<String, dynamic>? data,
  ]) async {
    NavigatorState? navigator;
    for (var attempt = 0; attempt < 20; attempt++) {
      navigator = _navigatorKey?.currentState;
      if (navigator != null && navigator.mounted) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (navigator == null || !navigator.mounted) {
      debugPrint('Cannot open notification: app navigator is unavailable.');
      return;
    }

    final accountId =
        (data?['accountId'] ?? data?['relatedAccountId'])?.toString().trim();
    if (accountId != null && accountId.isNotEmpty && accountId != 'null') {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => _buildDestinationScreen(accountId),
        ),
      );
      return;
    }

    if (_navigatorKey?.currentState?.mounted == true) {
      _navigatorKey!.currentState!.pushNamed('/notifications');
    } else {
      debugPrint('Cannot open notifications: app navigator was disposed.');
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
                appBar: AppBar(title: UrduAwareText('Details')),
                body: Center(child: UrduAwareText('Account details not found.')),
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

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) {
      await _showLocalNotification(message);
      return;
    }

    try {
      InAppNotificationBanner.show(
        context,
        title: message.notification?.title ??
            message.data['title']?.toString() ??
            'نیا نوٹیفیکیشن',
        message: message.notification?.body ??
            message.data['body']?.toString() ??
            '',
        senderName: message.data['senderName']?.toString() ?? 'Karobari Saathi',
        imageUrl: message.data['senderPhotoUrl']?.toString() ??
            message.data['imageUrl']?.toString(),
        onTap: () => _handleNotificationTap(
          message.data['type']?.toString(),
          message.data,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to show in-app notification banner: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _showLocalNotification(message);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      await _showLocalNotificationRaw(
        title: message.notification?.title ??
            message.data['title']?.toString() ??
            'نیا نوٹیفیکیشن',
        body: message.notification?.body ??
            message.data['body']?.toString() ??
            '',
        payload: message.data['type']?.toString() ?? 'general',
        dataPayload: message.data,
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to show fallback local notification: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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

    final notificationType = dataPayload?['type']?.toString() ?? payload;
    final fullPayload = jsonEncode({
      'type': notificationType,
      'data': dataPayload ?? <String, dynamic>{},
    });

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: fullPayload,
    );
  }

  void _handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        _handleNotificationTap(
          decoded['type']?.toString(),
          data is Map ? Map<String, dynamic>.from(data) : null,
        );
        return;
      }
    } catch (_) {
      // Fall back to the payload format used by older notifications.
    }

    final parts = payload.split('|');
    _handleNotificationTap(
      parts.first,
      parts.length > 1 ? {'accountId': parts[1]} : null,
    );
  }

  void _addNotificationFromMessage(RemoteMessage message) {}

  NotificationType _getNotificationTypeFromString(String type) {
    switch (type) {
      case 'transaction':
        return NotificationType.transaction;
      case 'share':
      case 'account_share':
        return NotificationType.share;
      case 'reminder':
        return NotificationType.reminder;
      case 'report':
      case 'price_drop':
        return NotificationType.report;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.general;
    }
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
    final notificationsToUpdate = List<AppNotification>.of(_notifications);
    for (var notification in _notifications) {
      notification.isRead = true;
    }
    _unreadCount = 0;
    notifyListeners();

    unawaited(_writeNotificationBatch(notificationsToUpdate, delete: false));
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
    final notificationsToDelete = List<AppNotification>.of(_notifications);
    unawaited(_writeNotificationBatch(notificationsToDelete, delete: true));

    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> _writeNotificationBatch(
    List<AppNotification> notifications, {
    required bool delete,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || notifications.isEmpty) return;

    final collectionRef =
        _firestore.collection('users').doc(userId).collection('notifications');
    try {
      for (var offset = 0; offset < notifications.length; offset += 450) {
        final end = offset + 450 < notifications.length
            ? offset + 450
            : notifications.length;
        final batch = _firestore.batch();
        for (final notification in notifications.sublist(offset, end)) {
          final reference = collectionRef.doc(notification.id);
          if (delete) {
            batch.delete(reference);
          } else {
            batch.update(reference, {'isRead': true});
          }
        }
        await batch.commit();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Unable to ${delete ? 'delete' : 'mark read'} notifications: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _updateUnreadCount() {
    _unreadCount =
        _notifications.where((notification) => !notification.isRead).length;
  }

  Future<void> notifyPartyByPhone({
    required String partyPhoneNumber,
    required double amount,
    required String transactionType,
    String? category,
    String? paymentMethod,
    String? description,
    List<Map<String, dynamic>>? items,
    double? receivedAmount,
    double? pendingAmount,
    String? transactionId,
    DateTime? transactionDate,
    String? referenceNumber,
    double? subtotal,
    double? discountAmount,
    double? discountPercent,
    String? discountReason,
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

        // Build detailed receipt message body
        final StringBuffer bodyBuffer = StringBuffer();
        bodyBuffer.writeln('🧾 $myName کی طرف سے بل / رسید');
        if (description != null && description.isNotEmpty) {
          bodyBuffer.writeln('تفصیل: $description');
        }
        bodyBuffer.writeln('کل رقم: Rs. ${amount.toStringAsFixed(0)}');

        if (items != null && items.isNotEmpty) {
          bodyBuffer.writeln('--- آئٹمز ---');
          for (final item in items) {
            final name = item['description'] ?? item['name'] ?? '';
            final qty = item['quantity'] ?? 1;
            final rate = item['rate'] ?? 0;
            final total = item['total'] ?? (qty * rate);
            bodyBuffer.writeln('• $name ($qty × $rate = $total)');
          }
        }

        if (receivedAmount != null && pendingAmount != null) {
          bodyBuffer
              .writeln('وصول شدہ: Rs. ${receivedAmount.toStringAsFixed(0)}');
          if (pendingAmount > 0) {
            bodyBuffer.writeln(
                'بقایا ادھار: Rs. ${pendingAmount.toStringAsFixed(0)}');
          }
        }

        final notifId = DateTime.now().millisecondsSinceEpoch.toString();
        final notification = AppNotification(
          id: notifId,
          title: '📄 تفصیلی بل / رسید',
          message: bodyBuffer.toString().trim(),
          type: NotificationType.transaction,
          isRead: false,
          timestamp: DateTime.now(),
          data: {
            'amount': amount.toString(),
            'transactionType': transactionType,
            'category': category,
            'paymentMethod': paymentMethod,
            'senderName': myName,
            'senderPhone': currentUser.phoneNumber,
            'senderUid': currentUser.uid,
            'senderPhotoUrl': currentUser.photoURL,
            'description': description ?? '',
            'items': items ?? [],
            'receivedAmount': receivedAmount?.toString() ?? '0',
            'pendingAmount': pendingAmount?.toString() ?? '0',
            'transactionId': transactionId ?? notifId,
            'transactionDate':
                (transactionDate ?? DateTime.now()).toIso8601String(),
            'referenceNumber': referenceNumber,
            'subtotal': (subtotal ?? amount).toString(),
            'discountAmount': (discountAmount ?? 0).toString(),
            'discountPercent': discountPercent?.toString(),
            'discountReason': discountReason,
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
      debugPrint('Error notifying party with receipt: $e');
    }
  }

  Future<void> sendReminderNotification({
    required String accountId,
    required String accountName,
    required double pendingAmount,
  }) async {}

  Future<void> sendReportNotification(String period) async {}
}
