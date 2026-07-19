import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/price_report_model.dart';
import '../models/price_alert_model.dart';
import '../models/inventory_item_model.dart';

class PriceDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // نئی قیمت رپورٹ کریں
  Future<void> submitPriceReport(PriceReport report) async {
    await _firestore.collection('price_reports').doc(report.id).set(report.toMap());
  }

  // مارکیٹ پلیس میں موجود بہترین ڈیل چیک کریں
  Future<InventoryItem?> checkMarketplaceForDeal(String productName, double targetPrice) async {
    try {
      final query = await _firestore
          .collectionGroup('inventory_items')
          .where('defaultRate', isLessThanOrEqualTo: targetPrice)
          .get();

      // سمارٹ میچنگ: نام کے الفاظ چیک کریں تاکہ بہتر نتیجہ ملے
      final searchWords = productName.toLowerCase().split(' ').where((w) => w.length > 2).toList();
      
      for (var doc in query.docs) {
        final item = InventoryItem.fromMap({...doc.data(), 'id': doc.id});
        final itemName = item.name.toLowerCase();
        
        // اگر کم از کم دو الفاظ میچ ہو جائیں یا پورا پہلا لفظ میچ ہو
        int matches = 0;
        for (var word in searchWords) {
          if (itemName.contains(word)) matches++;
        }
        
        if (matches >= (searchWords.length > 1 ? 2 : 1)) {
          return item;
        }
      }
    } catch (e) {
      print("Marketplace check error: $e");
    }
    return null;
  }

  // کسی خاص پروڈکٹ کے لیے قریبی قیمتیں لائیں
  Future<List<PriceReport>> getNearbyPrices(String productId) async {
    final snapshot = await _firestore
        .collection('price_reports')
        .where('productId', isEqualTo: productId)
        .orderBy('reportedAt', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) => PriceReport.fromMap(doc.data())).toList();
  }

  // پرائس الرٹ سیٹ کریں
  Future<void> setPriceAlert(PriceAlert alert) async {
    await _firestore.collection('price_alerts').doc(alert.id).set(alert.toMap());
  }
}
