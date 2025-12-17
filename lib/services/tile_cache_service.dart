/// Conditional export for TileCacheService
/// Uses web stub on web platform, native implementation elsewhere
library;

export 'tile_cache_service_web.dart'
    if (dart.library.io) 'tile_cache_service_native.dart';
