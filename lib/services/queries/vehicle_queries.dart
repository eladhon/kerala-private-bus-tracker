/// Vehicle state and observation queries
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';
import '../../models/vehicle_state_model.dart';
import '../../models/bus_trip_model.dart';

/// Vehicle queries module
class VehicleQueries {
  final SupabaseClient _client = SupabaseService().client;

  // ============================================
  // VEHICLE OBSERVATION / STATE QUERIES
  // ============================================

  /// Insert raw GPS observation and update vehicle state for real-time streaming
  Future<void> insertVehicleObservation({
    required String busId,
    required double lat,
    required double lng,
    double? accuracyM,
    double? speedMps,
    double? headingDeg,
  }) async {
    // Insert observation and get ID
    final observationResponse = await _client
        .from('vehicle_observations')
        .insert({
          'bus_id': busId,
          'lat': lat,
          'lng': lng,
          'accuracy_m': accuracyM,
          'speed_mps': speedMps,
          'heading_deg': headingDeg,
          'observed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    // Upsert to vehicle_state for real-time streaming
    await _client.from('vehicle_state').upsert({
      'bus_id': busId,
      'lat': lat,
      'lng': lng,
      'speed_mps': speedMps ?? 0,
      'heading_deg': headingDeg ?? 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'observation_id': observationResponse['id'],
    });
  }

  /// Get current state of all vehicles
  Future<List<VehicleStateModel>> getAllVehicleStates() async {
    try {
      final response = await _client.from('vehicle_state').select();
      final data = response as List<dynamic>;
      return data.map((json) => VehicleStateModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error fetching vehicle states: $e");
      return [];
    }
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
    List<String> busIds,
  ) async {
    if (busIds.isEmpty) return [];

    final response = await _client
        .from('vehicle_state')
        .select()
        .inFilter('bus_id', busIds);

    final data = response as List<dynamic>? ?? [];
    return data.map((state) => VehicleStateModel.fromJson(state)).toList();
  }

  // ============================================
  // TRIP MANAGEMENT QUERIES
  // ============================================

  /// Start a new trip for a bus on a route
  Future<BusTripModel> startTrip({
    required String busId,
    required String routeId,
  }) async {
    // Auto-close previous active trips
    await _client
        .from('bus_trips')
        .update({
          'status': 'completed',
          'end_time': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('bus_id', busId)
        .eq('status', 'active');

    // Create new active trip
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
}
