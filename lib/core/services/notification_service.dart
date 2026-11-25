import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/utils/formatters.dart';

const String _pendingPartyNotificationsBoxName =
    'pending_party_notifications_v1';

enum PartyNotificationResult {
  savedToInbox,
  recipientNotFound,
  sameUser,
  notSignedIn,
}

class NotificationService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<AppNotification> _notifications = [];
  final Set<String> _pendingDeletionIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _firestoreSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _activeUserId;
  bool _isDisposed = false;
  bool _isProcessingPendingPartyNotifications = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  NotificationService() {
    _authStateSubscription =
        _auth.authStateChanges().listen(_handleAuthStateChanged);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        if (!results.contains(ConnectivityResult.none)) {
          unawaited(_processPendingPartyNotifications());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Activity feed connectivity listener failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
    if (_auth.currentUser != null) {
      unawaited(_handleAuthStateChanged(_auth.currentUser));
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopFirestoreListener();
    _authStateSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
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
      notifyListeners();
      return;
    }

    _startFirestoreListener();
    unawaited(_processPendingPartyNotifications());
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
      final newNotifications = <AppNotification>[];
      for (final doc in snapshot.docs) {
        if (_pendingDeletionIds.contains('${user.uid}/${doc.id}')) continue;
        try {
          final data = doc.data();
          data['id'] = doc.id;
          newNotifications.add(AppNotification.fromMap(data));
        } catch (error, stackTrace) {
          debugPrint('Unable to parse activity ${doc.id}: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      _notifications = newNotifications;
      notifyListeners();
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('Firestore activity feed listener failed: $error');
      debugPrintStack(stackTrace: stackTrace);
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
    if (_auth.currentUser != null) refreshListener();
  }

  void markAsRead(String notificationId) {
    final index =
        _notifications.indexWhere((item) => item.id == notificationId);
    if (index == -1 || _notifications[index].isRead) return;
    _notifications[index].isRead = true;
    notifyListeners();
    unawaited(_updateActivity(notificationId, {'isRead': true}));
  }

  void markAllAsRead() {
    final unread = _notifications.where((item) => !item.isRead).toList();
    for (final item in unread) {
      item.isRead = true;
    }
    notifyListeners();
    unawaited(_writeActivityBatch(unread, delete: false));
  }

  Future<void> deleteNotification(String notificationId) async {
    final index =
        _notifications.indexWhere((item) => item.id == notificationId);
    if (index == -1) return;
    final removed = _notifications.removeAt(index);
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      notifyListeners();
      return;
    }

    final deletionKey = '$userId/$notificationId';
    _pendingDeletionIds.add(deletionKey);
    notifyListeners();
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (error, stackTrace) {
      _notifications.insert(
        index.clamp(0, _notifications.length),
        removed,
      );
      notifyListeners();
      debugPrint('Unable to dismiss activity $notificationId: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      _pendingDeletionIds.remove(deletionKey);
    }
  }

  Future<void> reportNotification({
    required String notificationId,
    required String reason,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw StateError('Sign in before reporting activity.');
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .collection('reports')
        .doc(userId)
        .set({
      'reporterUid': userId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void updateNotificationData(
    String notificationId,
    Map<String, dynamic> newData,
  ) {
    final index =
        _notifications.indexWhere((item) => item.id == notificationId);
    if (index == -1) return;
    final current = _notifications[index];
    final mergedData = {...?current.data, ...newData};
    _notifications[index] = AppNotification(
      id: current.id,
      title: current.title,
      message: current.message,
      type: current.type,
      isRead: current.isRead,
      timestamp: current.timestamp,
      data: mergedData,
      relatedAccountId: current.relatedAccountId,
      relatedTransactionId: current.relatedTransactionId,
    );
    notifyListeners();
    unawaited(_updateActivity(notificationId, {'data': mergedData}));
  }

  void clearAll() {
    final toDelete = List<AppNotification>.of(_notifications);
    _notifications.clear();
    notifyListeners();
    unawaited(_writeActivityBatch(toDelete, delete: true));
  }

  Future<void> _updateActivity(
    String notificationId,
    Map<String, dynamic> values,
  ) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update(values);
    } catch (error, stackTrace) {
      debugPrint('Unable to update activity $notificationId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _writeActivityBatch(
    List<AppNotification> activities, {
    required bool delete,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || activities.isEmpty) return;
    final collection =
        _firestore.collection('users').doc(userId).collection('notifications');
    try {
      for (var offset = 0; offset < activities.length; offset += 450) {
        final end =
            offset + 450 < activities.length ? offset + 450 : activities.length;
        final batch = _firestore.batch();
        for (final activity in activities.sublist(offset, end)) {
          final ref = collection.doc(activity.id);
          if (delete) {
            batch.delete(ref);
          } else {
            batch.update(ref, {'isRead': true});
          }
        }
        await batch.commit();
      }
    } catch (error, stackTrace) {
      debugPrint(
          'Unable to ${delete ? 'dismiss' : 'mark read'} activities: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<PartyNotificationResult> notifyPartyByPhone({
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
    String? notificationId,
    bool isQuickBill = false,
    String? contractName,
    String? activityKind,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return PartyNotificationResult.notSignedIn;

    final phoneCandidates =
        Formatters.phoneNumberLookupCandidates(partyPhoneNumber);
    if (phoneCandidates.isEmpty) {
      return PartyNotificationResult.recipientNotFound;
    }

    try {
      QuerySnapshot<Map<String, dynamic>>? querySnapshot;
      for (final candidate in phoneCandidates) {
        final result = await _firestore
            .collection('public_profiles')
            .where('phoneNumber', isEqualTo: candidate)
            .limit(1)
            .get();
        if (result.docs.isNotEmpty) {
          querySnapshot = result;
          break;
        }
      }
      if (querySnapshot == null || querySnapshot.docs.isEmpty) {
        return PartyNotificationResult.recipientNotFound;
      }

      final recipient = querySnapshot.docs.first;
      if (recipient.id == currentUser.uid) {
        return PartyNotificationResult.sameUser;
      }
      final senderProfile = (await _firestore
                  .collection('public_profiles')
                  .doc(currentUser.uid)
                  .get())
              .data() ??
          <String, dynamic>{};
      final displayName = senderProfile['displayName']?.toString().trim() ?? '';
      final shopName = senderProfile['shopName']?.toString().trim() ?? '';
      final profileName = isQuickBill
          ? (shopName.isNotEmpty ? shopName : displayName)
          : (displayName.isNotEmpty ? displayName : shopName);
      final senderName = profileName.isNotEmpty
          ? profileName
          : currentUser.phoneNumber ?? 'User';
      final senderPhone = currentUser.phoneNumber ?? '';
      final id = notificationId ??
          (transactionId != null
              ? 'transaction_${currentUser.uid}_$transactionId'
              : DateTime.now().millisecondsSinceEpoch.toString());
      final isAutoMirroredWorkerPayment = referenceNumber
              ?.startsWith(model.Transaction.workerWagePaymentReference) ==
          true;
      final activity = AppNotification(
        id: id,
        title: 'Activity',
        message: 'A new ledger activity is available.',
        type: NotificationType.transaction,
        isRead: false,
        timestamp: DateTime.now(),
        data: {
          'amount': amount.toString(),
          'transactionType': transactionType,
          'category': category,
          'paymentMethod': paymentMethod,
          'senderName': senderName,
          'senderPhone': senderPhone,
          'senderUid': currentUser.uid,
          'senderPhotoUrl': senderProfile['photoURL'],
          'description': description ?? '',
          'items': items ?? [],
          'receivedAmount': (receivedAmount ?? 0).toString(),
          'pendingAmount': (pendingAmount ?? amount).toString(),
          'transactionId': transactionId ?? id,
          'transactionDate':
              (transactionDate ?? DateTime.now()).toIso8601String(),
          'referenceNumber': referenceNumber,
          'subtotal': (subtotal ?? amount).toString(),
          'discountAmount': (discountAmount ?? 0).toString(),
          'discountPercent': discountPercent?.toString(),
          'discountReason': discountReason,
          'isQuickBill': isQuickBill,
          'contractName': contractName,
          'activityKind': activityKind,
          if (!isAutoMirroredWorkerPayment) 'isAdded': false,
        },
      );

      await _firestore
          .collection('users')
          .doc(recipient.id)
          .collection('notifications')
          .doc(id)
          .set(activity.toMap(), SetOptions(merge: true));
      return PartyNotificationResult.savedToInbox;
    } catch (error, stackTrace) {
      debugPrint('Unable to create quiet activity for party: $error');
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<PartyNotificationResult> notifyWorkerAssignment({
    required String workerId,
    required String workerPhoneNumber,
    String? jobName,
    double? wageAmount,
    String? wageBasis,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return PartyNotificationResult.notSignedIn;
    final phoneCandidates =
        Formatters.phoneNumberLookupCandidates(workerPhoneNumber);
    if (phoneCandidates.isEmpty) {
      return PartyNotificationResult.recipientNotFound;
    }

    try {
      QuerySnapshot<Map<String, dynamic>>? recipientSnapshot;
      for (final candidate in phoneCandidates) {
        final result = await _firestore
            .collection('public_profiles')
            .where('phoneNumber', isEqualTo: candidate)
            .limit(1)
            .get();
        if (result.docs.isNotEmpty) {
          recipientSnapshot = result;
          break;
        }
      }
      if (recipientSnapshot == null || recipientSnapshot.docs.isEmpty) {
        return PartyNotificationResult.recipientNotFound;
      }
      final recipient = recipientSnapshot.docs.first;
      if (recipient.id == currentUser.uid) {
        return PartyNotificationResult.sameUser;
      }

      final senderProfile = (await _firestore
                  .collection('public_profiles')
                  .doc(currentUser.uid)
                  .get())
              .data() ??
          <String, dynamic>{};
      final senderName = (senderProfile['displayName'] ??
              senderProfile['shopName'] ??
              currentUser.phoneNumber ??
              'User')
          .toString()
          .trim();
      final stableWorkerId = workerId.replaceAll('/', '_');
      final activityId = 'worker_assignment_${currentUser.uid}_$stableWorkerId';
      final activityRef = _firestore
          .collection('users')
          .doc(recipient.id)
          .collection('notifications')
          .doc(activityId);
      if ((await activityRef.get()).exists) {
        return PartyNotificationResult.savedToInbox;
      }

      final activity = AppNotification(
        id: activityId,
        title: 'Activity',
        message: 'A worker assignment is available.',
        type: NotificationType.general,
        isRead: false,
        timestamp: DateTime.now(),
        data: {
          'activityKind': 'worker_assignment',
          'senderUid': currentUser.uid,
          'senderName': senderName,
          'senderPhone': currentUser.phoneNumber ?? '',
          'senderPhotoUrl': senderProfile['photoURL'],
          'workerId': workerId,
          'jobName': jobName,
          'wageAmount': wageAmount,
          'wageBasis': wageBasis,
        },
      );
      await activityRef.set(activity.toMap());
      return PartyNotificationResult.savedToInbox;
    } catch (error, stackTrace) {
      debugPrint(
          'Unable to add worker assignment to the activity feed: $error');
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<bool> enqueuePendingPartyNotification({
    required model.Transaction transaction,
    required String partyPhoneNumber,
    String? contractName,
    String? activityKind,
  }) async {
    final user = _auth.currentUser;
    if (user == null || partyPhoneNumber.trim().isEmpty) return false;
    try {
      final box = await _getPendingPartyNotificationsBox();
      final queueId = '${user.uid}_${transaction.id}';
      await box.put(queueId, {
        'senderUid': user.uid,
        'partyPhoneNumber': partyPhoneNumber,
        'transaction': transaction.toMap(),
        'contractName': contractName,
        'activityKind': activityKind,
      });
      unawaited(_processPendingPartyNotifications());
      return true;
    } catch (error, stackTrace) {
      debugPrint('Unable to queue quiet party activity: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<Box> _getPendingPartyNotificationsBox() async {
    if (Hive.isBoxOpen(_pendingPartyNotificationsBoxName)) {
      return Hive.box(_pendingPartyNotificationsBoxName);
    }
    return Hive.openBox(_pendingPartyNotificationsBoxName);
  }

  Future<void> _processPendingPartyNotifications() async {
    if (_isDisposed || _isProcessingPendingPartyNotifications) return;
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;
      final box = await _getPendingPartyNotificationsBox();
      _isProcessingPendingPartyNotifications = true;

      for (final key in box.keys.toList()) {
        final rawEntry = box.get(key);
        if (rawEntry is! Map) {
          await box.delete(key);
          continue;
        }
        final entry = Map<String, dynamic>.from(rawEntry);
        if (entry['senderUid'] != user.uid) continue;

        try {
          final transaction = model.Transaction.fromMap(
            Map<String, dynamic>.from(entry['transaction'] as Map),
          );
          final recipientPhone = entry['partyPhoneNumber'] as String? ?? '';
          if (recipientPhone.trim().isEmpty) {
            await box.delete(key);
            continue;
          }
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('transactions')
              .doc(transaction.id)
              .set(transaction.toMap(), SetOptions(merge: true))
              .timeout(const Duration(seconds: 8));
          if (_auth.currentUser?.uid != user.uid) continue;

          final result = await notifyPartyByPhone(
            partyPhoneNumber: recipientPhone,
            amount: transaction.amount,
            transactionType: transaction.type,
            category: transaction.category,
            paymentMethod: transaction.paymentMethod,
            description: transaction.description,
            items: transaction.items.map((item) => item.toMap()).toList(),
            receivedAmount: transaction.receivedAmount,
            pendingAmount: transaction.pendingAmount,
            transactionId: transaction.id,
            transactionDate: transaction.date,
            referenceNumber: transaction.referenceNumber,
            subtotal: transaction.subtotal,
            discountAmount: transaction.discountAmount,
            discountPercent: transaction.discountPercent,
            discountReason: transaction.discountReason,
            isQuickBill: transaction.isQuickBill,
            contractName: entry['contractName']?.toString(),
            activityKind: entry['activityKind']?.toString(),
          );
          if (result != PartyNotificationResult.notSignedIn) {
            await box.delete(key);
          }
        } catch (error, stackTrace) {
          debugPrint('Quiet party activity will retry: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to process queued party activities: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isProcessingPendingPartyNotifications = false;
    }
  }

  Future<void> sendReminderNotification({
    required String accountId,
    required String accountName,
    required double pendingAmount,
  }) async {}

  Future<void> sendReportNotification(String period) async {}
}
