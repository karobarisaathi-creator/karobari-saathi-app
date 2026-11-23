import 'package:account_app/features/marketplace/models/marketplace_listing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marketplace listing preserves editable and contact fields', () {
    final createdAt = DateTime(2026, 12, 4, 10, 30);
    final listing = MarketplaceListing(
      id: 'listing-1',
      ownerId: 'seller-1',
      sellerName: 'Ayesha',
      phoneNumber: '+923001234567',
      phoneShared: true,
      title: 'Used sewing machine',
      description: 'Works well.',
      category: 'home',
      condition: 'used',
      area: 'Lahore',
      price: 25000,
      isNegotiable: true,
      imageUrls: const ['https://example.test/photo.jpg'],
      imagePaths: const ['marketplace/seller-1/listing-1/photo.jpg'],
      status: 'active',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final restored = MarketplaceListing.fromMap(
      listing.id,
      listing.toMap(),
    );

    expect(restored.ownerId, listing.ownerId);
    expect(restored.phoneNumber, listing.phoneNumber);
    expect(restored.phoneShared, isTrue);
    expect(restored.price, listing.price);
    expect(restored.imageUrls, listing.imageUrls);
    expect(restored.imagePaths, listing.imagePaths);
    expect(restored.createdAt, createdAt);
    expect(restored.isActive, isTrue);
  });

  test('reads Firestore timestamps and tolerates missing optional fields', () {
    final createdAt = DateTime(2026, 12, 4, 10, 30);
    final listing = MarketplaceListing.fromMap('legacy', {
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(createdAt),
      'price': 0,
      'imageUrls': ['https://example.test/item.jpg'],
    });

    expect(listing.id, 'legacy');
    expect(listing.createdAt, createdAt);
    expect(listing.price, 0);
    expect(listing.phoneShared, isFalse);
    expect(listing.status, 'active');
  });
}
