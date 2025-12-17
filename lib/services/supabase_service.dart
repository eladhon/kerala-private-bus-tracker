import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Singleton service for Supabase client access
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase - call this in main() before runApp
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  /// Check if user is currently logged in
  bool get isLoggedIn => client.auth.currentUser != null;

  /// Get current user ID
  String? get currentUserId => client.auth.currentUser?.id;

  /// Get current user phone
  String? get currentUserPhone => client.auth.currentUser?.phone;
}
