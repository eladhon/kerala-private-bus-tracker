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
  /// Check if user is currently logged in
  @Deprecated('Disabled for demo mode')
  bool get isLoggedIn => false; // Disabled for demo mode using public.users only

  /// Get current user ID
  @Deprecated('Disabled for demo mode')
  String? get currentUserId => null; // Disabled for demo mode using public.users only

  /// Get current user phone
  @Deprecated('Disabled for demo mode')
  String? get currentUserPhone => null; // Disabled for demo mode using public.users only
}
