import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import '../models/stop_model.dart';

/// Service to calculate route paths using OSRM
class RoutingService {
  // Using public OSRM demo server
  // NOTE: For production, host your own OSRM or use a paid service (Google/Mapbox)
  static const String _baseDrivingUrl =
      'https://router.project-osrm.org/route/v1/driving';
  static const String _baseWalkingUrl =
      'https://router.project-osrm.org/route/v1/foot';

  /// Get the road path connecting a list of stops
  Future<List<LatLng>> getRoutePolyline(List<StopModel> stops) async {
    return _fetchPolyline(
      stops.map((s) => LatLng(s.lat, s.lng)).toList(),
      _baseDrivingUrl,
    );
  }

  /// Get the walking path connecting a list of points (LatLng)
  Future<List<LatLng>> getWalkingPolyline(List<LatLng> points) async {
    return _fetchPolyline(points, _baseWalkingUrl);
  }

  Future<List<LatLng>> _fetchPolyline(
    List<LatLng> points,
    String baseUrl,
  ) async {
    if (points.length < 2) {
      return [];
    }

    // Fallback path (straight lines between points)
    final fallbackPath = List<LatLng>.from(points);

    try {
      // 1. Construct coordinates string (lng,lat;lng,lat...)
      final coordinates = points
          .map((pt) => '${pt.longitude},${pt.latitude}')
          .join(';');

      // 2. Build URL
      final url = Uri.parse(
        '$baseUrl/$coordinates?overview=full&geometries=polyline',
      );

      // Add User-Agent header which is often required by OSM services
      final response = await http
          .get(url, headers: {'User-Agent': 'KeralaBusTracker/1.0'})
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => http.Response('Timeout', 408),
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
          return LatLng(pt[0].toDouble(), pt[1].toDouble());
        }).toList();

        if (decodedLatLng.length < 2) {
          return fallbackPath;
        }
        return decodedLatLng;
      } else {
        return fallbackPath;
      }
    } catch (e) {
      return fallbackPath;
    }
  }
}
