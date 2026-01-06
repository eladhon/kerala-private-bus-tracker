import 'package:flutter/material.dart';

/// Manages the app's theme mode (Light/Dark/System)
/// Uses a singleton pattern to be accessible globally without context.
class ThemeManager extends ChangeNotifier {
  // Private constructor
  ThemeManager._();

  // Singleton instance
  static final ThemeManager instance = ThemeManager._();

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Toggles between Light and Dark mode.
  /// If currently System, it checks platform brightness to switch to the opposite.
  void toggleTheme() {
    if (_themeMode == ThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _themeMode = brightness == Brightness.light
          ? ThemeMode.dark
          : ThemeMode.light;
    } else {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    }
    notifyListeners();
  }
}
