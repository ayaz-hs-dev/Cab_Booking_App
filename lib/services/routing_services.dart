import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  static const String apiKey =
      "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImY2ZjRmMDRhZTNlNjRjZDY4NDNhMDM2ODg3MDg2Y2FlIiwiaCI6Im11cm11cjY0In0=";

  static Future<List<Map<String, dynamic>>> getRoutes(
    LatLng start,
    LatLng end,
  ) async {
    final url =
        'http://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?alternatives=2&geometries=geojson';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> routes = data['routes'];
        return routes.asMap().entries.map((entry) {
          // final index = entry.key;
          final route = entry.value;
          final coordinates = (route['geometry']['coordinates'] as List)
              .map((coord) => LatLng(coord[1], coord[0]))
              .toList();
          return {
            'polyline': coordinates,
            'distance': route['distance'] / 1000,
            'duration': route['duration'] / 60,
          };
        }).toList();
      } else {
        throw Exception('Failed to fetch routes');
      }
    } catch (e) {
      throw Exception('Error fetching routes: $e');
    }
  }

  static double calculateFare(double distance) {
    // Example fare calculation: $2 base + $1 per km
    return 2.0 + distance * 1.0;
  }

  // Fetch route distance in meters between two points
  static Future<double?> getRouteDistance(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Distance in meters
        double distance =
            data['features'][0]['properties']['segments'][0]['distance'];
        return distance;
      } else {
        debugPrint("Routing error: ${response.statusCode} ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Routing exception: $e");
      return null;
    }
  }

  static Future<double?> getRouteTime(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Duration in seconds
        double duration =
            data['features'][0]['properties']['segments'][0]['duration'];
        return duration;
      } else {
        debugPrint("Routing error: ${response.statusCode} ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Routing exception: $e");
      return null;
    }
  }
}
