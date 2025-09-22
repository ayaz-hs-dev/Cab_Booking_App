import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceService {
  // Replace with your OpenRouteService API key
  static const String apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImY2ZjRmMDRhZTNlNjRjZDY4NDNhMDM2ODg3MDg2Y2FlIiwiaCI6Im11cm11cjY0In0=';

  // Search places using OpenRouteService API
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final url =
        "https://api.openrouteservice.org/geocode/autocomplete?api_key=$apiKey&text=$query";

    final response = await http.get(
      Uri.parse(url),
      headers: {"User-Agent": "taxi-app/1.0", "Accept": "application/json"},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List<dynamic>;

      return features.map((place) {
        final properties = place['properties'];
        final coordinates = place['geometry']['coordinates'];

        return {
          "displayName": properties['label'] ?? '',
          "lat": coordinates[1],
          "lon": coordinates[0],
        };
      }).toList();
    } else {
      throw Exception("Failed to load places: ${response.statusCode}");
    }
  }

  static Future<Map<String, dynamic>> reverseGeocode(LatLng location) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=json'
        '&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'taxi_app'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'displayName': data['display_name'] ?? 'Unknown Location',
          'lat': location.latitude,
          'lon': location.longitude,
        };
      } else {
        throw Exception('Failed to reverse geocode');
      }
    } catch (e) {
      throw Exception('Error reverse geocoding: $e');
    }
  }
}
