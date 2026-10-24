import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
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
    
    // یہاں مزید ڈیپ لنکس ہینڈل کیے جا سکتے ہیں (مثلاً کاریگر پروفائل وغیرہ)
  }


  void dispose() {
    _linkSubscription?.cancel();
  }
}
