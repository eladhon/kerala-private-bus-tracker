/// Route-related Supabase queries
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';
import '../../models/route_model.dart';
import '../../models/stop_model.dart';

/// Route queries module
class RouteQueries {
  final SupabaseClient _client = SupabaseService().client;

  // In-memory cache for routes with TTL
  static List<RouteModel>? _allRoutesCache;
  static DateTime? _allRoutesCacheTime;
  static final Map<String, RouteModel> _routeByIdCache = {};
  static final Map<String, DateTime> _routeByIdCacheTime = {};
  static const _cacheTtl = Duration(minutes: 5);

  /// Clear all cached data (call after mutations)
  void clearCache() {
    _allRoutesCache = null;
    _allRoutesCacheTime = null;
    _routeByIdCache.clear();
    _routeByIdCacheTime.clear();
  }

  /// Get all routes (cached)
  Future<List<RouteModel>> getAllRoutes() async {
    // Check cache
    if (_allRoutesCache != null &&
        _allRoutesCacheTime != null &&
        DateTime.now().difference(_allRoutesCacheTime!) < _cacheTtl) {
      return _allRoutesCache!;
    }

    final response = await _client
        .from('routes')
        .select('*')
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    final routes = data.map((route) => RouteModel.fromJson(route)).toList();

    // Update cache
    _allRoutesCache = routes;
    _allRoutesCacheTime = DateTime.now();

    return routes;
  }

  /// Get route by ID (cached)
  Future<RouteModel?> getRouteById(String routeId) async {
    // Check cache
    final cachedRoute = _routeByIdCache[routeId];
    final cacheTime = _routeByIdCacheTime[routeId];
    if (cachedRoute != null &&
        cacheTime != null &&
        DateTime.now().difference(cacheTime) < _cacheTtl) {
      return cachedRoute;
    }

    final response = await _client
        .from('routes')
        .select('*')
        .eq('id', routeId)
        .maybeSingle();

    if (response != null) {
      final route = RouteModel.fromJson(response);
      // Update cache
      _routeByIdCache[routeId] = route;
      _routeByIdCacheTime[routeId] = DateTime.now();
      return route;
    }
    return null;
  }

  /// Search routes by name, start or end location
  Future<List<RouteModel>> searchRoutes(String query) async {
    final response = await _client
        .from('routes')
        .select('*')
        .or(
          'name.ilike.%$query%,start_location.ilike.%$query%,end_location.ilike.%$query%',
        )
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((route) => RouteModel.fromJson(route)).toList();
  }

  /// Get popular routes (for quick picks)
  Future<List<RouteModel>> getPopularRoutes({int limit = 5}) async {
    final response = await _client
        .from('routes')
        .select('*')
        .eq('is_popular', true)
        .limit(limit)
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((route) => RouteModel.fromJson(route)).toList();
  }

  /// Create a new route
  Future<RouteModel> createRoute({
    required String name,
    required String startLocation,
    required String endLocation,
    double? distance,
    bool isPopular = false,
    List<StopModel> stops = const [],
  }) async {
    final response = await _client
        .from('routes')
        .insert({
          'name': name,
          'start_location': startLocation,
          'end_location': endLocation,
          'distance': distance,
          'is_popular': isPopular,
          'stops': stops.map((s) => s.toJson()).toList(),
        })
        .select()
        .single();

    return RouteModel.fromJson(response);
  }

  /// Update route details
  Future<void> updateRoute(String routeId, Map<String, dynamic> updates) async {
    await _client.from('routes').update(updates).eq('id', routeId);
  }

  /// Delete a route and handle associated buses
  Future<void> deleteRoute(String routeId) async {
    await _client
        .from('buses')
        .update({'route_id': null})
        .eq('route_id', routeId);

    await _client.from('routes').delete().eq('id', routeId);
  }

  // ============================================
  // BUS STOP QUERIES (Embedded in Routes JSONB)
  // ============================================

