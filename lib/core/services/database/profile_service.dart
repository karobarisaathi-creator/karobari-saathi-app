import 'base_service.dart';

class ProfileService extends BaseService {
  Future<Map<String, String>?> findPublicProfileByPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final potentials = <String>[];

    if (clean.startsWith('92')) {
      potentials.add('+$clean');
      potentials.add('0${clean.substring(2)}');
    } else if (clean.startsWith('03')) {
      potentials.add(clean);
      potentials.add('+92${clean.substring(1)}');
    } else if (clean.startsWith('3') && clean.length == 10) {
      potentials.add('+92$clean');
      potentials.add('0$clean');
    } else {
      potentials.add(phone);
      if (phone.startsWith('+')) {
        potentials.add(phone.substring(1));
      } else {
        potentials.add('+$phone');
      }
    }

    for (final p in potentials) {
      final query = await firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: p)
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
            final shopDoc = await firestore.collection('public_shops').doc(uid).get();
            if (shopDoc.exists) {
              final shopData = shopDoc.data();
              if (shopData != null) {
                addr = (shopData['businessAddress'] ?? shopData['address'] ?? shopData['location'] ?? '').toString();
              }
            }
          } catch (_) {}
        }

        return {
          'uid': uid,
          'name': (data['displayName'] ?? data['name'] ?? '').toString(),
          'photoUrl': (data['photoURL'] ??
              data['photoUrl'] ??
              data['profileImage'] ??
              '').toString(),
          'profession': (data['profession'] ?? data['category'] ?? data['shopName'] ?? '').toString(),
          'address': addr,
        };
      }
    }

    return null;
  }

  Future<Map<String, String>?> findPublicProfileByUid(String uid) async {
    final localAccount = accountsBox?.get(uid);
    if (localAccount != null) {
      return {
        'uid': localAccount.id,
        'name': localAccount.name,
        'photoUrl': localAccount.profileImage ?? '',
        'phone': localAccount.phone,
        'address': localAccount.address ?? '',
      };
    }

    final doc = await firestore.collection('users').doc(uid).get();
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
          final shopDoc = await firestore.collection('public_shops').doc(uid).get();
          if (shopDoc.exists) {
            final shopData = shopDoc.data();
            if (shopData != null) {
              addr = (shopData['businessAddress'] ?? shopData['address'] ?? shopData['location'] ?? '').toString();
            }
          }
        } catch (_) {}
      }

      return {
        'uid': uid,
        'name': (data['displayName'] ?? data['name'] ?? '').toString(),
        'photoUrl':
            (data['photoURL'] ?? data['photoUrl'] ?? data['profileImage'] ?? '').toString(),
        'phone': (data['phoneNumber'] ?? '').toString(),
        'profession': (data['profession'] ?? data['category'] ?? data['shopName'] ?? '').toString(),
        'address': addr,
      };
    }
    return null;
  }
}
