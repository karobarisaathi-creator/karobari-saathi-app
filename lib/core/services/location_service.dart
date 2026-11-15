import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Map<String, double>?> getCurrentCoordinates() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (error, stackTrace) {
      debugPrint('Current location lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> resolveShopLocation({
    required String address,
    double? fallbackLatitude,
    double? fallbackLongitude,
  }) async {
    final trimmedAddress = address.trim();
    if (trimmedAddress.length >= 3) {
      final locations = await searchLocations(trimmedAddress);
      if (locations.isNotEmpty &&
          locations.first['lat'] is double &&
          locations.first['lon'] is double) {
        return {
          'businessAddress': trimmedAddress,
          'latitude': locations.first['lat'] as double,
          'longitude': locations.first['lon'] as double,
        };
      }
      if (fallbackLatitude != null && fallbackLongitude != null) {
        return {
          'businessAddress': trimmedAddress,
          'latitude': fallbackLatitude,
          'longitude': fallbackLongitude,
        };
      }
      return null;
    }

    if (fallbackLatitude != null && fallbackLongitude != null) {
      return {
        'businessAddress': '',
        'latitude': fallbackLatitude,
        'longitude': fallbackLongitude,
      };
    }

    final coordinates = await getCurrentCoordinates();
    if (coordinates == null) return null;

    final detectedAddress = await reverseGeocode(
      coordinates['latitude']!,
      coordinates['longitude']!,
    );
    return {
      'businessAddress': detectedAddress ?? '',
      ...coordinates,
    };
  }

  /// OpenStreetMap Nominatim API کو استعمال کرتے ہوئے علاقوں کے نام تلاش کرتا ہے
  static Future<List<Map<String, dynamic>>> searchLocations(String query,
      {String language = 'ur'}) async {
    if (query.length < 3) return [];

    try {
      final url = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': '5',
          'countrycodes': 'pk',
          'accept-language': language,
        },
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'AccountApp/1.0'
      }).timeout(const Duration(seconds: 10));

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
  static Future<String?> reverseGeocode(double lat, double lon,
      {String language = 'ur'}) async {
    try {
      final url = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': '$lat',
          'lon': '$lon',
          'format': 'json',
          'accept-language': language,
        },
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'AccountApp/1.0'
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ہم پورا ایڈریس دکھانے کے بجائے اہم حصے دکھائیں گے
        final address = data['address'];
        if (address != null) {
          String? city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['suburb'];
          String? suburb = address['suburb'] ??
              address['neighbourhood'] ??
              address['residential'];

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
