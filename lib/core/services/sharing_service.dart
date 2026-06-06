import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/shared_account_model.dart';
import 'dart:async'; // For Stream

class SharingService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper: مختلف فون نمبر فارمیٹس جنریٹ کریں
  List<String> _getPotentialPhoneNumbers(String phoneNumber) {
    String clean = phoneNumber.replaceAll(RegExp(r'\D'), '');
    List<String> formats = [];

    if (clean.startsWith('92')) {
      formats.add('+$clean');
      formats.add('0${clean.substring(2)}');
    } else if (clean.startsWith('03')) {
      formats.add(clean);
      formats.add('+92${clean.substring(1)}');
    } else if (clean.startsWith('3') && clean.length == 10) {
      formats.add('0$clean');
      formats.add('+92$clean');
    } else {
      formats.add(phoneNumber);
      formats.add('+$clean');
    }
    
    return formats.toSet().toList();
  }

  // Share account with another user
  Future<void> shareAccount({
    required String accountId,
    required String targetPhoneNumber,
    required List<String> permissions,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final potentialNumbers = _getPotentialPhoneNumbers(targetPhoneNumber);
      print("Sharing account $accountId. Checking potential numbers: $potentialNumbers");

      QuerySnapshot? targetUserSnapshot;
      String foundPhoneNumber = targetPhoneNumber;

      for (String phone in potentialNumbers) {
        final snapshot = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: phone)
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          targetUserSnapshot = snapshot;
          foundPhoneNumber = phone;
          break;
        }
      }

      if (targetUserSnapshot != null && targetUserSnapshot.docs.isNotEmpty) {
        print("User found in app with number: $foundPhoneNumber");
        await _shareWithAppUser(
          accountId: accountId,
          targetPhoneNumber: foundPhoneNumber,
          targetUserId: targetUserSnapshot.docs.first.id,
          permissions: permissions,
          user: user,
        );
      } else {
        print("User not found in app. Sending SMS invitation.");
        await _shareViaSMS(
          accountId: accountId,
          targetPhoneNumber: targetPhoneNumber,
          permissions: permissions,
          user: user,
        );
      }

      notifyListeners();
    } catch (e) {
      print("Sharing Error: $e");
      throw Exception('Sharing failed: $e');
    }
  }

  Future<void> _shareWithAppUser({
    required String accountId,
    required String targetPhoneNumber,
    required String targetUserId,
    required List<String> permissions,
    required User user,
  }) async {
    final accountDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .doc(accountId)
        .get();

    if (!accountDoc.exists) {
      throw Exception('Account not found');
    }

    final account = Account.fromMap(accountDoc.data()!);

    final sharedAccount = SharedAccount(
      id: '${accountId}_${user.uid}_$targetUserId',
      accountId: accountId,
      ownerId: user.uid,
      sharedWith: targetUserId,
      sharedWithPhone: targetPhoneNumber,
      permissions: permissions,
      sharedAt: DateTime.now(),
      isActive: true,
      accountName: account.name,
      currentBalance: account.balance,
      photoUrl: user.photoURL,
    );

    await _firestore
        .collection('shared_accounts')
        .doc(sharedAccount.id)
        .set(sharedAccount.toMap());

    // Copy existing transactions to the target user
    try {
      final transactionsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .where('accountId', isEqualTo: accountId)
          .get();

      final batch = _firestore.batch();
      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final newDocRef = _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('transactions')
            .doc(doc.id);
        
        batch.set(newDocRef, data);
      }
      await batch.commit();
      print("Transactions copied to shared user.");
    } catch (e) {
      print("Error copying transactions: $e");
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .doc(accountId)
        .update({
      'isShared': true,
      'sharedWith': FieldValue.arrayUnion([targetPhoneNumber]),
      'updatedAt': DateTime.now(),
    });

    await _sendShareNotification(accountId, targetUserId, account.name, senderPhotoUrl: user.photoURL);
  }

  Future<void> _shareViaSMS({
    required String accountId,
    required String targetPhoneNumber,
    required List<String> permissions,
    required User user,
  }) async {
    final accountDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .doc(accountId)
        .get();

    if (!accountDoc.exists) {
      throw Exception('Account not found');
    }

    final account = Account.fromMap(accountDoc.data()!);
    final shareLink = "https://yourapp.page.link/share?account=$accountId&owner=${user.uid}";
    final smsMessage = """
Assalam-o-Alaikum!
${user.phoneNumber ?? "A user"} ne aap ke sath "${account.name}" account share kiya hai.
Account Balance: RS ${account.balance.toStringAsFixed(0)}

App install karen aur account manage karein:
$shareLink
""";

    final potentialNumbers = _getPotentialPhoneNumbers(targetPhoneNumber);
    
    final pendingShare = {
      'accountId': accountId,
      'ownerId': user.uid,
      'ownerPhone': user.phoneNumber,
      'targetPhoneNumber': targetPhoneNumber,
      'potentialTargetNumbers': potentialNumbers,
      'permissions': permissions,
      'shareLink': shareLink,
      'sentAt': DateTime.now(),
      'status': 'pending',
      'accountName': account.name,
      'accountBalance': account.balance,
      'message': smsMessage,
    };

    final cleanPhone = targetPhoneNumber.replaceAll(RegExp(r'\D'), '');
    await _firestore
        .collection('pending_shares')
        .doc('${accountId}_${user.uid}_$cleanPhone')
        .set(pendingShare);

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .doc(accountId)
        .update({
      'isShared': true,
      'sharedWith': FieldValue.arrayUnion([targetPhoneNumber]),
      'updatedAt': DateTime.now(),
    });

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: targetPhoneNumber,
      queryParameters: {'body': smsMessage},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> checkPendingShares(String phoneNumber) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final potentialNumbers = _getPotentialPhoneNumbers(phoneNumber);
    
    for (String phone in potentialNumbers) {
         final snapshot = await _firestore
            .collection('pending_shares')
            .where('potentialTargetNumbers', arrayContains: phone)
            .where('status', isEqualTo: 'pending')
            .get();
            
         await _processPendingShares(snapshot, user, phoneNumber);
    }
  }
  
  Future<void> _processPendingShares(QuerySnapshot snapshot, User user, String currentPhone) async {
      for (var doc in snapshot.docs) {
      final pendingShare = doc.data() as Map<String, dynamic>;

      try {
        final sharedAccount = SharedAccount(
          id: '${pendingShare['accountId']}_${pendingShare['ownerId']}_${user.uid}',
          accountId: pendingShare['accountId'],
          ownerId: pendingShare['ownerId'],
          sharedWith: user.uid,
          sharedWithPhone: currentPhone,
          permissions: List<String>.from(pendingShare['permissions']),
          sharedAt: DateTime.now(),
          isActive: true,
          accountName: pendingShare['accountName'],
          currentBalance: pendingShare['accountBalance'],
          photoUrl: user.photoURL,
        );

        await _firestore
            .collection('shared_accounts')
            .doc(sharedAccount.id)
            .set(sharedAccount.toMap());

        // Copy existing transactions from owner to new user
        try {
          final transactionsSnapshot = await _firestore
              .collection('users')
              .doc(pendingShare['ownerId'])
              .collection('transactions')
              .where('accountId', isEqualTo: pendingShare['accountId'])
              .get();

          final batch = _firestore.batch();
          for (var tDoc in transactionsSnapshot.docs) {
             final tData = tDoc.data();
             final newDocRef = _firestore
                .collection('users')
                .doc(user.uid)
                .collection('transactions')
                .doc(tDoc.id);
             batch.set(newDocRef, tData);
          }
          await batch.commit();
          print("Transactions copied from owner to new user.");
        } catch (e) {
          print("Error copying transactions: $e");
        }

        await _firestore
            .collection('pending_shares')
            .doc(doc.id)
            .update({
          'status': 'completed',
          'activatedAt': DateTime.now(),
          'activatedBy': user.uid,
        });

        await _sendShareNotification(
          pendingShare['accountId'],
          pendingShare['ownerId'],
          'Share Accepted: ${pendingShare['accountName']}',
          isOwnerNotification: true,
          senderPhotoUrl: user.photoURL,
        );
      } catch (e) {
        print('Error activating pending share: $e');
      }
    }
  }

  Future<void> _sendShareNotification(
      String accountId,
      String targetUserId,
      String messageTitle,
      {bool isOwnerNotification = false, String? senderPhotoUrl}
      ) async {
    try {
        final targetUserDoc = await _firestore
            .collection('users')
            .doc(targetUserId)
            .get();

        if (targetUserDoc.exists) {
          final data = targetUserDoc.data();
          // Check if fcmToken exists, though we are writing to DB regardless for local notifications
          
          // Corrected Path: users/{userId}/notifications
          await _firestore
              .collection('users')
              .doc(targetUserId)
              .collection('notifications')
              .add({
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'title': isOwnerNotification ? 'Account Share Accepted' : 'New Shared Account',
                'message': isOwnerNotification 
                    ? 'Your invitation was accepted.' 
                    : 'An account has been shared with you: $messageTitle',
                'type': 'share',
                'timestamp': DateTime.now().toIso8601String(),
                'relatedAccountId': accountId,
                'isRead': false,
                'data': {
                  'accountId': accountId,
                  'action': isOwnerNotification ? 'accepted' : 'shared',
                  'senderPhotoUrl': senderPhotoUrl,
                },
              });
              
          print('Notification sent to user: $targetUserId');
        }
    } catch(e) {
        print("Error sending notification: $e");
    }
  }

  Stream<List<SharedAccount>> getSharedAccountsWithMe() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('shared_accounts')
        .where('sharedWith', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => SharedAccount.fromMap(doc.data()))
          .toList(),
    );
  }

  Stream<List<SharedAccount>> getSharedAccountsByMe() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('shared_accounts')
        .where('ownerId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => SharedAccount.fromMap(doc.data()))
          .toList(),
    );
  }

  Stream<List<SharedAccount>> getPendingSharesByMe() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('pending_shares')
        .where('ownerId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return SharedAccount(
              id: doc.id,
              accountId: data['accountId'],
              ownerId: data['ownerId'],
              sharedWith: 'Pending',
              sharedWithPhone: data['targetPhoneNumber'],
              permissions: List<String>.from(data['permissions']),
              sharedAt: (data['sentAt'] as Timestamp).toDate(),
              isActive: false,
              accountName: data['accountName'],
              currentBalance: (data['accountBalance'] as num?)?.toDouble(),
              photoUrl: null, // Photo might not be available for pending
            );
          }).toList(),
    );
  }

  Future<void> stopSharing(String sharedAccountId, {bool isPending = false}) async {
    if (isPending) {
       await _deletePendingShare(sharedAccountId);
    } else {
       await _deleteActiveShare(sharedAccountId);
    }
    notifyListeners();
  }
  
  Future<void> _deletePendingShare(String sharedAccountId) async {
    try {
        final pendingDoc = await _firestore.collection('pending_shares').doc(sharedAccountId).get();
        if (pendingDoc.exists) {
           final data = pendingDoc.data();
           await _firestore.collection('pending_shares').doc(sharedAccountId).delete();
           
           if (data != null) {
               try {
                 await _firestore
                  .collection('users')
                  .doc(data['ownerId'])
                  .collection('accounts')
                  .doc(data['accountId'])
                  .update({
                    'sharedWith': FieldValue.arrayRemove([data['targetPhoneNumber']]),
                    'updatedAt': DateTime.now(),
                  });
               } catch (e) {
                   print("Error updating owner account for pending share deletion: $e");
               }
           }
        } else {
          // If document doesn't exist but we are here, just ensure UI cleans up or ignore
           print("Pending share doc not found: $sharedAccountId");
        }
      } catch (e) {
         print("Error deleting pending share: $e");
         throw e;
      }
  }

  Future<void> _deleteActiveShare(String sharedAccountId) async {
    DocumentSnapshot? sharedAccountDoc;
    try {
      sharedAccountDoc = await _firestore
          .collection('shared_accounts')
          .doc(sharedAccountId)
          .get();
    } catch (e) {
      print("stopSharing: Error fetching from shared_accounts: $e");
    }

    if (sharedAccountDoc != null && sharedAccountDoc.exists) {
      final sharedAccount = SharedAccount.fromMap(sharedAccountDoc.data() as Map<String, dynamic>);
      await _firestore
          .collection('shared_accounts')
          .doc(sharedAccountId)
          .update({'isActive': false, 'updatedAt': DateTime.now()});

      await _firestore
          .collection('users')
          .doc(sharedAccount.ownerId)
          .collection('accounts')
          .doc(sharedAccount.accountId)
          .update({
        'sharedWith': FieldValue.arrayRemove([sharedAccount.sharedWithPhone]),
        'updatedAt': DateTime.now(),
      });
    } else {
        // Fallback: Check pending if not found in active (just in case flag was wrong or ID confusion)
        // But with explicit flag, we might not need this unless we want to be super safe
        await _deletePendingShare(sharedAccountId);
    }
  }

  Future<void> markAsSeen(String sharedAccountId) async {
    final user = _auth.currentUser;
    if (user == null) return; // Not logged in

    try {
      await _firestore
          .collection('shared_accounts')
          .doc(sharedAccountId)
          .update({
        'lastViewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error marking account as seen: $e");
      // Handle error silently, as this is not a critical user-facing action
    }
  }
}
