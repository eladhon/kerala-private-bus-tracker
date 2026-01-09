/// User-related Supabase queries
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';
import '../../models/user_model.dart';
import '../../models/user_preference_model.dart';
import '../../models/user_trip_history_model.dart';
import '../../models/student_application_model.dart';

/// User queries module
class UserQueries {
  final SupabaseClient _client = SupabaseService().client;

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
    bool isStudent = false,
  }) async {
    final response = await _client
        .from('users')
        .insert({
          'phone': phone,
          'name': name,
          'role': role,
          'bus_id': busId,
          'is_student': isStudent,
        })
        .select()
        .single();

    return UserModel.fromJson(response);
  }

  /// Update user details
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await _client.from('users').update(updates).eq('id', userId);
  }

  /// Update user student status
  Future<void> updateUserStudentStatus(String userId, bool isStudent) async {
    await _client
        .from('users')
        .update({'is_student': isStudent})
        .eq('id', userId);
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

  /// Get user preferences
  Future<UserPreferenceModel?> getUserPreferences(String userId) async {
    final response = await _client
        .from('user_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response != null) {
      return UserPreferenceModel.fromJson(response);
    }
    return null;
  }

  /// Upsert user preferences
  Future<void> upsertUserPreferences(UserPreferenceModel preferences) async {
    await _client.from('user_preferences').upsert(preferences.toJson());
  }

  // ============================================
  // FAVORITES QUERIES
  // ============================================

  /// Toggle bus favorite status
  Future<bool> toggleFavorite(String busId, String userId) async {
    final exists = await _client
        .from('user_favorites')
        .select()
        .eq('user_id', userId)
        .eq('bus_id', busId)
        .maybeSingle();

    if (exists != null) {
      await _client
          .from('user_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('bus_id', busId);
      return false;
    } else {
      await _client.from('user_favorites').insert({
        'user_id': userId,
        'bus_id': busId,
      });
      return true;
    }
  }

  /// Check if bus is favorite
  Future<bool> isBusFavorite(String busId, String userId) async {
    final response = await _client
        .from('user_favorites')
        .select()
        .eq('user_id', userId)
        .eq('bus_id', busId)
        .maybeSingle();
    return response != null;
  }

  // ============================================
  // CONDUCTOR QUERIES
  // ============================================

  /// Get all conductors
  Future<List<UserModel>> getAllConductors() async {
    final response = await _client
        .from('users')
        .select()
        .eq('role', 'conductor')
        .order('name', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((user) => UserModel.fromJson(user)).toList();
  }

  /// Assign bus to conductor
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

  /// Create conductor
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
          'is_student': false,
        })
        .select()
        .single();

    return UserModel.fromJson(response);
  }

  /// Update conductor
  Future<void> updateConductor(
    String conductorId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('users').update(updates).eq('id', conductorId);
  }

  /// Delete conductor
  Future<void> deleteConductor(String conductorId) async {
    await _client
        .from('buses')
        .update({'conductor_id': null})
        .eq('conductor_id', conductorId);

    await _client.from('users').delete().eq('id', conductorId);
  }

  // ============================================
  // USER HISTORY QUERIES
  // ============================================

  /// Get trip history for a user
  Future<List<UserTripHistoryModel>> getUserTripHistory(String userId) async {
    final response = await _client
        .from('user_trip_history')
        .select('*, buses(name), routes(name, start_location, end_location)')
        .eq('user_id', userId)
        .order('trip_date', ascending: false);

    final data = response as List<dynamic>? ?? [];
    return data.map((h) => UserTripHistoryModel.fromJson(h)).toList();
  }

  /// Add a trip to user history
  Future<void> addUserTripToHistory({
    required String userId,
    required String busId,
    String? routeId,
  }) async {
    await _client.from('user_trip_history').insert({
      'user_id': userId,
      'bus_id': busId,
      'route_id': routeId,
    });
  }

  // ============================================
  // STUDENT APPLICATION QUERIES
  // ============================================

  /// Submit a student application
  Future<void> createStudentApplication({
    required String userId,
    required String userName,
    required String schoolName,
    required String idCardUrl,
  }) async {
    await _client.from('student_applications').insert({
      'user_id': userId,
      'user_name': userName,
      'school_name': schoolName,
      'id_card_url': idCardUrl,
      'status': 'pending',
    });
  }

  /// Get application status for a user
  Future<StudentApplicationModel?> getUserApplication(String userId) async {
    final response = await _client
        .from('student_applications')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response != null) {
      return StudentApplicationModel.fromJson(response);
    }
    return null;
  }

  /// Get pending applications (Admin)
  Future<List<StudentApplicationModel>> getPendingApplications() async {
    final response = await _client
        .from('student_applications')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((a) => StudentApplicationModel.fromJson(a)).toList();
  }

  /// Update application status (Admin)
  Future<void> updateApplicationStatus(String appId, String status) async {
    await _client
        .from('student_applications')
        .update({
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', appId);
  }
}
