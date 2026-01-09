import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/stop_model.dart';
import '../../models/vehicle_state_model.dart';
import '../../models/user_model.dart';
import '../../models/conductor_review_model.dart';
import '../../services/routing_service.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_service.dart';
import '../../services/eta_service.dart';
import '../../services/proximity_alert_service.dart';
import '../../shared/services/location_service.dart';

import '../../services/price_calculator_service.dart';

/// Live bus tracking screen with real-time map updates
class BusTrackingScreen extends StatefulWidget {
  final BusModel bus;
  final String? currentUserId; // Manual user ID passing for demo
  final String? userSourceStop;
  final String? userDestStop;
  final LatLng? userSourceLatLng;
  final LatLng? userDestLatLng;

  const BusTrackingScreen({
    super.key,
    required this.bus,
    this.currentUserId,
    this.userSourceStop,
    this.userDestStop,
    this.userSourceLatLng,
    this.userDestLatLng,
    this.selectedRouteId,
  });

  final String? selectedRouteId; // Override bus.routeId (for schedule trips)

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen>
    with SingleTickerProviderStateMixin {
  final _queries = SupabaseQueries();
  final MapController _mapController = MapController();
  // Removed DraggableScrollableController

  // Real-time tracking variables
  VehicleStateModel? _lastPacket;
  DateTime? _lastPacketTime;
  VehicleStateModel? _interpolatedLocation; // The location we show on UI

  // Conductor & Reviews
  UserModel? _conductor;
  List<ConductorReviewModel> _reviews = [];
  bool _isLoadingReviews = true;
  bool _isFavorite = false;
  bool _isReminderSet = false;
  bool _isPanelExpanded = false;
  bool _hasNotified = false;

  // Ticker for smooth animation (dead reckoning)
  late final Ticker _ticker;

  Position? _userPosition;
  StreamSubscription? _locationSubscription;
  Timer? _refreshTimer;
  bool _followBus = true;
  final bool _showUserLocation = true;

  // Refresh every 10 seconds
  static const int _refreshIntervalSeconds = 10;

  // Route Polyline & Markers
  List<LatLng> _routePoints = []; // Grayscale full route
  List<LatLng> _userRoutePoints = []; // Blue user segment
  List<LatLng> _walkingToSourcePoints = []; // Dotted walking path to start
  List<LatLng> _walkingFromDestPoints = []; // Dotted walking path from end
  List<Marker> _stopMarkers = [];
  List<StopModel> _routeStops = []; // Store stops for next stop calculation
  String? _nextStopName;
  final _routingService = RoutingService();

  // ETA & Proximity Services
  final _etaService = EtaService();
  final _proximityService = ProximityAlertService();
  EtaResult? _etaResult;
  StopModel? _userDestStopModel;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
    _initializeTracking();
    _fetchRoutePolyline();
    _fetchConductorDetails();
    _fetchFavoriteStatus();
    _isReminderSet = ReminderService().isReminderSet(widget.bus.id);
  }

  Future<void> _fetchFavoriteStatus() async {
    if (widget.currentUserId == null) return;
    try {
      final isFav = await _queries.isBusFavorite(
        widget.bus.id,
        widget.currentUserId!,
      );
      if (mounted) setState(() => _isFavorite = isFav);
    } catch (e) {
      debugPrint("Error fetching fav status: $e");
    }
  }

