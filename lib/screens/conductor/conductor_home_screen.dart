import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../auth/login_screen.dart';

/// Conductor home screen with GPS tracking and availability toggle
class ConductorHomeScreen extends StatefulWidget {
  final String phoneNumber;

  const ConductorHomeScreen({super.key, required this.phoneNumber});

  @override
  State<ConductorHomeScreen> createState() => _ConductorHomeScreenState();
}

class _ConductorHomeScreenState extends State<ConductorHomeScreen> {
  final _queries = SupabaseQueries();
  final MapController _mapController = MapController();

  BusModel? _assignedBus;
  Position? _currentPosition;
  Timer? _locationTimer;
  bool _isTracking = false;
  bool _isLoading = true;
  bool _hasLocationPermission = false;

  // Server upload tracking
  // Raw GPS is now sent to server; smoothing happens via Postgres trigger
  DateTime _lastUploadTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Local update interval (for UI display)
  static const int _localUpdateIntervalSeconds = 2;
  // Server upload interval (raw GPS sent every 15s, smoothed by Postgres)
  static const int _serverUploadIntervalSeconds = 15;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      // Check location permissions
      _hasLocationPermission = await _checkLocationPermission();

      // Get assigned bus for this conductor
      final user = await _queries.getUserByPhone(widget.phoneNumber);
      if (user != null && user.busId != null) {
        final bus = await _queries.getBusById(user.busId!);
        setState(() => _assignedBus = bus);
      }
    } catch (e) {
      debugPrint('Error initializing: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _startTracking() async {
    if (!_hasLocationPermission) {
      _hasLocationPermission = await _checkLocationPermission();
      if (!_hasLocationPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission required to track bus'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isTracking = true);

    // Get initial position
    await _updateLocation();

    // Start timer-based tracking
    _locationTimer = Timer.periodic(
      const Duration(seconds: _localUpdateIntervalSeconds),
      (_) => _updateLocation(),
    );
  }

  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Store raw position for local UI display
      // Server-side smoothing handles the canonical state
      setState(() => _currentPosition = position);

      // Center map on current position
      _mapController.move(LatLng(position.latitude, position.longitude), 15);

      // Throttled upload of RAW GPS to server
      // The Postgres trigger will apply EMA smoothing
      final now = DateTime.now();
      if (_assignedBus != null &&
          now.difference(_lastUploadTime).inSeconds >=
              _serverUploadIntervalSeconds) {
        await _queries.insertVehicleObservation(
          busId: _assignedBus!.id,
          lat: position.latitude,
          lng: position.longitude,
          accuracyM: position.accuracy,
          speedMps: position.speed, // Already in m/s from Geolocator
          headingDeg: position.heading,
        );
        _lastUploadTime = now;
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  void _stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (mounted) {
      setState(() => _isTracking = false);
    }
  }

  Future<void> _toggleAvailability() async {
    if (_assignedBus == null) return;

    final newAvailability = !_assignedBus!.isAvailable;

    try {
      await _queries.setBusAvailability(_assignedBus!.id, newAvailability);
      setState(() {
        _assignedBus = _assignedBus!.copyWith(isAvailable: newAvailability);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newAvailability
                  ? 'Bus is now available for passengers'
                  : 'Bus marked as not available',
            ),
            backgroundColor: newAvailability ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _logout() {
    _stopTracking();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Map with location marker
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    )
                  : const LatLng(10.8505, 76.2711),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.keralab.bustracker',
              ),
              // Current location marker layer
              CurrentLocationLayer(
                style: LocationMarkerStyle(
                  marker: DefaultLocationMarker(
                    color: colorScheme.primary,
                    child: Icon(
                      Icons.directions_bus,
                      color: colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  markerSize: const Size(40, 40),
                  accuracyCircleColor: colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  headingSectorColor: colorScheme.primary.withValues(
                    alpha: 0.8,
                  ),
                  headingSectorRadius: 60,
                ),
              ),
              // Custom bus marker if position available
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
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
                    colorScheme.primaryContainer.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.directions_bus,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _assignedBus?.name ?? 'No Bus Assigned',
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_assignedBus != null)
                              Text(
                                _assignedBus!.registrationNumber,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        color: colorScheme.onPrimaryContainer,
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Control Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
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
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tracking Status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isTracking
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isTracking ? Icons.gps_fixed : Icons.gps_off,
                            color: _isTracking
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isTracking ? 'GPS Active' : 'GPS Inactive',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _isTracking
                                    ? 'Uploading raw GPS'
                                    : 'Start tracking to share location',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isTracking,
                          onChanged: (value) {
                            if (value) {
                              _startTracking();
                            } else {
                              _stopTracking();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Position Info
                    if (_currentPosition != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoItem(
                              Icons.location_on,
                              'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}',
                              context,
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: colorScheme.outlineVariant,
                            ),
                            _buildInfoItem(
                              Icons.location_on,
                              'Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                              context,
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: colorScheme.outlineVariant,
                            ),
                            _buildInfoItem(
                              Icons.speed,
                              '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
                              context,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Availability Toggle Button
                    if (_assignedBus != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _toggleAvailability,
                          icon: Icon(
                            _assignedBus!.isAvailable
                                ? Icons.check_circle
                                : Icons.cancel,
                          ),
                          label: Text(
                            _assignedBus!.isAvailable
                                ? 'Bus Available ✓'
                                : 'Mark as Available',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _assignedBus!.isAvailable
                                ? colorScheme.primary
                                : colorScheme.error,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusMarker() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onPrimary,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: Icon(
        Icons.directions_bus,
        color: Theme.of(context).colorScheme.onPrimary,
        size: 30,
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
