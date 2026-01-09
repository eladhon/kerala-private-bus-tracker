/// Shift queries for Supabase operations
library;

import 'package:flutter/foundation.dart';
import '../supabase_service.dart';
import '../../models/conductor_shift_model.dart';

/// Shift-related database operations
class ShiftQueries {
  final _supabase = SupabaseService().client;

  /// Get all shifts for a conductor
  Future<List<ConductorShiftModel>> getConductorShifts(
    String conductorId, {
    int daysAhead = 7,
  }) async {
    try {
      final response = await _supabase
          .from('conductor_shifts')
          .select('*, users!conductor_id(name), buses(name), routes(name)')
          .eq('conductor_id', conductorId)
          .gte('start_time', DateTime.now().toIso8601String())
          .lte(
            'start_time',
            DateTime.now().add(Duration(days: daysAhead)).toIso8601String(),
          )
          .order('start_time', ascending: true);

      return (response as List)
          .map((json) => ConductorShiftModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting conductor shifts: $e');
      return [];
    }
  }

  /// Get all shifts (admin view)
  Future<List<ConductorShiftModel>> getAllShifts({
    DateTime? fromDate,
    DateTime? toDate,
    String? status,
  }) async {
    try {
      var query = _supabase
          .from('conductor_shifts')
          .select('*, users!conductor_id(name), buses(name), routes(name)');

      if (fromDate != null) {
        query = query.gte('start_time', fromDate.toIso8601String());
      }
      if (toDate != null) {
        query = query.lte('start_time', toDate.toIso8601String());
      }
      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('start_time', ascending: true);

      return (response as List)
          .map((json) => ConductorShiftModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting all shifts: $e');
      return [];
    }
  }

  /// Create a new shift
  Future<ConductorShiftModel?> createShift({
    required String conductorId,
    required String busId,
    String? routeId,
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
    String? createdBy,
  }) async {
    try {
      final data = {
        'conductor_id': conductorId,
        'bus_id': busId,
        'route_id': routeId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'status': 'scheduled',
        'notes': notes,
        'created_by': createdBy,
      };

      final response = await _supabase
          .from('conductor_shifts')
          .insert(data)
          .select()
          .single();

      return ConductorShiftModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating shift: $e');
      return null;
    }
  }

  /// Update shift status
  Future<bool> updateShiftStatus(String shiftId, ShiftStatus status) async {
    try {
      await _supabase
          .from('conductor_shifts')
          .update({
            'status': status.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', shiftId);
      return true;
    } catch (e) {
      debugPrint('Error updating shift status: $e');
      return false;
    }
  }

  /// Delete a shift
  Future<bool> deleteShift(String shiftId) async {
    try {
      await _supabase.from('conductor_shifts').delete().eq('id', shiftId);
      return true;
    } catch (e) {
      debugPrint('Error deleting shift: $e');
      return false;
    }
  }

  /// Get today's shifts for a bus
  Future<List<ConductorShiftModel>> getBusShiftsToday(String busId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _supabase
          .from('conductor_shifts')
          .select('*, users!conductor_id(name), buses(name), routes(name)')
          .eq('bus_id', busId)
          .gte('start_time', startOfDay.toIso8601String())
          .lt('start_time', endOfDay.toIso8601String())
          .order('start_time', ascending: true);

      return (response as List)
          .map((json) => ConductorShiftModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting bus shifts: $e');
      return [];
    }
  }
}
