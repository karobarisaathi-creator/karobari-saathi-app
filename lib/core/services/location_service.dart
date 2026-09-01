import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LocationService {
  /// OpenStreetMap Nominatim API کو استعمال کرتے ہوئے علاقوں کے نام تلاش کرتا ہے
  static Future<List<Map<String, dynamic>>> searchLocations(String query, {String language = 'ur'}) async {
    if (query.length < 3) return [];

    try {
      // ہم اسے پاکستان تک محدود کرنے کی کوشش کریں گے تاکہ بہتر نتائج ملیں
      // accept-language parameter adds support for Urdu addresses
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=pk&accept-language=$language');

      final response = await http.get(url, headers: {
        'User-Agent': 'AccountApp/1.0',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          return {
            'display_name': item['display_name'],
            'lat': double.tryParse(item['lat'] ?? ""),
            'lon': double.tryParse(item['lon'] ?? ""),
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Location search error: $e");
    }
    return [];
  }

  /// کوآرڈینیٹس سے ایڈریس حاصل کرتا ہے (اردو سپورٹ کے ساتھ)
  static Future<String?> reverseGeocode(double lat, double lon, {String language = 'ur'}) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=$language');

      final response = await http.get(url, headers: {
        'User-Agent': 'AccountApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // ہم پورا ایڈریس دکھانے کے بجائے اہم حصے دکھائیں گے
        final address = data['address'];
        if (address != null) {
          String? city = address['city'] ?? address['town'] ?? address['village'] ?? address['suburb'];
          String? suburb = address['suburb'] ?? address['neighbourhood'] ?? address['residential'];
          
          if (city != null && suburb != null) {
            return "$suburb, $city";
          }
          return data['display_name'];
        }
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
    }
    return null;
  }
}
