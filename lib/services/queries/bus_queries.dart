/// Bus-related Supabase queries
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';
import '../../models/bus_model.dart';
import '../../models/bus_schedule_model.dart';

/// Bus queries module
class BusQueries {
  final SupabaseClient _client = SupabaseService().client;

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
    debugPrint('Found ${data.length} buses for route $routeId');
    return data.map((bus) => BusModel.fromJson(bus)).toList();
  }

  /// Get all buses (available and unavailable)
  Future<List<BusModel>> getAvailableBuses() async {
    final response = await _client
        .from('buses')
        .select()
        .order('is_available', ascending: false)
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

  /// Get buses by IDs (for recently viewed)
  Future<List<BusModel>> getBusesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final response = await _client
        .from('buses')
        .select()
        .filter('id', 'in', ids);

    final data = response as List<dynamic>? ?? [];
    return data.map((bus) => BusModel.fromJson(bus)).toList();
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
  Future<void> setBusAvailability(
    String busId,
    bool isAvailable, {
    String? reason,
  }) async {
    final Map<String, dynamic> updates = {'is_available': isAvailable};
    if (!isAvailable && reason != null) {
      updates['unavailability_reason'] = reason;
    } else if (isAvailable) {
      updates['unavailability_reason'] = null;
    }

    await _client.from('buses').update(updates).eq('id', busId);
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

  /// Update bus
  Future<void> updateBus(String busId, Map<String, dynamic> updates) async {
    if (updates.containsKey('schedule') &&
        updates['schedule'] is List<BusScheduleModel>) {
      updates['schedule'] = (updates['schedule'] as List<BusScheduleModel>)
          .map((e) => e.toJson())
          .toList();
    }
    await _client.from('buses').update(updates).eq('id', busId);
  }

  /// Create bus
  Future<BusModel> createBus({
    required String name,
    required String registrationNumber,
    required String routeId,
    String? conductorId,
    bool isAvailable = false,
    String? departureTime,
    List<BusScheduleModel> schedule = const [],
  }) async {
    final response = await _client
        .from('buses')
        .insert({
          'name': name,
          'registration_number': registrationNumber,
          'route_id': routeId,
          'conductor_id': conductorId,
          'is_available': isAvailable,
          'departure_time': departureTime,
          'schedule': schedule.map((e) => e.toJson()).toList(),
        })
        .select()
        .single();

    return BusModel.fromJson(response);
  }

  /// Delete bus
  Future<void> deleteBus(String busId) async {
    await _client.from('users').update({'bus_id': null}).eq('bus_id', busId);
    await _client.from('vehicle_state').delete().eq('bus_id', busId);
    await _client.from('buses').delete().eq('id', busId);
  }

  /// Get buses with their vehicle state locations
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

  /// Get available bus count
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
}
