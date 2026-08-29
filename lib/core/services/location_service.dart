import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LocationService {
  /// OpenStreetMap Nominatim API کو استعمال کرتے ہوئے علاقوں کے نام تلاش کرتا ہے
  static Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    if (query.length < 3) return [];

    try {
      // ہم اسے پاکستان تک محدود کرنے کی کوشش کریں گے تاکہ بہتر نتائج ملیں
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=pk');

      final response = await http.get(url, headers: {
        'User-Agent': 'AccountApp/1.0', // Nominatim requires a user agent
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          return {
            'display_name': item['display_name'],
            'lat': double.tryParse(item['lat']),
            'lon': double.tryParse(item['lon']),
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Location search error: $e");
    }
    return [];
  }
}
