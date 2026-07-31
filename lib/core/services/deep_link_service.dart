import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../../features/inventory/item_detail_screen.dart';
import '../../core/models/inventory_item_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void initDeepLinks(BuildContext context) async {
    // 1. Handle links when app is in background or foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (context.mounted) {
        _handleDeepLink(context, uri);
      }
    });

    // 2. Handle link when app is closed (initial link)
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null && context.mounted) {
      _handleDeepLink(context, initialUri);
    }
  }

  void _handleDeepLink(BuildContext context, Uri uri) async {
    debugPrint('Deep Link Received: $uri');
    
    // Pattern: accountapp.page.link/item/{id} or your custom domain
    if (uri.path.contains('/item/')) {
      final String itemId = uri.pathSegments.last;
      _navigateToProduct(context, itemId);
    }
  }

  Future<void> _navigateToProduct(BuildContext context, String itemId) async {
    try {
      // Show loading indicator if needed or just fetch
      final doc = await FirebaseFirestore.instance.collectionGroup('inventory_items')
          .where('id', isEqualTo: itemId).limit(1).get();
          
      if (doc.docs.isNotEmpty && context.mounted) {
        final item = InventoryItem.fromMap({...doc.docs.first.data(), 'id': doc.docs.first.id});
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
        );
      }
    } catch (e) {
      debugPrint("Deep link navigation error: $e");
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
