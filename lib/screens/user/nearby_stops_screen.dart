import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/supabase_queries.dart';
import '../../models/stop_model.dart';
import '../../models/route_model.dart';

/// Screen showing nearby bus stops with interactive map
class NearbyStopsScreen extends StatefulWidget {
  const NearbyStopsScreen({super.key});

  @override
  State<NearbyStopsScreen> createState() => _NearbyStopsScreenState();
}

class _NearbyStopsScreenState extends State<NearbyStopsScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  final _queries = SupabaseQueries();

  List<StopModel> _allStops = [];
  List<StopModel> _visibleStops = [];
  bool _isLoading = true;
  LatLng? _userLocation;
  double _currentZoom = 15.0;
  LatLng _mapCenter = const LatLng(9.9312, 76.2673); // Default: Kerala center

  // Search
  final _searchController = TextEditingController();
  bool _isSearchingLocation = false;

  // Circle radius in meters based on zoom
  double _circleRadiusMeters = 500;
  static const double _maxRadiusMeters = 1000; // 2km diameter = 1km radius
  static const double _circleScreenRadius =
      120.0; // Fixed screen radius in pixels

  // Animation for pulsing circle
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Setup pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializeScreen();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _loadUserLocation();
    await _loadAllStops();
    _updateVisibleStops();
  }

  Future<void> _loadUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _mapCenter = _userLocation!;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadAllStops() async {
    try {
      final stops = await _queries.routes.getAllBusStops();
      if (mounted) {
        setState(() {
          _allStops = stops;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stops: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateVisibleStops() {
    if (_allStops.isEmpty) return;

    const distance = Distance();
    final visible = _allStops.where((stop) {
      final stopLatLng = LatLng(stop.lat, stop.lng);
      final dist = distance.as(LengthUnit.Meter, _mapCenter, stopLatLng);
      return dist <= _circleRadiusMeters;
    }).toList();

    setState(() => _visibleStops = visible);
  }

  Future<void> _performLocationSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearchingLocation = true);
    try {
      // Use Nominatim OpenStreetMap API
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'KeralaBusTrackerUser/1.0'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final firstResult = data[0];
          final double lat = double.parse(firstResult['lat']);
          final double lng = double.parse(firstResult['lon']);
          final latLng = LatLng(lat, lng);

          if (mounted) {
            _mapController.move(latLng, 15);
            // Search radius will auto-update via onPositionChanged
            FocusScope.of(context).unfocus(); // Hide keyboard
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("No location found for '$query'")),
            );
          }
        }
      } else {
        throw Exception('Failed to load location');
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Search failed. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingLocation = false);
    }
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    _mapCenter = camera.center;
    _currentZoom = camera.zoom;

    // Calculate radius based on zoom
    // At zoom 15, radius = 500m. Each zoom level halves/doubles the radius.
    _circleRadiusMeters = (500 * pow(2, 15 - _currentZoom))
        .clamp(100, _maxRadiusMeters)
        .toDouble();

    _updateVisibleStops();
  }

  void _showStopDetails(StopModel stop) async {
    // Fetch routes for this stop
    final routes = await _queries.routes.getRoutesForStop(stop.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildStopDetailsSheet(stop, routes),
    );
  }

  Widget _buildStopDetailsSheet(StopModel stop, List<RouteModel> routes) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stop Name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  stop.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Routes passing through
          Text(
            'Routes passing through:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          if (routes.isEmpty)
            Text(
              'No routes found',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routes.map((route) {
                return Chip(
                  avatar: const Icon(Icons.directions_bus, size: 18),
                  label: Text(route.name),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                );
              }).toList(),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\ud83d\ude8f Stops Near Me'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: _currentZoom,
                    minZoom: 12,
                    maxZoom: 18,
                    onPositionChanged: _onMapPositionChanged,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.kerala_bus_tracker',
                    ),

                    // Stop Markers
                    MarkerLayer(
                      markers: _visibleStops.map((stop) {
                        return Marker(
                          point: LatLng(stop.lat, stop.lng),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showStopDetails(stop),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // User location marker
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 20,
                            height: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Fixed Circle Overlay (at screen center) - Animated
                Center(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulse ring
                            Container(
                              width:
                                  _circleScreenRadius *
                                  2 *
                                  _pulseAnimation.value,
                              height:
                                  _circleScreenRadius *
                                  2 *
                                  _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary
                                      .withValues(
                                        alpha:
                                            0.3 *
                                            (1 - _pulseAnimation.value + 0.8),
                                      ),
                                  width: 2,
                                ),
                              ),
                            ),
                            // Main circle
                            Container(
                              width: _circleScreenRadius * 2,
                              height: _circleScreenRadius * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                ),
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                              ),
                            ),
                            // Center crosshair
                            Icon(
                              Icons.add,
                              size: 24,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.6),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // Radius indicator
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.radar,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _circleRadiusMeters >= 1000
                                ? '${(_circleRadiusMeters / 1000).toStringAsFixed(1)} km'
                                : '${_circleRadiusMeters.round()} m',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _visibleStops.isEmpty
                                ? '• No stops here 😢'
                                : _visibleStops.length == 1
                                ? '• 1 stop found! 🎉'
                                : '• ${_visibleStops.length} stops nearby! 🚌',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Recenter button
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter',
                    onPressed: () {
                      if (_userLocation != null) {
                        _mapController.move(_userLocation!, 15);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),

                // Search Bar Overlay
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _performLocationSearch,
                      decoration: InputDecoration(
                        hintText: 'Search landmark (e.g. Lulu Mall)',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearchingLocation
                            ? Transform.scale(
                                scale: 0.5,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
