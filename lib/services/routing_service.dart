import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import '../models/stop_model.dart';

/// Service to calculate route paths using OSRM
class RoutingService {
  // Using public OSRM demo server
  // NOTE: For production, host your own OSRM or use a paid service (Google/Mapbox)
  static const String _baseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  /// Get the road path connecting a list of stops
  Future<List<LatLng>> getRoutePolyline(List<StopModel> stops) async {
    if (stops.length < 2) {
      return [];
    }

    // Fallback path (straight lines between stops)
    final fallbackPath = stops.map((s) => LatLng(s.lat, s.lng)).toList();

    try {
      // 1. Construct coordinates string (lng,lat;lng,lat...)
      final coordinates = stops
          .map((stop) => '${stop.lng},${stop.lat}')
          .join(';');

      // 2. Build URL
      final url = Uri.parse(
        '$_baseUrl/$coordinates?overview=full&geometries=polyline',
      );

      // Add timeout to prevent hanging indefinitely
      // Add User-Agent header which is often required by OSM services
      final response = await http
          .get(
            url,
            headers: {
              'User-Agent': 'KeralaBusTracker/1.0 (bennykutty@example.com)',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              // Return a response that triggers the fallback logic downstream
              return http.Response('Timeout', 408);
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] != 'Ok') {
          return fallbackPath;
        }

        final routes = data['routes'] as List;
        if (routes.isEmpty) {
          return fallbackPath;
        }

        // 3. Decode geometry using google_polyline_algorithm
        final geometry = routes[0]['geometry'] as String;

        final decodedPoints = decodePolyline(
          geometry,
        ); // List<List<num>> [lat, lng]

        // Convert to LatLng
        final decodedLatLng = decodedPoints.map((pt) {
          // pt[0] is lat, pt[1] is lng (num) - convert to double
          return LatLng(pt[0].toDouble(), pt[1].toDouble());
        }).toList();

        // Ensure we have at least 2 points to form a line
        if (decodedLatLng.length < 2) {
          return fallbackPath;
        }
        return decodedLatLng;
      } else {
        return fallbackPath;
      }
    } catch (e) {
      // Return straight lines so at least something is shown
      return fallbackPath;
    }
  }
}
