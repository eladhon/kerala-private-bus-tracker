// Supabase Configuration
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Get these from your Supabase project settings
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_KEY'] ?? '';
}
