import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide GeoPoint;
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/services/ai_visual_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/price_database_service.dart';
import '../../core/services/usage_limit_service.dart';
import '../../core/models/price_alert_model.dart';
import '../../core/widgets/search_sort_bar.dart';
import '../../core/models/inventory_item_model.dart';

import 'widgets/shimmer_card.dart';
import 'widgets/result_card.dart';
import 'widgets/local_seller_card.dart';
import 'widgets/history_card.dart';

import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VisualFinderScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const VisualFinderScreen({super.key, this.initialSearchQuery});

  @override
  State<VisualFinderScreen> createState() => _VisualFinderScreenState();
}

class _VisualFinderScreenState extends State<VisualFinderScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final AIVisualService _aiService = AIVisualService();
  final UsageLimitService _limitService = UsageLimitService();

  File? _image;
  bool _isAnalyzing = false;
  Map<String, String>? _result;
  List<Map<String, String>> _history = [];
  List<InventoryItem> _localSellers = [];
  bool _isTracked = false;
  bool _searchFailed = false;
  Position? _currentPosition;
  Map<String, dynamic>? _limitInfo;
  late AnimationController _shimmerController;
  Timer? _searchDebounce;

  final TextEditingController _searchController = TextEditingController();

  String _getFont(String? text, bool isAppUrdu) {
    if (!isAppUrdu || text == null || text.isEmpty) return '';
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'NooriNastaleeq' : '';
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _determinePosition();
    _loadHistory();
    _loadLimits();
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
      _performTextSearch(widget.initialSearchQuery!);
    }
  }

  Future<void> _loadLimits() async {
    final info = await _limitService.getRemainingLimits();
    if (mounted) setState(() => _limitInfo = info);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _currentPosition = await Geolocator.getCurrentPosition();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  String _calculateDistance(String? locationStr) {
    if (_currentPosition == null || locationStr == null || locationStr.isEmpty) return "";
    try {
      final parts = locationStr.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          double distanceInMeters = Geolocator.distanceBetween(
            _currentPosition!.latitude, 
            _currentPosition!.longitude, 
            lat, 
            lng
          );
          double km = distanceInMeters / 1000;
          return km < 1 ? "${(distanceInMeters).toStringAsFixed(0)} m" : "${km.toStringAsFixed(1)} km";
        }
      }
    } catch (e) {
      debugPrint("Distance calculation error: $e");
    }
    return "";
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('deal_finder_history');
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        if (mounted) {
          setState(() {
            _history = decoded.map((item) => Map<String, String>.from(item)).toList();
          });
        }
      } catch (e) {
        debugPrint("Error loading history: $e");
      }
    }
  }

  Future<void> _saveToHistory(Map<String, String> result) async {
    final prefs = await SharedPreferences.getInstance();
    _history.removeWhere((item) => item['name'] == result['name']);
    _history.insert(0, result);
    if (_history.length > 10) _history.removeLast();
    await prefs.setString('deal_finder_history', jsonEncode(_history));
    if (mounted) setState(() {});
  }

  Future<void> _searchLocalAppInventory(String query) async {
    if (query.isEmpty) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final results = await db.searchGlobalInventory(query);
    results.sort((a, b) => a.defaultRate.compareTo(b.defaultRate));
    if (mounted) {
      setState(() {
        _localSellers = results;
      });
    }
  }

  Future<void> _performTextSearch(String query) async {
    if (query.trim().isEmpty) return;

    final limitCheck = await _limitService.canSearch();
    if (!limitCheck['allowed']) {
      _showError(limitCheck['message']);
      _showUpgradeDialog();
      return;
    }
    
    setState(() {
      _isAnalyzing = true;
      _result = null;
      _image = null;
      _localSellers = [];
      _searchFailed = false;
    });

    await _searchLocalAppInventory(query);
    final result = await _aiService.searchProductByText(query);

    if (mounted) {
      setState(() => _isAnalyzing = false);
      final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

      if (result.isSuccess) {
        final data = result.data!;
        setState(() => _result = data);
        _saveToHistory(data);
        await _limitService.incrementSearch();
        _loadLimits();
        final betterName = data['name']?.split(' ').take(2).join(' ') ?? query;
        await _searchLocalAppInventory(betterName);
      } else {
        String msg = isUrdu ? "سرور مصروف ہے، ہم مقامی نتائج دکھا رہے ہیں۔" : "Server is busy, showing local results.";
        
        if (result.error == AIErrorType.timeout) {
          msg = isUrdu ? "انٹرنیٹ سست ہے، دوبارہ کوشش کریں۔" : "Connection slow, please try again.";
        } else if (result.error == AIErrorType.payment) {
          msg = isUrdu ? "اے پی آئی بیلنس ختم ہو گیا ہے" : "API balance exhausted";
        } else if (result.error == AIErrorType.quota) {
          msg = isUrdu ? "سروس کی حد ختم ہو گئی ہے" : "Service quota exceeded";
        }
        
        _showError(msg);
        if (_localSellers.isEmpty) _searchFailed = true;
      }
    }
  }

  Future<void> _handleScanResult(dynamic scanData) async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    if (scanData is String) {
      _performTextSearch(scanData);
    } else if (scanData is File) {
      final limitCheck = await _limitService.canScan();
      if (!limitCheck['allowed']) {
        _showError(limitCheck['message']);
        _showUpgradeDialog();
        return;
      }

      setState(() {
        _image = scanData;
        _isAnalyzing = true;
        _result = null;
        _localSellers = [];
        _searchFailed = false;
      });
      
      final result = await _aiService.analyzeProductImage(_image!);
      
      if (mounted) {
        setState(() => _isAnalyzing = false);
        
        if (result.isSuccess) {
          final data = result.data!;
          setState(() => _result = data);
          _saveToHistory(data);
          await _limitService.incrementScan();
          _loadLimits();
          _searchLocalAppInventory(data['name']!);
        } else {
          String msg = isUrdu ? "شناخت میں دشواری، دوبارہ کوشش کریں" : "Failed to identify, please try again.";
          
          if (result.error == AIErrorType.timeout) {
            msg = isUrdu ? "انٹرنیٹ سست ہے، دوبارہ کوشش کریں۔" : "Connection slow, please try again.";
          } else if (result.error == AIErrorType.quota) {
            msg = isUrdu ? "سروس کی حد ختم ہو گئی ہے" : "Service quota exceeded";
          }
          
          _showError(msg);
          if (_localSellers.isEmpty) _searchFailed = true;
        }
      }
    }
  }

  void _openSmartScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SmartScannerPage()),
    );
    if (result != null) {
      _handleScanResult(result);
    }
  }

  void _pickFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      _handleScanResult(File(pickedFile.path));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(fontFamily: _getFont(message, true)))),
    );
  }

  Future<void> _togglePriceAlert(bool val) async {
    if (_result == null) return;
    setState(() => _isTracked = val);
    if (val) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final priceDb = Provider.of<PriceDatabaseService>(context, listen: false);
      final targetPrice = double.tryParse(_result!['price']!.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      final existingDeal = await priceDb.checkMarketplaceForDeal(_result!['name']!, targetPrice);
      if (existingDeal != null && mounted) {
        _showExistingDealDialog(existingDeal);
        setState(() => _isTracked = false);
        return;
      }
      final productId = _result!['name']!.toLowerCase().replaceAll(' ', '_');
      final alert = PriceAlert(
        id: const Uuid().v4(),
        userId: user.uid,
        productName: _result!['name']!,
        productId: productId,
        targetPrice: targetPrice,
        currentPrice: targetPrice,
        createdAt: DateTime.now(),
      );
      try {
        await priceDb.setPriceAlert(alert);
        if (mounted) {
          final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
          _showError(isUrdu ? "قیمت مانیٹرنگ شروع کر دی گئی ہے" : "Price monitoring started");
        }
      } catch (e) {
        debugPrint("Alert error: $e");
      }
    }
  }

  void _showExistingDealDialog(InventoryItem item) {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.themeColor.withValues(alpha: 0.3))),
        title: Text(isUrdu ? "بہترین ڈیل مل گئی!" : "Deal Already Exists!", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUrdu ? "آپ کی پسندیدہ قیمت پر یہ آئٹم پہلے ہی مارکیٹ میں دستیاب ہے۔" : "This item is already available at your target price.",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            LocalSellerCard(item: item, isUrdu: isUrdu, distance: _calculateDistance(item.location), getFont: _getFont),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isUrdu ? "ٹھیک ہے" : "Got it", style: const TextStyle(color: AppTheme.themeColor))),
        ],
      ),
    );
  }

  void _searchOnline(String platform) async {
    if (_result == null) return;
    String query = _result!['name']!;
    String url = "";
    
    switch (platform) {
      case "WhatMobile": url = "https://www.whatmobile.com.pk/search.php?q=${Uri.encodeComponent(query)}"; break;
      case "Daraz": url = "https://www.daraz.pk/catalog/?q=${Uri.encodeComponent(query)}"; break;
      case "PriceOye": url = "https://priceoye.pk/search?q=${Uri.encodeComponent(query)}"; break;
      case "OLX": url = "https://www.olx.com.pk/items/q-${Uri.encodeComponent(query)}"; break;
      case "PakWheels": url = "https://www.pakwheels.com/used-cars/search/-/?q=${Uri.encodeComponent(query)}"; break;
      case "Zameen": url = "https://www.zameen.com/search?q=${Uri.encodeComponent(query)}"; break;
      case "Google": url = "https://www.google.com/search?q=${Uri.encodeComponent(query + " price in Pakistan")}"; break;
    }

    if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showUpgradeDialog() {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isUrdu ? "پریمیم میں اپ گریڈ کریں" : "Upgrade to Premium", style: const TextStyle(color: Colors.white)),
        content: Text(
          isUrdu 
            ? "فری سرچ کی حد ختم ہو گئی ہے۔ تمام حدود ختم کرنے کے لیے پریمیم پلان حاصل کریں۔" 
            : "Free search limit reached. Get premium to remove all limits.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isUrdu ? "بعد میں" : "Later", style: const TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to payment or premium screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.themeColor),
            child: Text(isUrdu ? "پلان دیکھیں" : "View Plans"),
          ),
        ],
      ),
    );
  }

  // App Bar میں Limits دکھانے کے لیے
  Widget _buildLimitIndicator(bool isUrdu, String fontFamily) {
    if (_limitInfo == null) return const SizedBox.shrink();
    if (_limitInfo!['isPremium'] == true) return const SizedBox.shrink();

    final dailyRemaining = _limitInfo!['dailyRemaining'];
    final scansRemaining = _limitInfo!['scansRemaining'];
    
    Color getColor(dynamic remaining) {
      if (remaining is String) return Colors.green;
      if (remaining > 3) return Colors.green;
      if (remaining > 1) return Colors.orange;
      return Colors.red;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.magnifyingGlass(), size: 14, color: getColor(dailyRemaining)),
              const SizedBox(width: 4),
              Text("$dailyRemaining", style: TextStyle(fontWeight: FontWeight.bold, color: getColor(dailyRemaining))),
              const SizedBox(width: 12),
              Icon(PhosphorIcons.camera(), size: 14, color: getColor(scansRemaining)),
              const SizedBox(width: 4),
              Text("$scansRemaining", style: TextStyle(fontWeight: FontWeight.bold, color: getColor(scansRemaining))),
            ],
          ),
          TextButton(
            onPressed: _showUpgradeDialog,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            child: Text(
              isUrdu ? "اپ گریڈ" : "Upgrade",
              style: const TextStyle(color: AppTheme.themeColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: isUrdu ? "ڈیل فائنڈر" : "Business Agent Finder", showBackButton: canPop),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            _buildLimitIndicator(isUrdu, fontFamily),
            const SizedBox(height: 16),
            _buildSearchBar(isUrdu, fontFamily),
            Expanded(
              child: _isAnalyzing 
                ? VisualShimmerCard(animation: _shimmerController, isUrdu: isUrdu, fontFamily: fontFamily)
                : (_result != null || _localSellers.isNotEmpty)
                    ? _buildResultView(isUrdu, fontFamily)
                    : _searchFailed
                        ? _buildErrorView(isUrdu, fontFamily)
                        : _buildHomeView(isUrdu, fontFamily),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isUrdu, String fontFamily) {
    return SearchSortBar(
      controller: _searchController,
      hintText: isUrdu ? "نام لکھیں یا اسکین کریں..." : "Type name or scan...",
      padding: EdgeInsets.zero,
      onSearchChanged: (val) {
        if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 500), () {
          if (val.length >= 2) {
            _searchLocalAppInventory(val);
          } else if (val.isEmpty) {
            setState(() {
              _localSellers = [];
              _result = null;
            });
          }
        });
      },
      onSubmitted: (val) { if (val.isNotEmpty) _performTextSearch(val); },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: _pickFromGallery, icon: Icon(PhosphorIcons.image(), color: AppTheme.themeColor, size: 22), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _openSmartScanner,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.themeColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.themeColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Icon(PhosphorIcons.scan(), color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeView(bool isUrdu, String fontFamily) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(PhosphorIcons.scan(PhosphorIconsStyle.fill), size: 80, color: AppTheme.darkColor.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          Text(isUrdu ? "کاروباری ایجنٹ سکینر" : "Business Agent Scanner", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.darkColor, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
          const SizedBox(height: 10),
          Text(isUrdu ? "بہترین ڈیلز تلاش کرنے کے لیے تصویر لیں یا بارکوڈ اسکین کریں۔" : "Take a photo or scan barcode to find the best deals.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.darkColor.withValues(alpha: 0.6), fontSize: 16, fontFamily: fontFamily)),
          const SizedBox(height: 60),
          if (_history.isNotEmpty) ...[
            Align(alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft, child: Text(isUrdu ? "حالیہ تلاشیں:" : "Recent Scans:", style: TextStyle(color: AppTheme.darkColor.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: fontFamily))),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  return HistoryCard(item: _history[index], isUrdu: isUrdu, getFont: _getFont, onTap: () {
                    setState(() { _result = _history[index]; _localSellers = []; });
                    _searchLocalAppInventory(_history[index]['name']!);
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultView(bool isUrdu, String fontFamily) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          if (_result != null) ...[ 
            VisualResultCard(
              result: _result!, 
              image: _image, 
              isTracked: _isTracked, 
              onTrackChanged: _togglePriceAlert, 
              getFont: _getFont, 
              isUrdu: isUrdu, 
              fontFamily: fontFamily
            ),
            const SizedBox(height: 16),
            Text(isUrdu ? "آن لائن قیمتیں چیک کریں:" : "Check Online Prices:", style: TextStyle(color: AppTheme.darkColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal, 
              child: Row(children: _getPlatformButtons())
            ),
            const SizedBox(height: 24) 
          ],
          if (_localSellers.isNotEmpty) ...[
            Text(isUrdu ? "قریبی دکانوں پر دستیاب:" : "Available at Local Shops:", style: TextStyle(color: AppTheme.darkColor, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
            const SizedBox(height: 12),
            ..._localSellers.map((item) => LocalSellerCard(item: item, isUrdu: isUrdu, distance: _calculateDistance(item.location), getFont: _getFont)),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 30),
          TextButton(onPressed: () => setState(() { _result = null; _image = null; _localSellers = []; _searchFailed = false; }), child: Center(child: Text(isUrdu ? "واپس ہوم پر جائیں" : "Go Back to Home", style: TextStyle(color: AppTheme.darkColor.withValues(alpha: 0.5), fontFamily: fontFamily)))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Widget> _getPlatformButtons() {
    if (_result == null) return [];
    List<String> platforms = [];
    String cat = (_result!['category'] ?? "").toLowerCase();
    
    if (cat.contains("mobile")) {
      platforms = ["WhatMobile", "PriceOye", "Daraz", "OLX"];
    } else if (cat.contains("electron")) {
      platforms = ["PriceOye", "Daraz", "OLX", "Google"];
    } else if (cat.contains("vehicle") || cat.contains("car") || cat.contains("bike")) {
      platforms = ["PakWheels", "OLX", "Google"];
    } else if (cat.contains("estate") || cat.contains("property")) {
      platforms = ["Zameen", "OLX", "Google"];
    } else {
      platforms = ["Daraz", "OLX", "Google"];
    }

    return platforms.map((p) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(p, style: const TextStyle(fontSize: 12, color: Colors.white)),
        backgroundColor: AppTheme.themeColor.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () => _searchOnline(p),
      ),
    )).toList();
  }

  Widget _buildErrorView(bool isUrdu, String fontFamily) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(PhosphorIcons.smileySad(), color: AppTheme.darkColor.withValues(alpha: 0.3), size: 85),
        const SizedBox(height: 24),
        Text(isUrdu ? "معذرت، کوئی نتیجہ نہیں ملا" : "Sorry, no results found", style: TextStyle(color: AppTheme.darkColor, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
        const SizedBox(height: 10),
        Text(isUrdu ? "ہم اس پروڈکٹ کی تفصیلات تلاش نہیں کر سکے۔ براہ کرم نام درست کریں یا دوبارہ اسکین کریں۔" : "We couldn't find details for this product. Please check the name or scan again.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.darkColor.withValues(alpha: 0.6), fontSize: 14, fontFamily: fontFamily)),
      ],
    );
  }
}

class SmartScannerPage extends StatefulWidget {
  const SmartScannerPage({super.key});
  @override
  State<SmartScannerPage> createState() => _SmartScannerPageState();
}

class _SmartScannerPageState extends State<SmartScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  final UsageLimitService _limitService = UsageLimitService();
  bool _isScanned = false;
  Map<String, dynamic>? _limitInfo;

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final info = await _limitService.getRemainingLimits();
    if (mounted) setState(() => _limitInfo = info);
  }

  void _showUpgradeDialog() {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isUrdu ? "پریمیم میں اپ گریڈ کریں" : "Upgrade to Premium", style: const TextStyle(color: Colors.white)),
        content: Text(
          isUrdu 
            ? "فری سرچ کی حد ختم ہو گئی ہے۔ تمام حدود ختم کرنے کے لیے پریمیم پلان حاصل کریں۔" 
            : "Free search limit reached. Get premium to remove all limits.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isUrdu ? "بعد میں" : "Later", style: const TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to payment or premium screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.themeColor),
            child: Text(isUrdu ? "پلان دیکھیں" : "View Plans"),
          ),
        ],
      ),
    );
  }

  // App Bar میں Limits دکھانے کے لیے
  Widget _buildLimitIndicator(bool isUrdu, String fontFamily) {
    if (_limitInfo == null) return const SizedBox.shrink();
    if (_limitInfo!['isPremium'] == true) return const SizedBox.shrink();

    final dailyRemaining = _limitInfo!['dailyRemaining'];
    final scansRemaining = _limitInfo!['scansRemaining'];
    
    Color getColor(dynamic remaining) {
      if (remaining is String) return Colors.green;
      if (remaining > 3) return Colors.green;
      if (remaining > 1) return Colors.orange;
      return Colors.red;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.magnifyingGlass(), size: 14, color: getColor(dailyRemaining)),
              const SizedBox(width: 4),
              Text("$dailyRemaining", style: TextStyle(fontWeight: FontWeight.bold, color: getColor(dailyRemaining))),
              const SizedBox(width: 12),
              Icon(PhosphorIcons.camera(), size: 14, color: getColor(scansRemaining)),
              const SizedBox(width: 4),
              Text("$scansRemaining", style: TextStyle(fontWeight: FontWeight.bold, color: getColor(scansRemaining))),
            ],
          ),
          TextButton(
            onPressed: _showUpgradeDialog,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            child: Text(
              isUrdu ? "اپ گریڈ" : "Upgrade",
              style: const TextStyle(color: AppTheme.themeColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: (capture) { if (!_isScanned) { final List<Barcode> barcodes = capture.barcodes; if (barcodes.isNotEmpty && barcodes.first.rawValue != null) { _isScanned = true; Navigator.pop(context, barcodes.first.rawValue); } } }),
          Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: AppTheme.themeColor, width: 2), borderRadius: BorderRadius.circular(24)))),
          SafeArea(child: Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))), CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.flash_on, color: Colors.white), onPressed: () => _controller.toggleTorch()))]))),
          Positioned(bottom: 40, left: 0, right: 0, child: Column(children: [const Text("Align Barcode or Take Photo", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 20), GestureDetector(onTap: () async { try { final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70); if (image != null && mounted) { Navigator.pop(context, File(image.path)); } } catch (e) { debugPrint("Error taking photo: $e"); } }, child: Container(height: 80, width: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: Center(child: Container(height: 60, width: 60, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))))] ) ),
        ],
      ),
    );
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}
