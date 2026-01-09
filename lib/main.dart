import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/supabase_service.dart';
import 'services/tile_cache_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/web_app_selector.dart';
import 'app_theme.dart';

import 'services/theme_manager.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Set preferred orientations (only on mobile)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
    // App will still run, but database features won't work
  }

  // Initialize tile caching for offline maps (skipped on web)
  try {
    await TileCacheService.initialize();
    debugPrint('Tile cache initialized successfully');
  } catch (e) {
    debugPrint('Tile cache initialization error: $e');
    // App will still work with online-only maps
  }

  // Initialize Notification Service
  try {
    await NotificationService().init();
    debugPrint('Notification Service initialized');
  } catch (e) {
    debugPrint('Notification Service initialization error: $e');
  }

  runApp(const KeralaBusTrackerApp());
}

class KeralaBusTrackerApp extends StatelessWidget {
  const KeralaBusTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'Kerala Bus Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeManager.instance.themeMode,
          // On web: show app selector (admin or mobile)
          // On mobile: go directly to login
          home: kIsWeb ? const WebAppSelector() : const LoginScreen(),
        );
      },
    );
  }
}
