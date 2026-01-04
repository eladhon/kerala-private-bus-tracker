import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

/// Service for managing map tile caching (native implementation)
/// This file is used on native platforms where ObjectBox is supported
class TileCacheService {
  static const String _storeName = 'kerala_bus_map_tiles';
  static FMTCStore? _store;
  static bool _isSupported = false;

  /// Check if tile caching is supported on current platform
  static bool get isSupported => _isSupported;

  /// Initialize the tile caching system
  static Future<void> initialize() async {
    try {
      await FMTCObjectBoxBackend().initialise();
      _store = FMTCStore(_storeName);
      await _store!.manage.create();
      _isSupported = true;
    } catch (e) {
      _isSupported = false;
      rethrow;
    }
  }

  /// Get the tile provider with caching
  static FMTCTileProvider? getTileProvider() {
    if (!_isSupported || _store == null) return null;
    // ignore: deprecated_member_use
    return _store!.getTileProvider();
  }

  /// Get store statistics
  static Future<Map<String, dynamic>> getStats() async {
    if (!_isSupported || _store == null) {
      return {'initialized': false, 'platform': 'native'};
    }

    final stats = await _store!.stats.all;
    return {
      'initialized': true,
      'platform': 'native',
      'tileCount': stats.length,
      'size': stats.size,
      'hits': stats.hits,
      'misses': stats.misses,
    };
  }

  /// Clear the tile cache
  static Future<void> clearCache() async {
    if (_isSupported && _store != null) {
      await _store!.manage.reset();
    }
  }
}
