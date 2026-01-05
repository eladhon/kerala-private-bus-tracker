import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/vehicle_state_model.dart';
import '../models/stop_model.dart';
import '../models/bus_trip_model.dart';
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
    debugPrint('Querying buses for route ID: $routeId');
    final response = await _client
        .from('buses')
        .select()
        .eq('route_id', routeId)
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    debugPrint('Found ${data.length} buses for route $routeId');
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
  /// Get all routes
  Future<List<RouteModel>> getAllRoutes() async {
    final response = await _client
        .from('routes')
        .select('*')
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((route) => RouteModel.fromJson(route)).toList();
  }

  /// Get route by ID
  Future<RouteModel?> getRouteById(String routeId) async {
    final response = await _client
        .from('routes')
        .select('*')
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
  }) async {
    final response = await _client
        .from('routes')
        .insert({
          'name': name,
          'start_location': startLocation,
          'end_location': endLocation,
          'distance': distance,
          'is_popular': isPopular,
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
    // First, unassign all buses from this route
    await _client
        .from('buses')
        .update({'route_id': null})
        .eq('route_id', routeId);

    // Delete the route (cascade deletes route_stops, but stops remain as they are entities)
    await _client.from('routes').delete().eq('id', routeId);
  }

  // ============================================
  // TRIP MANAGEMENT QUERIES
  // ============================================

  /// Start a new trip for a bus on a route
  Future<BusTripModel> startTrip({
    required String busId,
    required String routeId,
  }) async {
    // 1. Check if there is already an active trip for this bus and end it?
    // Optional: Auto-close previous active trips
    await _client
        .from('bus_trips')
        .update({
          'status': 'completed',
          'end_time': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('bus_id', busId)
        .eq('status', 'active');

    // 2. Create new active trip
    final response = await _client
        .from('bus_trips')
        .insert({
          'bus_id': busId,
          'route_id': routeId,
          'status': 'active',
          'start_time': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    return BusTripModel.fromJson(response);
  }

  /// End an active trip
  Future<void> endTrip(String tripId) async {
    await _client
        .from('bus_trips')
        .update({
          'status': 'completed',
          'end_time': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tripId);
  }

  /// Get current active trip for a bus
  Future<BusTripModel?> getActiveTripForBus(String busId) async {
    final response = await _client
        .from('bus_trips')
        .select()
        .eq('bus_id', busId)
        .eq('status', 'active')
        .maybeSingle();

    if (response != null) {
      return BusTripModel.fromJson(response);
    }
    return null;
  }

  /// Get all trips for a bus (history)
  Future<List<BusTripModel>> getTripHistory(String busId) async {
    final response = await _client
        .from('bus_trips')
        .select()
        .eq('bus_id', busId)
        .order('start_time', ascending: false);

    final data = response as List<dynamic>;
    return data.map((t) => BusTripModel.fromJson(t)).toList();
  }

  // ============================================
  // BUS STOP QUERIES (Normalized)
  // ============================================

  /// Get all bus stops (aggregated from all routes)
  Future<List<StopModel>> getAllBusStops() async {
    // Since stops are now inside routes, we fetch all routes and collect stops
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

    // Sort by name
    allStops.sort((a, b) => a.name.compareTo(b.name));
    return allStops;
  }

  /// Add a new bus stop to a route using specialized RPCs
  /// Add a new bus stop to a route (JSONB append)
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

    // 1. Fetch current route
    final route = await getRouteById(routeId);
    if (route == null) throw Exception('Route not found');

    // 2. Create new Stop object
    final newStop = StopModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      lat: latitude,
      lng: longitude,
      orderIndex: orderIndex ?? route.busStops.length + 1,
    );

    // 3. Update list
    final updatedStops = List<StopModel>.from(route.busStops);
    if (orderIndex != null && orderIndex <= updatedStops.length) {
      updatedStops.insert(orderIndex, newStop);
    } else {
      updatedStops.add(newStop);
    }

    // 4. Save back to DB
    await _client
        .from('routes')
        .update({'stops': updatedStops.map((s) => s.toJson()).toList()})
        .eq('id', routeId);
  }

  /// Update a bus stop
  /// Update a bus stop (JSONB update)
  Future<void> updateBusStop(
    String stopId,
    Map<String, dynamic> updates,
  ) async {
    // We need route_id to find the stop in the correct route
    final routeId = updates['route_id'];
    if (routeId == null) {
      throw Exception('route_id is required to update a stop in JSONB mode');
    }

    final route = await getRouteById(routeId);
    if (route == null) throw Exception('Route not found');

    final updatedStops = route.busStops.map((s) {
      if (s.id == stopId) {
        // Apply updates
        return s.copyWith(
          name: updates['name'] ?? s.name,
          lat: updates['lat'] ?? updates['latitude'] ?? s.lat,
          lng: updates['lng'] ?? updates['longitude'] ?? s.lng,
          orderIndex: updates['order_index'] ?? s.orderIndex,
        );
      }
      return s;
    }).toList();

    // Re-sort if order changed
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

  /// Delete a bus stop (JSONB remove)
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
    // PostGIS nearest neighbor on 'stops' table is no longer possible directly
    // WE must fetch all stops from routes and calculate distance in Dart
    // Or rely on a specialized postgres function that iterates routes jsonb (expensive)
    // For now, doing Dart-side calculation

    final allStops = await getAllBusStops();

    // Sort by distance (Haversine simplified)
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

  // ============================================
  // VEHICLE OBSERVATION / STATE QUERIES
  // ============================================

  /// Insert raw GPS observation
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

  /// Stream all vehicle states
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
  // DASHBOARD / STATS QUERIES
  // ============================================

  Future<int> getAvailableBusCount() async {
    final response = await _client
        .from('buses')
        .select()
        .eq('is_available', true)
        .count(CountOption.exact);

    return response.count;
  }

  Future<int> getTotalBusCount() async {
    final response = await _client
        .from('buses')
        .select()
        .count(CountOption.exact);

    return response.count;
  }

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

  Future<Map<String, dynamic>?> authenticateAdmin(
    String username,
    String password,
  ) async {
    final response = await _client
        .from('admins')
        .select()
        .eq('username', username)
        .eq('password_hash', password)
        .eq('is_active', true)
        .maybeSingle();

    return response;
  }

  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    final response = await _client
        .from('admins')
        .select()
        .order('username', ascending: true);

    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<Map<String, dynamic>> createAdmin({
    required String username,
    required String password,
    String? name,
  }) async {
    final response = await _client
        .from('admins')
        .insert({
          'username': username,
          'password_hash': password,
          'name': name,
          'is_active': true,
        })
        .select()
        .single();

    return response;
  }

  Future<void> updateAdmin(String adminId, Map<String, dynamic> updates) async {
    await _client.from('admins').update(updates).eq('id', adminId);
  }

  Future<void> deleteAdmin(String adminId) async {
    await _client.from('admins').delete().eq('id', adminId);
  }

  Future<List<UserModel>> getAllConductors() async {
    final response = await _client
        .from('users')
        .select()
        .eq('role', 'conductor')
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((user) => UserModel.fromJson(user)).toList();
  }

  Future<void> assignBusToConductor(String conductorId, String? busId) async {
    await _client.from('users').update({'bus_id': null}).eq('id', conductorId);

    if (busId != null) {
      await _client
          .from('users')
          .update({'bus_id': busId})
          .eq('id', conductorId);

      await _client
          .from('buses')
          .update({'conductor_id': conductorId})
          .eq('id', busId);
    }
  }

  Future<void> updateBus(String busId, Map<String, dynamic> updates) async {
    await _client.from('buses').update(updates).eq('id', busId);
  }

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

  Future<void> deleteBus(String busId) async {
    await _client.from('users').update({'bus_id': null}).eq('bus_id', busId);
    await _client.from('vehicle_state').delete().eq('bus_id', busId);
    await _client.from('buses').delete().eq('id', busId);
  }

  Future<void> deleteConductor(String conductorId) async {
    await _client
        .from('buses')
        .update({'conductor_id': null})
        .eq('conductor_id', conductorId);

    await _client.from('users').delete().eq('id', conductorId);
  }

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

  Future<void> updateConductor(
    String conductorId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('users').update(updates).eq('id', conductorId);
  }
}