  Future<void> _fetchConductorDetails() async {
    try {
      if (widget.bus.conductorId != null) {
        debugPrint("Fetching details for conductor: ${widget.bus.conductorId}");
        final conductor = await _queries.getUserById(widget.bus.conductorId!);

        if (conductor != null) {
          debugPrint("Conductor found: ${conductor.name}");
          if (mounted) setState(() => _conductor = conductor);

          debugPrint("Fetching reviews...");
          final reviews = await _queries.getConductorReviews(conductor.id);
          debugPrint("Reviews fetched: ${reviews.length}");

          if (mounted) {
            setState(() {
              _reviews = reviews;
              _isLoadingReviews = false;
            });
          }
        } else {
          debugPrint("Conductor not found in DB");
          if (mounted) setState(() => _isLoadingReviews = false);
        }
      } else {
        debugPrint("Bus has no conductor assigned");
        if (mounted) setState(() => _isLoadingReviews = false);
      }
    } catch (e) {
      debugPrint("Error fetching conductor details: $e");
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _fetchRoutePolyline() async {
    try {
      // 1. Get the route details (Use selected match or default bus route)
      final routeIdToUse = widget.selectedRouteId ?? widget.bus.routeId;
      final route = await _queries.getRouteById(routeIdToUse);

      if (route == null) return;
      if (route.busStops.isNotEmpty) {
        // Create markers for stops
        final markers = route.busStops.map((stop) {
          return Marker(
            point: LatLng(stop.lat, stop.lng),
            width: 12,
            height: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue, width: 2),
              ),
            ),
          );
        }).toList();

        if (mounted) {
          setState(() {
            _stopMarkers = markers;
          });
        }

        if (mounted) {
          setState(() {
            _stopMarkers = markers;
          });
        }

        // Store stops
        _routeStops = route.busStops;

        // 1. Fetch Full Route Polyline (Gray)
        final fullPoints = await _routingService.getRoutePolyline(
          route.busStops,
        );

        // 2. Fetch User Segment Polyline (Blue) if applicable
        List<LatLng> userPoints = [];
        if (widget.userSourceStop != null && widget.userDestStop != null) {
          final stops = route.busStops;
          // Case-insensitive comparison with bidirectional contains check
          final sourceName = widget.userSourceStop?.trim().toLowerCase() ?? '';
          final destName = widget.userDestStop?.trim().toLowerCase() ?? '';

          int startIdx = stops.indexWhere((s) {
            final stopName = s.name.toLowerCase();
            return stopName == sourceName ||
                stopName.contains(sourceName) ||
                sourceName.contains(stopName);
          });

          int endIdx = stops.indexWhere((s) {
            final stopName = s.name.toLowerCase();
            return stopName == destName ||
                stopName.contains(destName) ||
                destName.contains(stopName);
          });

          debugPrint("Polyline Debug: Stops Count=${stops.length}");
          if (stops.isNotEmpty) {
            debugPrint(
              "Polyline Debug: Route First=${stops.first.name}, Last=${stops.last.name}",
            );
          }
          debugPrint(
            "Polyline Debug: User Input Source='$sourceName', Dest='$destName'",
          );
          debugPrint(
            "Polyline Debug: Matches -> StartIdx=$startIdx, EndIdx=$endIdx",
          );

          if (startIdx != -1 && endIdx != -1) {
            List<StopModel> userSegmentStops = [];

            if (startIdx <= endIdx) {
              // Forward direction
              userSegmentStops = stops.sublist(startIdx, endIdx + 1);
            } else {
              // Reverse direction (User going backwards relative to route definition)
              debugPrint(
                "Polyline Debug: Detected reverse direction (Start $startIdx > End $endIdx). Reversing segment.",
              );
              final segment = stops.sublist(endIdx, startIdx + 1);
              userSegmentStops = segment.reversed.toList();
            }

            if (userSegmentStops.isNotEmpty) {
              userPoints = await _routingService.getRoutePolyline(
                userSegmentStops,
              );

              // Fetch walking route to source stop
              if (widget.userSourceLatLng != null) {
                final walkStart = widget.userSourceLatLng!;
                final walkEnd = LatLng(
                  userSegmentStops.first.lat,
                  userSegmentStops.first.lng,
                );
                _walkingToSourcePoints = await _routingService
                    .getWalkingPolyline([walkStart, walkEnd]);
              }

              // Fetch walking route from destination stop
              if (widget.userDestLatLng != null) {
                final walkStart = LatLng(
                  userSegmentStops.last.lat,
                  userSegmentStops.last.lng,
                );
                final walkEnd = widget.userDestLatLng!;
                _walkingFromDestPoints = await _routingService
                    .getWalkingPolyline([walkStart, walkEnd]);
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _routePoints = fullPoints;

            if (userPoints.isNotEmpty) {
              _userRoutePoints = userPoints;
            } else if (widget.userSourceStop == null ||
                widget.userDestStop == null) {
              // No search active, show full route as blue (default view)
              _userRoutePoints = fullPoints;
              // Optionally clear _routePoints if we don't want gray underneath,
              // but keeping it is harmless as Blue covers it.
            } else {
              // Search was attempted but segment calculation failed (e.g. stops not found)
              // Show only Gray to differentiate.
              // Show only Gray to differentiate.
              _userRoutePoints = [];
            }

            // Recalculate next stop now that we have route stops
            _calculateNextStop();
          });

          // Animate camera to fit user segment and walking paths if available, else full route
          if (_userRoutePoints.isNotEmpty) {
            final allUserPoints = [
              ..._walkingToSourcePoints,
              ..._userRoutePoints,
              ..._walkingFromDestPoints,
              if (widget.userSourceLatLng != null) widget.userSourceLatLng!,
              if (widget.userDestLatLng != null) widget.userDestLatLng!,
            ];
            _fitRouteToBounds(allUserPoints);
          } else if (_routePoints.isNotEmpty) {
            _fitRouteToBounds(_routePoints);
          } else if (route.busStops.isNotEmpty) {
            final stopPoints = route.busStops
                .map((s) => LatLng(s.lat, s.lng))
                .toList();
            _fitRouteToBounds(stopPoints);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading route polyline: $e');
    }
  }

  void _fitRouteToBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(points);
    // Add some padding so it doesn't touch the edges
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  /// Dead reckoning tick loop (runs every frame)
  void _onTick(Duration elapsed) {
    if (_lastPacket == null || _lastPacketTime == null) {
      return;
    }

    // Only interpolate if moving and data is fresh (<30s old)
    // If data is too old, stop moving to avoid showing it driving off the map forever
    final timeSincePacket = DateTime.now().difference(_lastPacketTime!);
    if (timeSincePacket.inSeconds > 30 || _lastPacket!.speedKmh < 0.5) {
      return;
    }

    // Calculate distance moved: speedMps is already in m/s
    final speedMs = _lastPacket!.speedMps;
    final elapsedSincePacket = timeSincePacket.inMilliseconds / 1000.0;

    // Calculate new lat/lng based on heading and distance
    final newPos = _calculateNewPosition(
      _lastPacket!.lat,
      _lastPacket!.lng,
      speedMs,
      _lastPacket!.headingDeg,
      elapsedSincePacket,
    );

    setState(() {
      _interpolatedLocation = _lastPacket!.copyWith(
        lat: newPos.latitude,
        lng: newPos.longitude,
      );
      _calculateNextStop(); // Recalculate next stop
      _checkReminder();
    });

    if (_followBus) {
      _centerOnBus();
    }
  }

  void _checkReminder() {
    // Sync local state if needed
    _isReminderSet = ReminderService().isReminderSet(widget.bus.id);

    if (!_isReminderSet || _hasNotified || _interpolatedLocation == null) {
      return;
    }

    // Check distance to user location (simple straight line for now)
    // If routing was fully integrated, we'd use route ETA.
    // Heuristic: Bus moves ~30km/h = 500m/min. 10 mins = 5km.
    // Let's use 5km radius for "10 min warning" as a rough estimate if no route data.

    // If we have userSourceLatLng, use that. Else use current user location.
    final targetPos =
        widget.userSourceLatLng ??
        (_userPosition != null
            ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
            : null);

    if (targetPos == null) return;

    final dist = const Distance().as(
      LengthUnit.Meter,
      LatLng(_interpolatedLocation!.lat, _interpolatedLocation!.lng),
      targetPos,
    );

    // 5km approx 10 mins at 30km/h.
    // If getting closer, trigger it.
    if (dist <= 5000) {
      NotificationService().showNotification(
        id: widget.bus.id.hashCode,
        title: "Bus Nearby!",
        body: "${widget.bus.name} is about 10 minutes away.",
      );
      setState(() => _hasNotified = true);
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.currentUserId == null) return;
    try {
      final newStatus = await _queries.toggleFavorite(
        widget.bus.id,
        widget.currentUserId!,
      );
      setState(() => _isFavorite = newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus ? 'Added to favorites' : 'Removed from favorites',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error toggling favorite: $e");
    }
  }

  void _toggleReminder() {
    final reminderService = ReminderService();
    setState(() {
      if (reminderService.isReminderSet(widget.bus.id)) {
        reminderService.removeReminder(widget.bus.id);
        _isReminderSet = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder cancelled.'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        reminderService.addReminder(widget.bus);
        _isReminderSet = true;
        // Reset notification flag when enabling
        _hasNotified = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reminder set! You will be notified when bus is ~10 mins away.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  LatLng _calculateNewPosition(
    double lat,
    double lng,
    double speedMs,
    double heading,
    double elapsedSeconds,
  ) {
    const R = 6371000.0; // Earth radius in meters
    final distance = speedMs * elapsedSeconds;

    final lat1 = lat * math.pi / 180;
    final lng1 = lng * math.pi / 180;
    final brng = heading * math.pi / 180;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(distance / R) +
          math.cos(lat1) * math.sin(distance / R) * math.cos(brng),
    );
    final lng2 =
        lng1 +
        math.atan2(
          math.sin(brng) * math.sin(distance / R) * math.cos(lat1),
          math.cos(distance / R) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
  }

  void _calculateNextStop() {
    debugPrint(
      "_calculateNextStop: Stops=${_routeStops.length}, Loc=${_interpolatedLocation != null}",
    );

    if (_interpolatedLocation == null || _routeStops.isEmpty) return;

    // Find nearest stop and check if we passed it (simple proximity for now)
    double minDistance = double.infinity;
    StopModel? nearestStop;
    int nearestIndex = -1;

    for (int i = 0; i < _routeStops.length; i++) {
      final stop = _routeStops[i];
      final dist = const Distance().as(
        LengthUnit.Meter,
        LatLng(_interpolatedLocation!.lat, _interpolatedLocation!.lng),
        LatLng(stop.lat, stop.lng),
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearestStop = stop;
        nearestIndex = i;
      }
    }

    debugPrint(
      "_calculateNextStop: NearestIdx=$nearestIndex, Dist=$minDistance",
    );

    if (nearestIndex != -1) {
      if (nearestIndex < _routeStops.length - 1) {
        _nextStopName = nearestStop!.name;
      } else {
        _nextStopName = "End of Trip";
      }
      debugPrint("_calculateNextStop: Set Next Stop to $_nextStopName");
    }

    // Calculate ETA to user's destination stop
    _calculateEtaToDestination();
  }

  /// Calculate ETA to user's destination stop
  void _calculateEtaToDestination() {
    if (_interpolatedLocation == null || _routeStops.isEmpty) return;

    // Determine target stop (user's destination or first stop)
    StopModel? targetStop;

    // If user specified a destination stop, use it
    if (widget.userDestStop != null) {
      targetStop = _routeStops.cast<StopModel?>().firstWhere(
        (s) => s?.name.toLowerCase() == widget.userDestStop!.toLowerCase(),
        orElse: () => null,
      );
    }

    // If no user destination, use the source stop if specified
    if (targetStop == null && widget.userSourceStop != null) {
      targetStop = _routeStops.cast<StopModel?>().firstWhere(
        (s) => s?.name.toLowerCase() == widget.userSourceStop!.toLowerCase(),
        orElse: () => null,
      );
    }

    // Fallback to first stop
    targetStop ??= _routeStops.isNotEmpty ? _routeStops.first : null;

    if (targetStop == null) return;

    _userDestStopModel = targetStop;

    // Calculate ETA using the EtaService
    final result = _etaService.calculateEta(
      busState: _interpolatedLocation!,
      targetStop: targetStop,
      routeStops: _routeStops,
    );

    if (mounted) {
      setState(() {
        _etaResult = result;
      });
    }

    debugPrint("ETA calculated: ${result.formattedEta} to ${targetStop.name}");
  }

  /// Get color based on ETA status
  Color _getEtaColor(EtaStatus status) {
    switch (status) {
      case EtaStatus.arriving:
        return Colors.green;
      case EtaStatus.soon:
        return Colors.orange;
      case EtaStatus.onTheWay:
        return Colors.blue;
      case EtaStatus.farAway:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    _proximityService.stopMonitoring();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    // Get user's current location
    await _getUserLocation();

    // Get initial bus location
    await _fetchBusLocation();

    // Start real-time stream for bus location
    _locationSubscription = _queries
        .streamVehicleState(widget.bus.id)
        .listen(
          (location) {
            if (mounted && location != null) {
              _lastPacket = location;
              _lastPacketTime = DateTime.now();
              // Reset interpolation to actual location when new packet arrives
              setState(() {
                _interpolatedLocation = location;
                _calculateNextStop(); // Recalculate next stop
              });

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

    // Start proximity alerts if user has a destination stop
    _startProximityAlerts();
  }

  /// Start proximity alerts for bus approach notifications
  void _startProximityAlerts() {
    // Only start if we have a destination stop and route
    if (_userDestStopModel != null && _routeStops.isNotEmpty) {
      _proximityService.startMonitoring(
        busId: widget.bus.id,
        busName: widget.bus.name,
        userStop: _userDestStopModel!,
        routeStops: _routeStops,
        busStateStream: _queries.streamVehicleState(widget.bus.id),
      );
      debugPrint('ProximityAlerts: Started for ${_userDestStopModel!.name}');
    }
  }

  Future<void> _getUserLocation() async {
    try {
      final position = await LocationService().getCurrentPosition();
      if (position != null) {
        setState(() => _userPosition = position);
      }
    } catch (e) {
      debugPrint('Error getting user location: $e');
    }
  }

  Future<void> _fetchBusLocation() async {
    try {
      final location = await _queries.getVehicleState(widget.bus.id);
      if (mounted && location != null) {
        setState(() {
          _lastPacket = location;
          _lastPacketTime = DateTime.now();
          // Initially set interpolated location to actual
          _interpolatedLocation ??= location;
          _calculateNextStop(); // Recalculate next stop
        });
        if (_followBus) {
          _centerOnBus();
        }
      } else {}
    } catch (e) {
      debugPrint('Error fetching bus location: $e');
    }
  }

  void _centerOnBus() {
    if (_interpolatedLocation != null) {
      _mapController.move(_interpolatedLocation!.latLng, 15);
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
    // Debug Auth Status
    final user = widget.currentUserId;
    debugPrint(
      "BusTrackingScreen Build: User is ${user != null ? 'Logged In ($user)' : 'Guest/Null'}",
    );

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _interpolatedLocation?.latLng ??
                  const LatLng(10.8505, 76.2711),
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
              // Route Polyline Layer (Background - Gray)
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.grey.withValues(alpha: 0.5), // Lighter gray
                    ),
                  ],
                ),
              // Walking Path (Dotted)
              if (_walkingToSourcePoints.isNotEmpty ||
                  _walkingFromDestPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    if (_walkingToSourcePoints.isNotEmpty)
                      Polyline(
                        points: _walkingToSourcePoints,
                        strokeWidth: 3.0,
                        color: Colors.blue.withValues(alpha: 0.6),
                        pattern: const StrokePattern.dotted(),
                      ),
                    if (_walkingFromDestPoints.isNotEmpty)
                      Polyline(
                        points: _walkingFromDestPoints,
                        strokeWidth: 3.0,
                        color: Colors.blue.withValues(alpha: 0.6),
                        pattern: const StrokePattern.dotted(),
                      ),
                  ],
                ),
              // User Segment Polyline Layer (Foreground - Blue)
              if (_userRoutePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _userRoutePoints,
                      strokeWidth: 5.0, // Slightly thicker
                      color: Colors.blue.withValues(alpha: .9),
                    ),
                  ],
                ),
              // Stop Markers Layer
              if (_stopMarkers.isNotEmpty)
                MarkerLayer(
                  markers: [
                    ..._stopMarkers,
                    if (widget.userSourceLatLng != null)
                      Marker(
                        point: widget.userSourceLatLng!,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 30,
                        ),
                      ),
                    if (widget.userDestLatLng != null)
                      Marker(
                        point: widget.userDestLatLng!,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                  ],
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
                    headingSectorColor: Colors.blue.withValues(alpha: .8),
                  ),
                ),
              // Bus location marker
              if (_interpolatedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _interpolatedLocation!.latLng,
                      width: 50,
                      height: 50,
                      child: _buildBusMarker(),
                    ),
                  ],
                ),
            ],
          ),

          // Top Floating Bar (Back + Actions)
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Actions (Fav + Reminder)
                Row(
                  children: [
                    // Reminder Bell
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: Icon(
                          _isReminderSet
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          color: _isReminderSet ? Colors.orange : Colors.black,
                        ),
                        onPressed: _toggleReminder,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Favorite Heart
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.red : Colors.black,
                        ),
                        onPressed: _toggleFavorite,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Control Panel (Static Animated Container)
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
                height: _isPanelExpanded
                    ? MediaQuery.of(context).size.height * 0.7
                    : null,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  minHeight: 120, // Min height
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize
                      .min, // Essential for wrapping content when minimized
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle & Header Row (Always Visible)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 32,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Header Content: Bus Info + Toggle + Next Stop
                        InkWell(
                          onTap: () => setState(
                            () => _isPanelExpanded = !_isPanelExpanded,
                          ),
                          child: Row(
                            children: [
                              // Bus Icon + Name
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.directions_bus,
                                  size: 28,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Name & Reg
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.bus.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      widget.bus.registrationNumber,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Right: Next Stop (If Minimized) AND Arrow
                              Row(
                                children: [
                                  if (!_isPanelExpanded &&
                                      (_nextStopName != null ||
                                          _etaResult != null)) ...[
                                    // ETA Badge (prominent)
                                    if (_etaResult != null &&
                                        _etaResult!.isValid)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getEtaColor(
                                            _etaResult!.status,
                                          ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _getEtaColor(
                                              _etaResult!.status,
                                            ).withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _etaResult!.formattedEta,
                                              style: TextStyle(
                                                color: _getEtaColor(
                                                  _etaResult!.status,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            if (_etaResult!.stopsRemaining > 0)
                                              Text(
                                                '${_etaResult!.stopsRemaining} stops',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 10,
                                                ),
                                              ),
                                          ],
                                        ),
                                      )
                                    else if (_nextStopName != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _nextStopName!,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                  ],
                                  Icon(
                                    _isPanelExpanded
                                        ? Icons.keyboard_arrow_down
                                        : Icons.keyboard_arrow_up,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Expanded Content (Scrollable)
                    if (_isPanelExpanded)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Conductor Info
                              if (_conductor != null) ...[
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.tertiaryContainer,
                                      child: Text(
                                        _conductor!.name[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onTertiaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Conductor: ${_conductor!.name}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Text(
                                          "Verified Staff",
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Next Stop Detailed Card
                              if (_nextStopName != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "NEXT STOP",
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 20,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _nextStopName!,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_interpolatedLocation != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "Speed: ${_interpolatedLocation!.speedKmh.toStringAsFixed(1)} km/h",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Ticket Price Section
                              if (widget.userSourceStop != null &&
                                  widget.userDestStop != null) ...[
                                _buildPriceSection(),
                                const SizedBox(height: 24),
                              ],

                              const Divider(),
                              const SizedBox(height: 16),

                              // Reviews Section header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Passenger Reviews",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  TextButton.icon(
                                    onPressed: _showAddReviewDialog,
                                    icon: const Icon(
                                      Icons.add_comment,
                                      size: 18,
                                    ),
                                    label: const Text("Rate"),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Reviews List
                              if (_isLoadingReviews)
                                const Center(child: CircularProgressIndicator())
                              else if (_reviews.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      "No reviews yet. Be the first!",
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ..._reviews.map(
                                  (review) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: _buildReviewCard(review),
                                  ),
                                ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
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
                if (!_followBus && _interpolatedLocation != null)
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
          BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 8),
        ],
      ),
      child: const Icon(Icons.directions_bus, color: Colors.white, size: 30),
    );
  }

  Widget _buildReviewCard(ConductorReviewModel review) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.userName ?? 'User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Icon(Icons.star, size: 14, color: Colors.amber[700]),
              Text(
                review.rating.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.reviewText ?? '',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddReviewDialog() async {
    if (_conductor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No conductor details available to rate."),
        ),
      );
      return;
    }

    // Check for existing review
    ConductorReviewModel? existingReview;
    try {
      existingReview = await _queries.getConductorReview(
        _conductor!.id,
        userId: widget.currentUserId,
      );
    } catch (e) {
      debugPrint("Error fetching existing review: $e");
    }

    // Pre-fill if editing
    int rating = existingReview?.rating ?? 5;
    final commentController = TextEditingController(
      text: existingReview?.reviewText ?? '',
    );
    final isEditing = existingReview != null;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing
                            ? "Edit Rating for ${_conductor!.name}"
                            : "Rate ${_conductor!.name}",
                        style: Theme.of(sheetContext).textTheme.headlineSmall,
                      ),
                      if (isEditing)
                        const Chip(
                          label: Text("Editing"),
                          backgroundColor: Colors.amberAccent,
                          labelStyle: TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Star Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () =>
                            setSheetState(() => rating = index + 1),
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          size: 32,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Polite Message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.tips_and_updates,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Please be polite and avoid using offensive language. Your feedback helps us improve.",
                            style: Theme.of(sheetContext).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.amber.shade900,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      labelText: "Comment (Optional)",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        try {
                          await _queries.upsertConductorReview(
                            conductorId: _conductor!.id,
                            rating: rating.toInt(),
                            reviewText: commentController.text,
                            existingReviewId: existingReview?.id,
                            userId: widget.currentUserId,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? "Rating updated successfully!"
                                      : "Rating submitted successfully!",
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Failed to submit rating: $e"),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        isEditing ? "Update Rating" : "Submit Rating",
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriceSection() {
    return FutureBuilder<double?>(
      future: _calculateTicketPrice(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final price = snapshot.data!;
        final isStudent = _isStudentUser;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isStudent ? Colors.blue.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isStudent ? Colors.blue.shade200 : Colors.green.shade200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Estimated Fare',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Info icon with tooltip explaining how price is calculated
                      Tooltip(
                        message: isStudent
                            ? "Student Concession: ₹1/km approx. (Max ₹50)"
                            : "Standard Rate: ₹10 Base + ₹1.5/km",
                        triggerMode: TooltipTriggerMode.tap,
                        child: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isStudent
                              ? Colors.blue.shade800
                              : Colors.green.shade800,
                        ),
                      ),
                      if (isStudent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'STUDENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.userSourceStop} → ${widget.userDestStop}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (_calculatedDistance != null)
                    Text(
                      '${_calculatedDistance!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isStudentUser = false;
  double? _calculatedDistance;
  final _priceService = PriceCalculatorService();

  Future<double?> _calculateTicketPrice() async {
    // If we don't need calculation or missing stops
    if (_routeStops.isEmpty ||
        widget.userSourceStop == null ||
        widget.userDestStop == null) {
      return null;
    }

    // 1. Find stops objects from the route's stop list
    // Note: Stop names must match exactly.
    final startStop = _routeStops.cast<StopModel?>().firstWhere(
      (s) => s?.name.toLowerCase() == widget.userSourceStop!.toLowerCase(),
      orElse: () => null,
    );
    final endStop = _routeStops.cast<StopModel?>().firstWhere(
      (s) => s?.name.toLowerCase() == widget.userDestStop!.toLowerCase(),
      orElse: () => null,
    );

    if (startStop == null || endStop == null) {
      debugPrint("Could not find start/end stops in route for pricing.");
      return null;
    }

    // 2. Calculate Distance
    final distance = _priceService.calculateDistance(
      startStop.lat,
      startStop.lng,
      endStop.lat,
      endStop.lng,
    );
    _calculatedDistance = distance;

    // 3. Check Student Status
    bool isStudent = false;
    if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty) {
      try {
        final app = await _queries.getUserApplication(widget.currentUserId!);
        if (app != null && app.status == 'approved') {
          isStudent = true;
        }
      } catch (e) {
        debugPrint("Error checking student status: $e");
      }
    }
    _isStudentUser = isStudent;

    // 4. Estimate Price
    return _priceService.estimatePrice(distance, isStudent: isStudent);
  }
}