  /// Get all bus stops (aggregated from all routes)
  Future<List<StopModel>> getAllBusStops() async {
    final routes = await getAllRoutes();
    final allStops = <StopModel>[];
    final seenIds = <String>{};

    for (var route in routes) {
      for (var stop in route.busStops) {
        if (!seenIds.contains(stop.id)) {
          allStops.add(stop);
          seenIds.add(stop.id);
        }
      }
    }

    allStops.sort((a, b) => a.name.compareTo(b.name));
    return allStops;
  }

  /// Add a new bus stop to a route
  Future<void> createBusStop({
    required String name,
    required double latitude,
    required double longitude,
    String? routeId,
    int? orderIndex,
    int? minutesFromStart,
  }) async {
    if (routeId == null) {
      throw Exception('Route ID is required to add a stop');
    }

    final route = await getRouteById(routeId);
    if (route == null) throw Exception('Route not found');

    final newStop = StopModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      lat: latitude,
      lng: longitude,
      orderIndex: orderIndex ?? route.busStops.length + 1,
      minutesFromStart: minutesFromStart,
    );

    final updatedStops = List<StopModel>.from(route.busStops);
    if (orderIndex != null && orderIndex <= updatedStops.length) {
      updatedStops.insert(orderIndex, newStop);
    } else {
      updatedStops.add(newStop);
    }

    await _client
        .from('routes')
        .update({'stops': updatedStops.map((s) => s.toJson()).toList()})
        .eq('id', routeId);
  }

  /// Update a bus stop
  Future<void> updateBusStop(
    String stopId,
    Map<String, dynamic> updates,
  ) async {
    final routeId = updates['route_id'];
    if (routeId == null) {
      throw Exception('route_id is required to update a stop in JSONB mode');
    }

    final route = await getRouteById(routeId);
    if (route == null) throw Exception('Route not found');

    final updatedStops = route.busStops.map((s) {
      if (s.id == stopId) {
        return s.copyWith(
          name: updates['name'] ?? s.name,
          lat: updates['lat'] ?? updates['latitude'] ?? s.lat,
          lng: updates['lng'] ?? updates['longitude'] ?? s.lng,
          orderIndex: updates['order_index'] ?? s.orderIndex,
          minutesFromStart: updates['minutes_from_start'] ?? s.minutesFromStart,
        );
      }
      return s;
    }).toList();

    if (updates.containsKey('order_index')) {
      updatedStops.sort(
        (a, b) => (a.orderIndex ?? 0).compareTo(b.orderIndex ?? 0),
      );
    }

    await _client
        .from('routes')
        .update({'stops': updatedStops.map((s) => s.toJson()).toList()})
        .eq('id', routeId);
  }

  /// Delete a bus stop
  Future<void> deleteBusStop(String stopId, String? routeId) async {
    if (routeId == null) {
      throw Exception('Route ID is required to delete a stop');
    }

    final route = await getRouteById(routeId);
    if (route == null) return;

    final updatedStops = route.busStops.where((s) => s.id != stopId).toList();

    await _client
        .from('routes')
        .update({'stops': updatedStops.map((s) => s.toJson()).toList()})
        .eq('id', routeId);
  }

  /// Get nearest bus stops to a location
  Future<List<StopModel>> getNearestBusStops(
    double latitude,
    double longitude, {
    int limit = 5,
  }) async {
    final allStops = await getAllBusStops();

    allStops.sort((a, b) {
      final distA =
          (a.lat - latitude) * (a.lat - latitude) +
          (a.lng - longitude) * (a.lng - longitude);
      final distB =
          (b.lat - latitude) * (b.lat - latitude) +
          (b.lng - longitude) * (b.lng - longitude);
      return distA.compareTo(distB);
    });

    return allStops.take(limit).toList();
  }

  /// Get all routes that pass through a given stop
  Future<List<RouteModel>> getRoutesForStop(String stopId) async {
    final allRoutes = await getAllRoutes();
    return allRoutes.where((route) {
      return route.busStops.any((stop) => stop.id == stopId);
    }).toList();
  }
}
