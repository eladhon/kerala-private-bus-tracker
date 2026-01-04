import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/user_model.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/bus_location_model.dart';
import '../models/vehicle_state_model.dart';
import '../models/bus_stop_model.dart';
import 'supabase_service.dart';

/// All Supabase database queries centralized in one file
class SupabaseQueries {
  final SupabaseClient _client = SupabaseService().client;

  // ============================================
  // AUTH QUERIES
  // ============================================

  /// Sign in with phone number - sends OTP
  Future<void> signInWithPhone(String phoneNumber) async {
    await _client.auth.signInWithOtp(phone: phoneNumber);
  }

  /// Verify OTP code
  Future<AuthResponse> verifyOtp(String phoneNumber, String otpCode) async {
    return await _client.auth.verifyOTP(
      phone: phoneNumber,
      token: otpCode,
      type: OtpType.sms,
    );
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ============================================
  // USER QUERIES
  // ============================================

  /// Get user by phone number
  Future<UserModel?> getUserByPhone(String phoneNumber) async {
    debugPrint('Querying user by phone: $phoneNumber');
    final response = await _client
        .from('users')
        .select()
        .eq('phone', phoneNumber)
        .maybeSingle();

    debugPrint('User query response: $response');

    if (response != null) {
      return UserModel.fromJson(response);
    }
    return null;
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response != null) {
      return UserModel.fromJson(response);
    }
    return null;
  }

  /// Create a new user
  Future<UserModel> createUser({
    required String phone,
    required String name,
    required String role,
    String? busId,
  }) async {
    final response = await _client
        .from('users')
        .insert({'phone': phone, 'name': name, 'role': role, 'bus_id': busId})
        .select()
        .single();

    return UserModel.fromJson(response);
  }

