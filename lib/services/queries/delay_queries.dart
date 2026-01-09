/// Delay queries for Supabase operations
library;

import 'package:flutter/foundation.dart';
import '../supabase_service.dart';
import '../../models/delay_report_model.dart';

/// Delay-related database operations
class DelayQueries {
  final _supabase = SupabaseService().client;

  /// Get active delay for a bus
  Future<DelayReportModel?> getActiveDelay(String busId) async {
    try {
      final response = await _supabase
          .from('delay_reports')
          .select()
          .eq('bus_id', busId)
          .eq('is_active', true)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return DelayReportModel.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting active delay: $e');
      return null;
    }
  }

  /// Report a delay (conductor only)
  Future<DelayReportModel?> reportDelay({
    required String busId,
    String? routeId,
    required int delayMinutes,
    required DelayReason reason,
    String? notes,
    required String reportedBy,
  }) async {
    try {
      final data = {
        'bus_id': busId,
        'route_id': routeId,
        'delay_minutes': delayMinutes,
        'reason': reason.value,
        'notes': notes,
        'reported_by': reportedBy,
        'expires_at': DateTime.now().add(Duration(hours: 2)).toIso8601String(),
        'is_active': true,
      };

      final response = await _supabase
          .from('delay_reports')
          .insert(data)
          .select()
          .single();

      return DelayReportModel.fromJson(response);
    } catch (e) {
      debugPrint('Error reporting delay: $e');
      return null;
    }
  }

  /// Cancel a delay report
  Future<bool> cancelDelay(String delayId) async {
    try {
      await _supabase
          .from('delay_reports')
          .update({'is_active': false})
          .eq('id', delayId);
      return true;
    } catch (e) {
      debugPrint('Error canceling delay: $e');
      return false;
    }
  }

  /// Get delay history for a bus
  Future<List<DelayReportModel>> getDelayHistory(
    String busId, {
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('delay_reports')
          .select()
          .eq('bus_id', busId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => DelayReportModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting delay history: $e');
      return [];
    }
  }

  /// Stream active delays for a bus
  Stream<DelayReportModel?> streamActiveDelay(String busId) {
    return _supabase
        .from('delay_reports')
        .stream(primaryKey: ['id'])
        .eq('bus_id', busId)
        .order('created_at', ascending: false)
        .limit(1)
        .map((list) {
          if (list.isEmpty) return null;
          final report = DelayReportModel.fromJson(list.first);
          return report.isStillActive ? report : null;
        });
  }
}
