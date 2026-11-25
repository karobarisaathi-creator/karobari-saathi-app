import 'base_service.dart';
import 'package:account_app/core/utils/formatters.dart';

class ProfileService extends BaseService {
  static final Map<String, Map<String, String>> _profileCacheMap = {};

  static void clearCache() => _profileCacheMap.clear();

  static Map<String, dynamic> publicProfileData({
    required String uid,
    required Map<String, dynamic> userData,
    required String? verifiedPhoneNumber,
  }) {
    final profile = <String, dynamic>{
      'uid': uid,
      'phoneNumber': verifiedPhoneNumber,
      'displayName': userData['displayName'] ?? userData['name'],
      'photoURL': userData['photoURL'] ?? userData['photoUrl'],
      'profession': userData['profession'],
      'businessAddress': userData['address'] ??
          userData['businessAddress'] ??
          userData['shopAddress'] ??
          userData['storeAddress'] ??
          userData['location'],
      'shopName': userData['shopName'] ?? userData['storeName'],
    };
    profile.removeWhere((key, value) => value == null);
    return profile;
  }

  Future<Map<String, String>?> findPublicProfileByPhone(String phone) async {
    for (final candidate in Formatters.phoneNumberLookupCandidates(phone)) {
      final query = await firestore
          .collection('public_profiles')
          .where('phoneNumber', isEqualTo: candidate)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        final uid = query.docs.first.id;

        String addr = (data['businessAddress'] ??
                data['address'] ??
                data['shopAddress'] ??
                data['storeAddress'] ??
                data['location'] ??
                '')
            .toString();

        if (addr.isEmpty) {
          try {
            final shopDoc =
                await firestore.collection('public_shops').doc(uid).get();
            if (shopDoc.exists) {
              final shopData = shopDoc.data();
              if (shopData != null) {
                addr = (shopData['businessAddress'] ??
                        shopData['address'] ??
                        shopData['location'] ??
                        '')
                    .toString();
              }
            }
          } catch (_) {}
        }

        final res = {
          'uid': uid,
          'name': (data['displayName'] ?? data['name'] ?? '').toString(),
          'photoUrl': (data['photoURL'] ??
                  data['photoUrl'] ??
                  data['profileImage'] ??
                  '')
              .toString(),
          'profession': (data['profession'] ?? '').toString(),
          'address': addr,
        };

        _profileCacheMap[uid] = res;
        return res;
      }
    }

    return null;
  }

  Future<Map<String, String>?> findPublicProfileByUid(String uid) async {
    if (_profileCacheMap.containsKey(uid)) {
      return _profileCacheMap[uid];
    }

    final localAccount = accountsBox?.get(uid);
    if (localAccount != null) {
      final res = {
        'uid': localAccount.id,
        'name': localAccount.name,
        'photoUrl': localAccount.profileImage ?? '',
        'phone': localAccount.phone,
        'profession': localAccount.profession ?? '',
        'address': localAccount.address ?? '',
      };
      _profileCacheMap[uid] = res;
      return res;
    }

    final doc = await firestore.collection('public_profiles').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      String addr = (data['businessAddress'] ??
              data['address'] ??
              data['shopAddress'] ??
              data['storeAddress'] ??
              data['location'] ??
              '')
          .toString();

      if (addr.isEmpty) {
        try {
          final shopDoc =
              await firestore.collection('public_shops').doc(uid).get();
          if (shopDoc.exists) {
            final shopData = shopDoc.data();
            if (shopData != null) {
              addr = (shopData['businessAddress'] ??
                      shopData['address'] ??
                      shopData['location'] ??
                      '')
                  .toString();
            }
          }
        } catch (_) {}
      }

      final res = {
        'uid': uid,
        'name': (data['displayName'] ?? data['name'] ?? '').toString(),
        'photoUrl':
            (data['photoURL'] ?? data['photoUrl'] ?? data['profileImage'] ?? '')
                .toString(),
        'phone': (data['phoneNumber'] ?? '').toString(),
        'profession': (data['profession'] ?? '').toString(),
        'address': addr,
      };

      _profileCacheMap[uid] = res;
      return res;
    }
    return null;
  }
}