  /// Update user details
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await _client.from('users').update(updates).eq('id', userId);
  }

  /// Get user role by phone number
  Future<String?> getUserRole(String phoneNumber) async {
    final response = await _client
        .from('users')
        .select('role')
        .eq('phone', phoneNumber)
        .maybeSingle();

    return response?['role'] as String?;
  }

  // ============================================
  // BUS QUERIES
  // ============================================

  /// Get all buses
  Future<List<BusModel>> getAllBuses() async {
    final response = await _client
        .from('buses')
        .select()
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((bus) => BusModel.fromJson(bus)).toList();
  }

  /// Get buses by route ID
  Future<List<BusModel>> getBusesByRoute(String routeId) async {
    final response = await _client
        .from('buses')
        .select()
        .eq('route_id', routeId)
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((bus) => BusModel.fromJson(bus)).toList();
  }

  /// Get available buses only
  Future<List<BusModel>> getAvailableBuses() async {
    final response = await _client
        .from('buses')
        .select()
        .eq('is_available', true)
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((bus) => BusModel.fromJson(bus)).toList();
  }

  /// Get bus by ID
  Future<BusModel?> getBusById(String busId) async {
    final response = await _client
        .from('buses')
        .select()
        .eq('id', busId)
        .maybeSingle();

    if (response != null) {
      return BusModel.fromJson(response);
    }
    return null;
  }

  /// Get bus assigned to conductor
  Future<BusModel?> getBusByConductorId(String conductorId) async {
    final response = await _client
        .from('buses')
        .select()
        .eq('conductor_id', conductorId)
        .maybeSingle();

    if (response != null) {
      return BusModel.fromJson(response);
    }
    return null;
  }

  /// Update bus availability
  Future<void> setBusAvailability(String busId, bool isAvailable) async {
    await _client
        .from('buses')
        .update({'is_available': isAvailable})
        .eq('id', busId);
  }

  /// Search buses by name or registration
  Future<List<BusModel>> searchBuses(String query) async {
    final response = await _client
        .from('buses')
        .select()
        .or('name.ilike.%$query%,registration_number.ilike.%$query%')
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((bus) => BusModel.fromJson(bus)).toList();
  }

  // ============================================
  // ROUTE QUERIES
  // ============================================

  /// Get all routes
  Future<List<RouteModel>> getAllRoutes() async {
    final response = await _client
        .from('routes')
        .select()
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((route) => RouteModel.fromJson(route)).toList();
  }

  /// Get route by ID
  Future<RouteModel?> getRouteById(String routeId) async {
    final response = await _client
        .from('routes')
        .select()
        .eq('id', routeId)
        .maybeSingle();

    if (response != null) {
      return RouteModel.fromJson(response);
    }
    return null;
  }

  /// Search routes by name, start or end location
  Future<List<RouteModel>> searchRoutes(String query) async {
    final response = await _client
        .from('routes')
        .select()
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
        .select()
        .eq('is_popular', true)
        .limit(limit)
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((route) => RouteModel.fromJson(route)).toList();
  }

  // ============================================
  // VEHICLE OBSERVATION / STATE QUERIES (GPS Smoothing Pipeline)
  // ============================================
  // The GPS smoothing pipeline uses:
  //   - vehicle_observations: Raw GPS data (write-only)
  //   - vehicle_state: Smoothed position (read-only, updated by Postgres trigger)
  // ============================================

  /// Insert raw GPS observation (triggers server-side smoothing)
  /// This is the primary method for conductors to report GPS position.
  /// The Postgres trigger will automatically update vehicle_state.
  Future<void> insertVehicleObservation({
    required String busId,
    required double lat,
    required double lng,
    double? accuracyM,
    double? speedMps,
    double? headingDeg,
  }) async {
    await _client.from('vehicle_observations').insert({
      'bus_id': busId,
      'lat': lat,
      'lng': lng,
      'accuracy_m': accuracyM,
      'speed_mps': speedMps,
      'heading_deg': headingDeg,
      'observed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Get current smoothed state of a vehicle
  Future<VehicleStateModel?> getVehicleState(String busId) async {
    final response = await _client
        .from('vehicle_state')
        .select()
        .eq('bus_id', busId)
        .maybeSingle();

    if (response != null) {
      return VehicleStateModel.fromJson(response);
    }
    return null;
  }

  /// Stream real-time smoothed vehicle state updates
  /// This is the recommended method for clients to get live position.
  Stream<VehicleStateModel?> streamVehicleState(String busId) {
    return _client
        .from('vehicle_state')
        .stream(primaryKey: ['bus_id'])
        .eq('bus_id', busId)
        .map((data) {
          if (data.isNotEmpty) {
            return VehicleStateModel.fromJson(data.first);
          }
          return null;
        });
  }

  /// Stream all vehicle states (for map view)
  Stream<List<VehicleStateModel>> streamAllVehicleStates() {
    return _client
        .from('vehicle_state')
        .stream(primaryKey: ['bus_id'])
        .map(
          (data) =>
              data.map((state) => VehicleStateModel.fromJson(state)).toList(),
        );
  }

  /// Get vehicle states for buses on a specific route
  Future<List<VehicleStateModel>> getVehicleStatesOnRoute(
    String routeId,
  ) async {
    final buses = await getBusesByRoute(routeId);
    final busIds = buses.map((b) => b.id).toList();

    if (busIds.isEmpty) return [];

    final response = await _client
        .from('vehicle_state')
        .select()
        .inFilter('bus_id', busIds);

    final data = response as List<dynamic>? ?? [];
    return data.map((state) => VehicleStateModel.fromJson(state)).toList();
  }

  // ============================================
  // LEGACY BUS LOCATION QUERIES (Deprecated)
  // ============================================
  // These methods are kept for backward compatibility.
  // New code should use vehicle_observations/vehicle_state instead.
  // ============================================

  /// @deprecated Use insertVehicleObservation instead
  Future<void> updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
  }) async {
    // Redirect to new pipeline
    await insertVehicleObservation(
      busId: busId,
      lat: latitude,
      lng: longitude,
      speedMps: speed != null ? speed / 3.6 : null, // Convert km/h to m/s
      headingDeg: heading,
    );
  }

  /// @deprecated Use getVehicleState instead
  Future<BusLocationModel?> getBusLocation(String busId) async {
    final state = await getVehicleState(busId);
    if (state != null) {
      // Convert VehicleStateModel to BusLocationModel for compatibility
      return BusLocationModel(
        busId: state.busId,
        latitude: state.lat,
        longitude: state.lng,
        speed: state.speedKmh,
        heading: state.headingDeg,
        updatedAt: state.updatedAt,
      );
    }
    return null;
  }

  /// @deprecated Use streamVehicleState instead
  Stream<BusLocationModel?> streamBusLocation(String busId) {
    return streamVehicleState(busId).map((state) {
      if (state != null) {
        return BusLocationModel(
          busId: state.busId,
          latitude: state.lat,
          longitude: state.lng,
          speed: state.speedKmh,
          heading: state.headingDeg,
          updatedAt: state.updatedAt,
        );
      }
      return null;
    });
  }

  /// @deprecated Use streamAllVehicleStates instead
  Stream<List<BusLocationModel>> streamAllBusLocations() {
    return streamAllVehicleStates().map(
      (states) => states
          .map(
            (state) => BusLocationModel(
              busId: state.busId,
              latitude: state.lat,
              longitude: state.lng,
              speed: state.speedKmh,
              heading: state.headingDeg,
              updatedAt: state.updatedAt,
            ),
          )
          .toList(),
    );
  }

  /// @deprecated Use getVehicleStatesOnRoute instead
  Future<List<BusLocationModel>> getBusLocationsOnRoute(String routeId) async {
    final states = await getVehicleStatesOnRoute(routeId);
    return states
        .map(
          (state) => BusLocationModel(
            busId: state.busId,
            latitude: state.lat,
            longitude: state.lng,
            speed: state.speedKmh,
            heading: state.headingDeg,
            updatedAt: state.updatedAt,
          ),
        )
        .toList();
  }

  // ============================================
  // DASHBOARD / STATS QUERIES
  // ============================================

  /// Get count of available buses
  Future<int> getAvailableBusCount() async {
    final response = await _client
        .from('buses')
        .select()
        .eq('is_available', true)
        .count(CountOption.exact);

    return response.count;
  }

  /// Get total bus count
  Future<int> getTotalBusCount() async {
    final response = await _client
        .from('buses')
        .select()
        .count(CountOption.exact);

    return response.count;
  }

  /// Get buses on a route with their current smoothed states
  Future<List<Map<String, dynamic>>> getBusesWithLocations(
    String routeId,
  ) async {
    final response = await _client
        .from('buses')
        .select('''
          *,
          vehicle_state (*)
        ''')
        .eq('route_id', routeId);

    final data = response as List<dynamic>? ?? [];
    return List<Map<String, dynamic>>.from(data);
  }

  // ============================================
  // ADMIN QUERIES
  // ============================================

  /// Get all conductors (users with role='conductor')
  Future<List<UserModel>> getAllConductors() async {
    final response = await _client
        .from('users')
        .select()
        .eq('role', 'conductor')
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((user) => UserModel.fromJson(user)).toList();
  }

  /// Assign a bus to a conductor (updates both user and bus tables)
  Future<void> assignBusToConductor(String conductorId, String? busId) async {
    // First, unassign conductor from any previously assigned bus
    await _client.from('users').update({'bus_id': null}).eq('id', conductorId);

    // If busId is provided, assign the new bus
    if (busId != null) {
      // Update user's bus_id
      await _client
          .from('users')
          .update({'bus_id': busId})
          .eq('id', conductorId);

      // Update bus's conductor_id
      await _client
          .from('buses')
          .update({'conductor_id': conductorId})
          .eq('id', busId);
    }
  }

  /// Update bus details
  Future<void> updateBus(String busId, Map<String, dynamic> updates) async {
    await _client.from('buses').update(updates).eq('id', busId);
  }

  /// Create a new bus
  Future<BusModel> createBus({
    required String name,
    required String registrationNumber,
    required String routeId,
    String? conductorId,
    bool isAvailable = false,
  }) async {
    final response = await _client
        .from('buses')
        .insert({
          'name': name,
          'registration_number': registrationNumber,
          'route_id': routeId,
          'conductor_id': conductorId,
          'is_available': isAvailable,
        })
        .select()
        .single();

    return BusModel.fromJson(response);
  }

  /// Delete a bus
  Future<void> deleteBus(String busId) async {
    // First remove conductor assignments
    await _client.from('users').update({'bus_id': null}).eq('bus_id', busId);

    // Delete vehicle state if exists (observations are kept for audit)
    await _client.from('vehicle_state').delete().eq('bus_id', busId);

    // Delete the bus
    await _client.from('buses').delete().eq('id', busId);
  }

  /// Delete a conductor (user with role='conductor')
  Future<void> deleteConductor(String conductorId) async {
    // Remove from any bus assignments
    await _client
        .from('buses')
        .update({'conductor_id': null})
        .eq('conductor_id', conductorId);

    // Delete the user
    await _client.from('users').delete().eq('id', conductorId);
  }

  /// Create a new conductor
  Future<UserModel> createConductor({
    required String phone,
    required String name,
    String? busId,
  }) async {
    final response = await _client
        .from('users')
        .insert({
          'phone': phone,
          'name': name,
          'role': 'conductor',
          'bus_id': busId,
        })
        .select()
        .single();

    return UserModel.fromJson(response);
  }

  /// Update conductor details
  Future<void> updateConductor(
    String conductorId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('users').update(updates).eq('id', conductorId);
  }

  // ============================================
  // BUS STOP QUERIES (Updated for JSONB in Routes)
  // ============================================

  /// Get all bus stops (aggregated from all routes)
  Future<List<BusStopModel>> getAllBusStops() async {
    final routes = await getAllRoutes();
    final allStops = <BusStopModel>[];
    for (var route in routes) {
      for (var stop in route.busStops) {
        // We ensure the stop has the routeId attached for context
        allStops.add(stop.copyWith(routeId: route.id));
      }
    }
    // Sort by name
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
  }) async {
    if (routeId == null) {
      throw Exception('Route ID is required to add a stop');
    }

    final routeResponse = await _client
        .from('routes')
        .select()
        .eq('id', routeId)
        .single();
    final route = RouteModel.fromJson(routeResponse);

    // Simple ID generation since it's a JSON array
    final newStop = BusStopModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      latitude: latitude,
      longitude: longitude,
      routeId: routeId,
      orderIndex: orderIndex,
      createdAt: DateTime.now(),
    );

    final updatedStops = List<BusStopModel>.from(route.busStops)..add(newStop);

    await _client
        .from('routes')
        .update({'bus_stops': updatedStops.map((s) => s.toJson()).toList()})
        .eq('id', routeId);
  }

  /// Update a bus stop
  Future<void> updateBusStop(
    String stopId,
    Map<String, dynamic> updates,
  ) async {
    // We need the route_id to find the route
    final routeId = updates['route_id'];
    if (routeId == null) {
      throw Exception('Route ID is required to update a stop');
    }

    final routeResponse = await _client
        .from('routes')
        .select()
        .eq('id', routeId)
        .single();
    final route = RouteModel.fromJson(routeResponse);

    final updatedStops = route.busStops.map((s) {
      if (s.id == stopId) {
        return s.copyWith(
          name: updates['name'],
          latitude: updates['latitude'],
          longitude: updates['longitude'],
          orderIndex: updates['order_index'],
        );
      }
      return s;
    }).toList();

    await _client
        .from('routes')
        .update({'bus_stops': updatedStops.map((s) => s.toJson()).toList()})
        .eq('id', routeId);
  }

  /// Delete a bus stop
  Future<void> deleteBusStop(String stopId, String? routeId) async {
    // If routeId is provided, use it directly (efficient)
    // If not, we have to search all routes (inefficient but safe fallback)

    if (routeId != null) {
      await _deleteStopFromRoute(routeId, stopId);
    } else {
      // Fallback search
      final routes = await getAllRoutes();
      for (var route in routes) {
        if (route.busStops.any((s) => s.id == stopId)) {
          await _deleteStopFromRoute(route.id, stopId);
          return;
        }
      }
    }
  }

  Future<void> _deleteStopFromRoute(String routeId, String stopId) async {
    final routeResponse = await _client
        .from('routes')
        .select()
        .eq('id', routeId)
        .single();
    final route = RouteModel.fromJson(routeResponse);

    final updatedStops = route.busStops.where((s) => s.id != stopId).toList();

    await _client
        .from('routes')
        .update({'bus_stops': updatedStops.map((s) => s.toJson()).toList()})
        .eq('id', routeId);
  }

  /// Get nearest bus stops to a location
  Future<List<BusStopModel>> getNearestBusStops(
    double latitude,
    double longitude, {
    int limit = 5,
  }) async {
    // Get all stops and calculate distance client-side
    // For production, use PostGIS extension for geo queries
    final allStops = await getAllBusStops();

    // Sort by distance
    allStops.sort((a, b) {
      final distA = _calculateDistance(
        latitude,
        longitude,
        a.latitude,
        a.longitude,
      );
      final distB = _calculateDistance(
        latitude,
        longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });

    return allStops.take(limit).toList();
  }

  /// Calculate distance between two points (Haversine formula simplified)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = (lat2 - lat1) * 0.0174533; // Convert to radians
    final dLon = (lon2 - lon1) * 0.0174533;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * 0.0174533) *
            cos(lat2 * 0.0174533) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 6371 * 2 * asin(sqrt(a)); // Earth radius in km
  }
}
