/// Admin and moderation related queries
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';
import '../../models/conductor_review_model.dart';
import '../../models/conductor_report_model.dart';
import '../../models/bus_model.dart';

/// Admin queries module
class AdminQueries {
  final SupabaseClient _client = SupabaseService().client;

  // ============================================
  // ADMIN AUTHENTICATION
  // ============================================

  /// Authenticate admin user
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

  /// Get all admins
  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    final response = await _client
        .from('admins')
        .select()
        .order('username', ascending: true);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Create admin
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

  /// Update admin
  Future<void> updateAdmin(String adminId, Map<String, dynamic> updates) async {
    await _client.from('admins').update(updates).eq('id', adminId);
  }

  /// Delete admin
  Future<void> deleteAdmin(String adminId) async {
    await _client.from('admins').delete().eq('id', adminId);
  }

  // ============================================
  // RATINGS & REVIEWS QUERIES
  // ============================================

  /// Get reviews for a specific conductor
  Future<List<ConductorReviewModel>> getConductorReviews(
    String conductorId,
  ) async {
    final response = await _client
        .from('conductor_reviews')
        .select('*, users:users!conductor_reviews_user_id_fkey(name)')
        .eq('conductor_id', conductorId)
        .order('created_at', ascending: false);

    final data = response as List<dynamic>? ?? [];
    return data.map((r) => ConductorReviewModel.fromJson(r)).toList();
  }

  /// Get ALL reviews (for Admin Moderation)
  Future<List<ConductorReviewModel>> getAllReviews() async {
    final response = await _client
        .from('conductor_reviews')
        .select('*, users:users!conductor_reviews_user_id_fkey(name)')
        .order('created_at', ascending: false);

    final data = response as List<dynamic>? ?? [];
    return data.map((r) => ConductorReviewModel.fromJson(r)).toList();
  }

  /// Delete a review (Admin)
  Future<void> deleteReview(String reviewId) async {
    await _client.from('conductor_reviews').delete().eq('id', reviewId);
  }

  /// Add a review for a conductor
  Future<void> addConductorReview(ConductorReviewModel review) async {
    // Check for bad words
    if (review.reviewText != null && review.reviewText!.isNotEmpty) {
      final filters = await getModerationFilters();
      final textLower = review.reviewText!.toLowerCase();

      for (final badWord in filters) {
        if (textLower.contains(badWord.toLowerCase())) {
          throw Exception('Review contains inappropriate language: "$badWord"');
        }
      }
    }

    await _client.from('conductor_reviews').insert({
      'conductor_id': review.conductorId,
      'user_id': review.userId,
      'rating': review.rating,
      'review_text': review.reviewText,
    });
  }

  /// Get a specific review by the current user for a conductor
  Future<ConductorReviewModel?> getConductorReview(
    String conductorId, {
    String? userId,
  }) async {
    final targetUserId = userId ?? _client.auth.currentUser?.id;
    if (targetUserId == null) return null;

    final response = await _client
        .from('conductor_reviews')
        .select()
        .eq('conductor_id', conductorId)
        .eq('user_id', targetUserId)
        .maybeSingle();

    if (response != null) {
      return ConductorReviewModel.fromJson(response);
    }
    return null;
  }

  /// Upsert (Insert or Update) a conductor review
  Future<void> upsertConductorReview({
    required String conductorId,
    required int rating,
    String? reviewText,
    String? existingReviewId,
    String? userId,
  }) async {
    final targetUserId = userId ?? _client.auth.currentUser?.id;
    if (targetUserId == null) throw Exception('User not logged in');

    final data = {
      if (existingReviewId != null) 'id': existingReviewId,
      'conductor_id': conductorId,
      'user_id': targetUserId,
      'rating': rating,
      'review_text': reviewText,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client
        .from('conductor_reviews')
        .upsert(data, onConflict: 'user_id, conductor_id');
  }

  // ============================================
  // MODERATION FILTERS QUERIES
  // ============================================

  /// Get all blocked phrases
  Future<List<String>> getModerationFilters() async {
    final response = await _client
        .from('moderation_filters')
        .select('phrase')
        .order('phrase', ascending: true);

    final data = response as List<dynamic>? ?? [];
    return data.map((item) => item['phrase'] as String).toList();
  }

  /// Add a blocked phrase
  Future<void> addModerationFilter(String phrase) async {
    await _client.from('moderation_filters').insert({'phrase': phrase});
  }

  /// Delete a blocked phrase
  Future<void> deleteModerationFilter(String phrase) async {
    await _client.from('moderation_filters').delete().eq('phrase', phrase);
  }

  // ============================================
  // CONDUCTOR REPORTS QUERIES
  // ============================================

  /// Submit a conductor report (repair/fuel)
  Future<void> submitConductorReport(ConductorReportModel report) async {
    await _client.from('conductor_reports').insert(report.toJson());
  }

  /// Get reports for a conductor by type
  Future<List<ConductorReportModel>> getConductorReports({
    required String userId,
    required String type,
  }) async {
    final response = await _client
        .from('conductor_reports')
        .select()
        .eq('user_id', userId)
        .eq('type', type)
        .order('created_at', ascending: false);

    final data = response as List<dynamic>? ?? [];
    return data.map((r) => ConductorReportModel.fromJson(r)).toList();
  }

  /// Get ALL reports by type (Admin)
  Future<List<ConductorReportModel>> getAllConductorReports(String type) async {
    final response = await _client
        .from('conductor_reports')
        .select()
        .eq('type', type)
        .order('created_at', ascending: false);

    final data = response as List<dynamic>? ?? [];
    return data.map((r) => ConductorReportModel.fromJson(r)).toList();
  }

  /// Get favorite buses for user
  Future<List<BusModel>> getFavoriteBuses(String userId) async {
    final response = await _client
        .from('user_favorites')
        .select('bus_id, buses(*)')
        .eq('user_id', userId);

    final data = response as List<dynamic>;
    return data.map((item) => BusModel.fromJson(item['buses'])).toList();
  }
}
