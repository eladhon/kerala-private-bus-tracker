import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimalist "Material You" app theme configuration
class AppTheme {
  // Light Theme Colors
  static const Color _lightPrimary = Color(0xFF1B5E20); // Deep Green
  static const Color _lightSurface = Colors.white;
  static const Color _lightSurfaceVariant = Color(
    0xFFF1F5F9,
  ); // Very light grey
  static const Color _lightOnSurface = Color(0xFF1E293B); // Slate 800

  // Dark Theme Colors
  static const Color _darkPrimary = Color(0xFF81C784); // Light Green
  static const Color _darkSurface = Color(0xFF121212); // Almost Black
  static const Color _darkSurfaceVariant = Color(0xFF1E1E1E); // Dark Grey
  static const Color _darkOnSurface = Color(0xFFE2E8F0); // Slate 200

  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    return GoogleFonts.outfitTextTheme(
      base,
    ).apply(displayColor: color, bodyColor: color);
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _lightPrimary,
        brightness: Brightness.light,
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        surfaceContainer: _lightSurfaceVariant,
        primary: _lightPrimary,
      ),
      scaffoldBackgroundColor: _lightSurface,
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, _lightOnSurface),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: _lightOnSurface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceVariant,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _lightPrimary, width: 2),
        ),
        labelStyle: TextStyle(color: _lightOnSurface.withValues(alpha: 0.6)),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurfaceVariant,
        selectedColor: _lightPrimary.withValues(alpha: 0.1),
        shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
        labelStyle: TextStyle(
          color: _lightOnSurface,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: _lightPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: _lightOnSurface, size: 20),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurfaceVariant,
        indicatorColor: _lightPrimary.withValues(alpha: 0.1),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _lightPrimary);
          }
          return IconThemeData(color: _lightOnSurface.withValues(alpha: 0.6));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? _lightPrimary
              : _lightOnSurface.withValues(alpha: 0.6);
          return GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: _lightPrimary.withValues(alpha: 0.1),
        groupAlignment: -0.9,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: const IconThemeData(color: _lightPrimary),
        unselectedIconTheme: IconThemeData(
          color: _lightOnSurface.withValues(alpha: 0.6),
        ),
        selectedLabelTextStyle: GoogleFonts.outfit(
          color: _lightPrimary,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelTextStyle: GoogleFonts.outfit(
          color: _lightOnSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _darkPrimary,
        brightness: Brightness.dark,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        surfaceContainer: _darkSurfaceVariant,
        primary: _darkPrimary,
      ),
      scaffoldBackgroundColor: _darkSurface,
    );

    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme, _darkOnSurface),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: Colors.black, // Dark button text
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceVariant,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _darkPrimary, width: 2),
        ),
        labelStyle: TextStyle(color: _darkOnSurface.withValues(alpha: 0.6)),
      ),
      cardTheme: CardThemeData(
        color: _darkSurfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceVariant,
        selectedColor: _darkPrimary.withValues(alpha: 0.2),
        shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
        labelStyle: TextStyle(
          color: _darkOnSurface,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: _darkPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: _darkOnSurface, size: 20),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurfaceVariant,
        indicatorColor: _darkPrimary.withValues(alpha: 0.2),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _darkPrimary);
          }
          return IconThemeData(color: _darkOnSurface.withValues(alpha: 0.6));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? _darkPrimary
              : _darkOnSurface.withValues(alpha: 0.6);
          return GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _darkSurface,
        indicatorColor: _darkPrimary.withValues(alpha: 0.2),
        groupAlignment: -0.9,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: const IconThemeData(color: _darkPrimary),
        unselectedIconTheme: IconThemeData(
          color: _darkOnSurface.withValues(alpha: 0.6),
        ),
        selectedLabelTextStyle: GoogleFonts.outfit(
          color: _darkPrimary,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelTextStyle: GoogleFonts.outfit(
          color: _darkOnSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
