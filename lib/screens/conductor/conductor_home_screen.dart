import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/user_model.dart';
import '../../models/route_model.dart';
import '../../models/stop_model.dart';
import '../../models/conductor_review_model.dart';
// import '../../services/theme_manager.dart'; // Unused
import '../../shared/services/location_service.dart';
// import '../auth/login_screen.dart'; // Unused
import 'widgets/bus_assignment_animation.dart';
import 'screens/conductor_report_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/delay_report_dialog.dart';
import '../../widgets/sos_button.dart';
import '../settings_screen.dart';

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
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  String? _selectedReportType; // 'repair', 'fuel', or null for list
  bool _isLoading = true;
  bool _hasLocationPermission = false;

  // Server upload tracking
  // Raw GPS is now sent to server; smoothing happens via Postgres trigger
  DateTime _lastUploadTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Server upload interval (raw GPS sent every 15s, smoothed by Postgres)
  static const int _serverUploadIntervalSeconds = 15;

  int _currentIndex = 0;
  bool _isPanelExpanded = true;
  UserModel? _currentUser;
  RouteModel? _assignedRoute;
  List<LatLng> _routePath = [];
  List<ConductorReviewModel> _reviews = [];

  // Setup Realtime listener
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _setupRealtimeListener(String userId) {
    debugPrint("Setting up Realtime listener for User ID: $userId");
    Supabase.instance.client
        .channel('public:users:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) async {
            debugPrint(
              "Realtime Update Received! Payload: ${payload.newRecord}",
            );
            final newRecord = payload.newRecord;
            final newBusId = newRecord['bus_id'] as String?;

            debugPrint(
              "Current BusID: ${_currentUser?.busId}, New BusID: $newBusId",
            );

            // If bus_id changed and is not null
            if (newBusId != null && (_currentUser?.busId != newBusId)) {
              debugPrint("BUS ASSIGNMENT CHANGED! New ID: $newBusId");
              await _handleNewAssignment(newBusId);
            } else {
              debugPrint("No change in bus assignment detected.");
            }
          },
        )
        .subscribe((status, error) {
          debugPrint("Realtime Subscription Status: $status, Error: $error");
        });
  }

  Future<void> _handleNewAssignment(String newBusId) async {
    // 1. Fetch new bus details
    final bus = await _queries.getBusById(newBusId);
    if (bus == null) return;

    // 2. Fetch new route details
    final route = await _queries.getRouteById(bus.routeId);

    // 3. Update State
    if (mounted) {
      setState(() {
        _assignedBus = bus;
        _assignedRoute = route;
        _currentUser = _currentUser?.copyWith(busId: newBusId);
        if (route != null) _fetchRoutePath(route.busStops);
      });

      // 4. Show Animation
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, a1, a2) => BusAssignmentAnimation(
          bus: bus,
          onAcknowledge: () {
            Navigator.of(context).pop();
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _stopTracking();
    // Unsubscribe from specific user channel if user is known
    if (_currentUser != null) {
      Supabase.instance.client
          .channel('public:users:${_currentUser!.id}')
          .unsubscribe();
    }
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      // Check location permissions
      _hasLocationPermission = await _checkLocationPermission();

      // Get assigned bus for this conductor using Phone Number (Demo Mode)
      final user = await _queries.getUserByPhone(widget.phoneNumber);

      if (user != null) {
        debugPrint('Found User: ${user.name}, BusID: ${user.busId}');
        setState(() => _currentUser = user);

        // Setup realtime listener now that we have the ID
        _setupRealtimeListener(user.id);

        // Fetch reviews for this conductor
        final reviews = await _queries.getConductorReviews(user.id);
        setState(() => _reviews = reviews);

        if (user.busId != null) {
          final bus = await _queries.getBusById(user.busId!);
          if (bus != null) {
            final route = await _queries.getRouteById(bus.routeId);
            setState(() {
              _assignedBus = bus;
              _assignedRoute = route;
            });
            // Fetch snap-to-road polyline
            if (route != null) {
              _fetchRoutePath(route.busStops);
            }
          } else {
            debugPrint('Bus with ID ${user.busId} returned null');
          }
        } else {
          debugPrint('User has no busId assigned');
        }
      } else {
        debugPrint('User lookup failed for Phone ${widget.phoneNumber}');
      }
    } catch (e) {
      debugPrint('Error initializing: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkLocationPermission() async {
    final status = await LocationService().requestPermission();
    return status == LocationPermissionStatus.granted;
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

    // Start stream-based tracking
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10, // Update every 10 meters if moved
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          _onLocationUpdate,
          onError: (e) {
            debugPrint('Error in location stream: $e');
          },
        );
  }

  void _onLocationUpdate(Position position) async {
    try {
      // Store raw position for local UI display
      setState(() => _currentPosition = position);

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
      debugPrint('Error processing location update: $e');
    }
  }

  void _stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    if (mounted) {
      setState(() => _isTracking = false);
    }
  }

  Future<void> _toggleAvailability() async {
    if (_assignedBus == null) return;

    final newAvailability = !_assignedBus!.isAvailable;
    String? reason;

    if (!newAvailability) {
      // Ask for reason
      final reasonController = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Mark Unavailable"),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: "Reason for unavailability",
              hintText: "e.g., Break, Repair, Trip Ended",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), // Cancel
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, reasonController.text),
              child: const Text("Confirm"),
            ),
          ],
        ),
      );

      // If user cancelled dialog (reason is null), do nothing
      if (reason == null) return;
    }

    try {
      await _queries.setBusAvailability(
        _assignedBus!.id,
        newAvailability,
        reason: reason,
      );
      setState(() {
        // Also update local model
        _assignedBus = _assignedBus!.copyWith(
          isAvailable: newAvailability,
          unavailabilityReason: reason,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newAvailability
                  ? 'Bus is now available for passengers'
                  : 'Bus marked as not available: ${reason ?? ""}',
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

  Future<void> _fetchRoutePath(List<StopModel> stops) async {
    if (stops.length < 2) return;

    try {
      // OSRM requires coordinates in "lng,lat" format
      final coordinates = stops.map((s) => '${s.lng},${s.lat}').join(';');

      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=polyline',
      );

      debugPrint('Fetching route from OSRM: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final geometry = data['routes'][0]['geometry'] as String;
          final points = decodePolyline(geometry);

          setState(() {
            _routePath = points
                .map((p) => LatLng(p[0].toDouble(), p[1].toDouble()))
                .toList();
          });
        }
      } else {
        debugPrint('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching route path: $e');
    }
  }

  // Logout moved to SettingsScreen

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar:
          (_currentIndex == 1 && _selectedReportType != null) ||
              _currentIndex == 0
          ? null
          : AppBar(
              title: Text(_currentIndex == 1 ? 'Chats' : 'Profile'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              actions: _currentIndex == 2
                  ? [
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettingsScreen(
                                currentUser: _currentUser,
                                // Conductor might not have user preferences loaded same way,
                                // but we can pass null or fetch if needed.
                                // For now, passing null is fine as per current code.
                                onProfileUpdate: _initializeData,
                              ),
                            ),
                          );
                        },
                      ),
                    ]
                  : null,
            ),
      floatingActionButton: _currentIndex == 0 && _currentUser != null
          ? Padding(
              padding: const EdgeInsets.only(
                bottom: 160,
              ), // Above the bottom panel
              child: SosButton(
                userId: _currentUser!.id,
                userRole: 'conductor',
                busId: _assignedBus?.id,
                routeId: _assignedRoute?.id,
              ),
            )
          : null,
      body: _currentIndex == 0
          ? _buildHomeTab()
          : _currentIndex == 1
          ? _buildChatsTab()
          : _buildProfileTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Use fetched path if available, else fallback to straight lines between stops
    final displayPoints = _routePath.isNotEmpty
        ? _routePath
        : (_assignedRoute?.busStops.map((s) => LatLng(s.lat, s.lng)).toList() ??
              []);

    return Stack(
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

            // Route Polyline
            if (displayPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: displayPoints,
                    strokeWidth: 4.0,
                    color: Colors.blue.withValues(alpha: 0.7),
                  ),
                ],
              ),

            // Bus Stops
            if (_assignedRoute != null)
              MarkerLayer(
                markers: _assignedRoute!.busStops.map((stop) {
                  return Marker(
                    point: LatLng(stop.lat, stop.lng),
                    width: 16,
                    height: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                    ),
                  );
                }).toList(),
              ),

            // Current location marker layer with smooth animation
            CurrentLocationLayer(
              alignPositionOnUpdate: AlignOnUpdate.always,
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
                accuracyCircleColor: colorScheme.primary.withValues(alpha: 0.1),
                headingSectorColor: colorScheme.primary.withValues(alpha: 0.8),
                headingSectorRadius: 60,
              ),
            ),
          ],
        ),

        // Bottom Control Panel (No Top Overlay)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < 0) {
                // Swipe Up -> Expand
                setState(() => _isPanelExpanded = true);
              } else if (details.primaryVelocity! > 0) {
                // Swipe Down -> Collapse
                setState(() => _isPanelExpanded = false);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle & Header Row (Always Visible)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header Row with Toggle
                      InkWell(
                        onTap: () => setState(
                          () => _isPanelExpanded = !_isPanelExpanded,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.directions_bus,
                                size: 32,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _assignedBus?.name ?? 'No Bus Assigned',
                                    style: textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  if (_assignedBus != null)
                                    Text(
                                      "Reg: ${_assignedBus!.registrationNumber}",
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else
                                    Text(
                                      "Please contact admin",
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Minimized State: Show Compact GPS Icon
                            if (!_isPanelExpanded) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isTracking
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.1,
                                        )
                                      : colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isTracking ? Icons.gps_fixed : Icons.gps_off,
                                  color: _isTracking
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ] else ...[
                              // Expanded State: Show Collapse Chevron
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Collapsible Content
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isPanelExpanded
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),

                              // Tracking Toggle
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _isTracking
                                      ? colorScheme.primaryContainer.withValues(
                                          alpha: 0.2,
                                        )
                                      : colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _isTracking
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: SwitchListTile(
                                  value: _isTracking,
                                  onChanged: (value) {
                                    if (value) {
                                      _startTracking();
                                    } else {
                                      _stopTracking();
                                    }
                                  },
                                  title: Text(
                                    _isTracking
                                        ? 'Tracking Active'
                                        : 'Start Tracking',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _isTracking
                                        ? "Broadcasting live location"
                                        : "Turn on to share location",
                                    style: textTheme.bodySmall,
                                  ),
                                  secondary: Icon(
                                    _isTracking
                                        ? Icons.gps_fixed
                                        : Icons.gps_off,
                                    color: _isTracking
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildInfoItem(
                                        Icons.speed,
                                        '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
                                        context,
                                      ),
                                      Container(
                                        width: 1,
                                        height: 20,
                                        color: colorScheme.outlineVariant,
                                      ),
                                      _buildInfoItem(
                                        Icons.alt_route,
                                        'Lat: ${_currentPosition!.latitude.toStringAsFixed(3)}',
                                        context,
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 24),

                              // Quick Actions
                              Text(
                                "Quick Actions",
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _currentIndex =
                                              1; // Switch to Chats tab
                                          _selectedReportType = 'repair';
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.build_circle_outlined,
                                      ),
                                      label: const Text("Report Repair"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _currentIndex =
                                              1; // Switch to Chats tab
                                          _selectedReportType = 'fuel';
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.local_gas_station_outlined,
                                      ),
                                      label: const Text("Fuel Log"),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Delay Report Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (_assignedBus != null &&
                                        _currentUser != null) {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => DelayReportDialog(
                                          busId: _assignedBus!.id,
                                          conductorId: _currentUser!.id,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.timer,
                                    color: Colors.orange,
                                  ),
                                  label: const Text('Report Delay'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Availability Details
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    final colorScheme = Theme.of(context).colorScheme;

    // Mock Ratings Data - REPLACED with _reviews
    /*
    final mockRatings = [
      {'name': 'Arun Kumar', 'rating': 5, 'comment': 'Very puntual!'},
      {'name': 'Deepa Thomas', 'rating': 4, 'comment': 'Good driving.'},
      {'name': 'Rahul R', 'rating': 5, 'comment': 'Clean bus.'},
      {'name': 'Sneha P', 'rating': 3, 'comment': 'A bit fast.'},
    ];
    */

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header (WhatsApp Style)
          Container(
            width: double.infinity,
            color: colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    _currentUser?.name.isNotEmpty == true
                        ? _currentUser!.name[0].toUpperCase()
                        : 'C',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUser?.name ?? 'Conductor',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentUser?.phone ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Assigned Bus Detail Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_bus, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          "Assigned Bus",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_assignedBus != null)
                      Column(
                        children: [
                          _buildDetailRow("Bus Name", _assignedBus!.name),
                          _buildDetailRow(
                            "Reg Number",
                            _assignedBus!.registrationNumber,
                          ),
                        ],
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text("No bus assigned currently."),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // User Ratings Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Rider Reviews',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Horizontal Ratings List
          if (_reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("No reviews yet."),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      color: colorScheme.surfaceContainerLow,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor:
                                      colorScheme.secondaryContainer,
                                  child: Text(
                                    (review.userName ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    review.userName ?? 'User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < review.rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                review.reviewText ?? '',
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 32),

          // Logout Button (Removed, moved to AppBar Settings)
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
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

  Widget _buildChatsTab() {
    // If a type is selected, show the chat screen
    if (_selectedReportType != null) {
      if (_currentUser == null) {
        return const Center(child: Text("User not loaded"));
      }
      return ConductorReportScreen(
        user: _currentUser!,
        reportType: _selectedReportType!,
        onBack: () {
          setState(() {
            _selectedReportType = null;
          });
        },
      );
    }

    // Otherwise show the list
    return ListView(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade100,
            child: Icon(Icons.build, color: Colors.red.shade700),
          ),
          title: const Text('Repair Reports'),
          subtitle: const Text('Report maintenance issues'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setState(() {
              _selectedReportType = 'repair';
            });
          },
        ),
        const Divider(),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Icon(Icons.local_gas_station, color: Colors.blue.shade700),
          ),
          title: const Text('Fuel Logs'),
          subtitle: const Text('Log daily fuel usage'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setState(() {
              _selectedReportType = 'fuel';
            });
          },
        ),
      ],
    );
  }
}
