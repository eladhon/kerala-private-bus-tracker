/// Stub implementation of TileCacheService for web platform
/// This file is used on web where ObjectBox/FMTC is not supported
library;

/// Service for managing map tile caching (web stub - no-op implementation)
class TileCacheService {
  static bool get isSupported => false;

  /// Initialize the tile caching system (no-op on web)
  static Future<void> initialize() async {
    // No-op on web - ObjectBox doesn't support web
  }

  /// Get the tile provider with caching (always null on web)
  static dynamic getTileProvider() => null;

  /// Get store statistics
  static Future<Map<String, dynamic>> getStats() async {
    return {'initialized': false, 'platform': 'web'};
  }

  /// Clear the tile cache (no-op on web)
  static Future<void> clearCache() async {
    // No-op on web
  }
}
