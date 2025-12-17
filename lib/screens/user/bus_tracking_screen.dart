import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/bus_location_model.dart';

/// Live bus tracking screen with real-time map updates
class BusTrackingScreen extends StatefulWidget {
  final BusModel bus;

  const BusTrackingScreen({super.key, required this.bus});

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  final _queries = SupabaseQueries();
  final MapController _mapController = MapController();
  BusLocationModel? _busLocation;
  Position? _userPosition;
  StreamSubscription? _locationSubscription;
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _followBus = true;
  bool _showUserLocation = true;

  // Refresh every 10 seconds
  static const int _refreshIntervalSeconds = 10;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    // Get user's current location
    await _getUserLocation();

    // Get initial bus location
    await _fetchBusLocation();

    // Start real-time stream for bus location
    _locationSubscription = _queries
        .streamBusLocation(widget.bus.id)
        .listen(
          (location) {
            if (mounted && location != null) {
              setState(() => _busLocation = location);
              if (_followBus) {
                _centerOnBus();
              }
            }
          },
          onError: (error) {
            debugPrint('Location stream error: $error');
          },
        );

    // Also poll every 10 seconds as backup
    _refreshTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalSeconds),
      (_) => _fetchBusLocation(),
    );
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _userPosition = position);
    } catch (e) {
      debugPrint('Error getting user location: $e');
    }
  }

  Future<void> _fetchBusLocation() async {
    try {
      final location = await _queries.getBusLocation(widget.bus.id);
      if (mounted && location != null) {
        setState(() {
          _busLocation = location;
          _isLoading = false;
        });
        if (_followBus) {
          _centerOnBus();
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching bus location: $e');
      setState(() => _isLoading = false);
    }
  }

  void _centerOnBus() {
    if (_busLocation != null) {
      _mapController.move(_busLocation!.latLng, 15);
    }
  }

  void _centerOnUser() {
    if (_userPosition != null) {
      _mapController.move(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
        15,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _busLocation?.latLng ?? const LatLng(10.8505, 76.2711),
              initialZoom: 12,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() => _followBus = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.keralab.bustracker',
              ),
              // User location layer with flutter_map_location_marker
              if (_showUserLocation)
                CurrentLocationLayer(
                  style: LocationMarkerStyle(
                    marker: const DefaultLocationMarker(
                      color: Colors.blue,
                      child: Icon(Icons.person, color: Colors.white, size: 16),
                    ),
                    markerSize: const Size(30, 30),
                    accuracyCircleColor: Colors.blue.withValues(alpha: 0.1),
                    headingSectorColor: Colors.blue.withValues(alpha: 0.8),
                  ),
                ),
              // Bus location marker
              if (_busLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _busLocation!.latLng,
                      width: 50,
                      height: 50,
                      child: _buildBusMarker(),
                    ),
                  ],
                ),
            ],
          ),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.bus.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.bus.registrationNumber,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Toggle user location visibility
                      IconButton(
                        onPressed: () {
                          setState(
                            () => _showUserLocation = !_showUserLocation,
                          );
                        },
                        icon: Icon(
                          _showUserLocation
                              ? Icons.person_pin_circle
                              : Icons.person_off,
                        ),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Row
                    Row(
                      children: [
                        _buildStatusChip(
                          icon: widget.bus.isAvailable
                              ? Icons.check_circle
                              : Icons.cancel,
                          label: widget.bus.isAvailable
                              ? 'Available'
                              : 'Not Available',
                          color: widget.bus.isAvailable
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        if (_busLocation != null)
                          _buildStatusChip(
                            icon: Icons.speed,
                            label: _busLocation!.speedDisplay,
                            color: Colors.blue,
                          ),
                        const Spacer(),
                        // Refresh indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_refreshIntervalSeconds}s',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Location Info
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      )
                    else if (_busLocation == null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Location not available',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Last updated: ${_busLocation!.lastUpdatedDisplay}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_busLocation!.latitude.toStringAsFixed(4)}, ${_busLocation!.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // Floating Action Buttons
          Positioned(
            bottom: 240,
            right: 16,
            child: Column(
              children: [
                // Center on user button
                if (_userPosition != null)
                  FloatingActionButton.small(
                    heroTag: 'user_location',
                    onPressed: _centerOnUser,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.person_pin, color: Colors.blue),
                  ),
                const SizedBox(height: 8),
                // Center on bus button
                if (!_followBus && _busLocation != null)
                  FloatingActionButton.small(
                    heroTag: 'bus_location',
                    onPressed: () {
                      setState(() => _followBus = true);
                      _centerOnBus();
                    },
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.directions_bus,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusMarker() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: const Icon(Icons.directions_bus, color: Colors.white, size: 30),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
