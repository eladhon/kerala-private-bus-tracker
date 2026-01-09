/// SOS queries for Supabase operations
library;

import 'package:flutter/foundation.dart';
import '../supabase_service.dart';
import '../../models/sos_alert_model.dart';

/// SOS-related database operations
class SosQueries {
  final _supabase = SupabaseService().client;

  /// Create a new SOS alert
  Future<SosAlertModel?> createAlert({
    required String userId,
    required String userRole,
    String? busId,
    String? routeId,
    required double lat,
    required double lng,
    required SosAlertType alertType,
    String? description,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'user_role': userRole,
        'bus_id': busId,
        'route_id': routeId,
        'lat': lat,
        'lng': lng,
        'alert_type': alertType.value,
        'description': description,
        'status': 'active',
      };

      final response = await _supabase
          .from('sos_alerts')
          .insert(data)
          .select()
          .single();

      return SosAlertModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating SOS alert: $e');
      return null;
    }
  }

  /// Get active alerts (admin view)
  Future<List<SosAlertModel>> getActiveAlerts() async {
    try {
      final response = await _supabase
          .from('sos_alerts')
          .select('*, users!user_id(name), buses(name)')
          .inFilter('status', ['active', 'acknowledged', 'responding'])
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SosAlertModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting active alerts: $e');
      return [];
    }
  }

  /// Get user's SOS history
  Future<List<SosAlertModel>> getUserAlerts(String userId) async {
    try {
      final response = await _supabase
          .from('sos_alerts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      return (response as List)
          .map((json) => SosAlertModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting user alerts: $e');
      return [];
    }
  }

  /// Acknowledge an alert
  Future<bool> acknowledgeAlert(String alertId, String adminId) async {
    try {
      await _supabase
          .from('sos_alerts')
          .update({
            'status': 'acknowledged',
            'acknowledged_by': adminId,
            'acknowledged_at': DateTime.now().toIso8601String(),
          })
          .eq('id', alertId);
      return true;
    } catch (e) {
      debugPrint('Error acknowledging alert: $e');
      return false;
    }
  }

  /// Resolve an alert
  Future<bool> resolveAlert(String alertId, {bool isFalseAlarm = false}) async {
    try {
      await _supabase
          .from('sos_alerts')
          .update({
            'status': isFalseAlarm ? 'false_alarm' : 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', alertId);
      return true;
    } catch (e) {
      debugPrint('Error resolving alert: $e');
      return false;
    }
  }

  /// Stream active alerts for real-time
  Stream<List<SosAlertModel>> streamActiveAlerts() {
    return _supabase
        .from('sos_alerts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (list) => list
              .map((json) => SosAlertModel.fromJson(json))
              .where((alert) => alert.isActive)
              .toList(),
        );
  }
}
