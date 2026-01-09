/// Authentication-related Supabase queries
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

/// Authentication queries module
class AuthQueries {
  final SupabaseClient _client = SupabaseService().client;

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

  /// Get current authenticated user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;
}
