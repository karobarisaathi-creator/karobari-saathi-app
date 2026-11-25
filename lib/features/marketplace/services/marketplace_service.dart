import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/marketplace_listing.dart';

class MarketplaceListingPage {
  const MarketplaceListingPage({
    required this.listings,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<MarketplaceListing> listings;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class MarketplaceService {
  MarketplaceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection('marketplace_listings');

  static const int activeListingPageSize = 20;

  Query<Map<String, dynamic>> _activeListingsQuery() => _listings
      .where('status', isEqualTo: 'active')
      .orderBy('createdAt', descending: true);

  Stream<MarketplaceListingPage> watchFirstActiveListingsPage({
    int pageSize = activeListingPageSize,
  }) =>
      _activeListingsQuery()
          .limit(pageSize)
          .snapshots()
          .map((snapshot) => _mapListingPage(snapshot, pageSize));

  Future<MarketplaceListingPage> fetchNextActiveListingsPage({
    required QueryDocumentSnapshot<Map<String, dynamic>> after,
    int pageSize = activeListingPageSize,
  }) async {
    final snapshot = await _activeListingsQuery()
        .startAfterDocument(after)
        .limit(pageSize)
        .get();
    return _mapListingPage(snapshot, pageSize);
  }

  Stream<List<MarketplaceListing>> watchMyListings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return Stream.error(StateError('Sign in to use the marketplace.'));
    }
    return _listings
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map(_mapAndSortListings);
  }

  Stream<MarketplaceListing?> watchListing(String listingId) {
    _requireUserId();
    return _listings.doc(listingId).snapshots().map(
          (document) => document.exists
              ? MarketplaceListing.fromMap(
                  document.id,
                  document.data()!,
                )
              : null,
        );
  }

  List<MarketplaceListing> _mapAndSortListings(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((document) =>
            MarketplaceListing.fromMap(document.id, document.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  MarketplaceListingPage _mapListingPage(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int pageSize,
  ) {
    return MarketplaceListingPage(
      listings: snapshot.docs
          .map((document) =>
              MarketplaceListing.fromMap(document.id, document.data()))
          .toList(),
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  Future<MarketplaceListing> saveListing({
    required MarketplaceListing listing,
    required List<File> newImages,
    List<String> removedImagePaths = const [],
  }) async {
    final userId = _requireUserId();
    if (listing.id.isNotEmpty && listing.ownerId != userId) {
      throw StateError('You can only edit your own marketplace listing.');
    }

    final isNew = listing.id.isEmpty;
    final document = isNew ? _listings.doc() : _listings.doc(listing.id);
    final uploadedUrls = <String>[];
    final uploadedPaths = <String>[];
    final imageUrls = [...listing.imageUrls];
    final imagePaths = [...listing.imagePaths];

    if (imageUrls.length + newImages.length > 5) {
      throw ArgumentError('A listing can have no more than five photos.');
    }

    late final MarketplaceListing savedListing;
    try {
      for (var index = 0; index < newImages.length; index++) {
        final file = newImages[index];
        if (!await file.exists()) {
          throw FileSystemException(
            'The selected photo is unavailable.',
            file.path,
          );
        }

        final extension = file.path.split('.').last.toLowerCase();
        final contentType = switch (extension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ =>
            throw ArgumentError('Only JPG, PNG, and WebP photos are allowed.'),
        };
        final path =
            'marketplace/$userId/${document.id}/${DateTime.now().microsecondsSinceEpoch}_$index.$extension';
        final imageRef = _storage.ref(path);
        await imageRef.putFile(
          file,
          SettableMetadata(contentType: contentType),
        );
        uploadedPaths.add(path);
        uploadedUrls.add(await imageRef.getDownloadURL());
      }

      imageUrls.addAll(uploadedUrls);
      imagePaths.addAll(uploadedPaths);
      if (imageUrls.length != imagePaths.length) {
        throw ArgumentError('Listing photo URLs and paths must match.');
      }

      final now = DateTime.now();
      savedListing = listing.copyWith(
        id: document.id,
        ownerId: userId,
        imageUrls: imageUrls,
        imagePaths: imagePaths,
        status: isNew ? 'active' : listing.status,
        createdAt: isNew ? now : listing.createdAt,
        updatedAt: now,
      );
      final data = savedListing.toMap()
        ..['updatedAt'] = FieldValue.serverTimestamp();
      if (isNew) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      if (isNew) {
        await document.set(data);
      } else {
        data.remove('createdAt');
        await document.update(data);
      }
    } catch (error, stackTrace) {
      await _deleteImages(uploadedPaths);
      Error.throwWithStackTrace(error, stackTrace);
    }

    await _deleteImages(removedImagePaths);
    return savedListing;
  }

  Future<void> updateStatus(String listingId, String status) async {
    if (!const {'active', 'sold', 'hidden'}.contains(status)) {
      throw ArgumentError.value(
          status, 'status', 'Unsupported listing status.');
    }
    _requireUserId();
    await _listings.doc(listingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteListing(MarketplaceListing listing) async {
    final userId = _requireUserId();
    if (listing.ownerId != userId) {
      throw StateError('You can only delete your own marketplace listing.');
    }
    await _listings.doc(listing.id).delete();
    await _deleteImages(listing.imagePaths);
  }

  Future<void> reportListing({
    required String listingId,
    required String reason,
  }) async {
    final userId = _requireUserId();
    if (reason.trim().isEmpty || reason.trim().length > 500) {
      throw ArgumentError.value(
          reason, 'reason', 'Enter a valid report reason.');
    }
    await _listings.doc(listingId).collection('reports').doc(userId).set({
      'reporterId': userId,
      'reason': reason.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _requireUserId() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in to use the marketplace.');
    }
    return userId;
  }

  Future<void> _deleteImages(List<String> storagePaths) async {
    for (final path in storagePaths) {
      try {
        await _storage.ref(path).delete();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'marketplace storage',
            context: ErrorDescription('while deleting listing photo $path'),
          ),
        );
      }
    }
  }
}
