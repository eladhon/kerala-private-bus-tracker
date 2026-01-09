/// Reusable bus tracking map widget with configurable layers
///
/// Consolidates map rendering logic from bus_tracking_screen.dart,
/// conductor_home_screen.dart, and route_search_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import '../../models/vehicle_state_model.dart';

/// Unified map widget for bus tracking across all screens
class BusTrackingMap extends StatelessWidget {
  /// Map controller for programmatic control
  final MapController? controller;

  /// Initial center point (defaults to Kerala center)
  final LatLng? initialCenter;

  /// Initial zoom level
  final double initialZoom;

  /// Full route polyline points (displayed in gray)
  final List<LatLng>? fullRoutePoints;

  /// User's selected segment of the route (displayed in blue)
  final List<LatLng>? userSegmentPoints;

  /// Walking path to source stop (dotted blue)
  final List<LatLng>? walkingToSourcePoints;

  /// Walking path from destination stop (dotted blue)
  final List<LatLng>? walkingFromDestPoints;

  /// Custom stop markers
  final List<Marker>? stopMarkers;

  /// Bus location from vehicle state
  final VehicleStateModel? busLocation;

  /// Custom bus marker widget
  final Widget? busMarkerWidget;

  /// Whether to show user's current location
  final bool showUserLocation;

  /// User location marker style
  final LocationMarkerStyle? userLocationStyle;

  /// Additional markers (source/destination pins, etc.)
  final List<Marker>? additionalMarkers;

  /// Callback when map position changes
  final void Function(MapCamera, bool hasGesture)? onPositionChanged;

  /// Polyline color for full route
  final Color fullRouteColor;

  /// Polyline color for user segment
  final Color userSegmentColor;

  const BusTrackingMap({
    super.key,
    this.controller,
    this.initialCenter,
    this.initialZoom = 12,
    this.fullRoutePoints,
    this.userSegmentPoints,
    this.walkingToSourcePoints,
    this.walkingFromDestPoints,
    this.stopMarkers,
    this.busLocation,
    this.busMarkerWidget,
    this.showUserLocation = true,
    this.userLocationStyle,
    this.additionalMarkers,
    this.onPositionChanged,
    this.fullRouteColor = const Color(0x80757575), // Grey with 50% alpha
    this.userSegmentColor = const Color(0xE6448AFF), // Blue with 90% alpha
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter:
            initialCenter ??
            busLocation?.latLng ??
            const LatLng(10.8505, 76.2711), // Kerala center
        initialZoom: initialZoom,
        onPositionChanged: onPositionChanged,
      ),
      children: [
        // Base tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.keralab.bustracker',
        ),

        // Full route polyline (gray, background)
        if (fullRoutePoints != null && fullRoutePoints!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: fullRoutePoints!,
                strokeWidth: 4.0,
                color: fullRouteColor,
              ),
            ],
          ),

        // Walking paths (dotted)
        if ((walkingToSourcePoints != null &&
                walkingToSourcePoints!.isNotEmpty) ||
            (walkingFromDestPoints != null &&
                walkingFromDestPoints!.isNotEmpty))
          PolylineLayer(
            polylines: [
              if (walkingToSourcePoints != null &&
                  walkingToSourcePoints!.isNotEmpty)
                Polyline(
                  points: walkingToSourcePoints!,
                  strokeWidth: 3.0,
                  color: Colors.blue.withValues(alpha: 0.6),
                  pattern: const StrokePattern.dotted(),
                ),
              if (walkingFromDestPoints != null &&
                  walkingFromDestPoints!.isNotEmpty)
                Polyline(
                  points: walkingFromDestPoints!,
                  strokeWidth: 3.0,
                  color: Colors.blue.withValues(alpha: 0.6),
                  pattern: const StrokePattern.dotted(),
                ),
            ],
          ),

        // User segment polyline (blue, foreground)
        if (userSegmentPoints != null && userSegmentPoints!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: userSegmentPoints!,
                strokeWidth: 5.0,
                color: userSegmentColor,
              ),
            ],
          ),

        // Stop markers
        if (stopMarkers != null && stopMarkers!.isNotEmpty)
          MarkerLayer(
            markers: [
              ...stopMarkers!,
              if (additionalMarkers != null) ...additionalMarkers!,
            ],
          ),

        // User location layer
        if (showUserLocation)
          CurrentLocationLayer(
            style:
                userLocationStyle ??
                LocationMarkerStyle(
                  marker: const DefaultLocationMarker(
                    color: Colors.blue,
                    child: Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                  markerSize: const Size(30, 30),
                  accuracyCircleColor: Colors.blue.withValues(alpha: 0.1),
                  headingSectorColor: Colors.blue.withValues(alpha: 0.8),
                ),
          ),

        // Bus marker
        if (busLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: busLocation!.latLng,
                width: 50,
                height: 50,
                child: busMarkerWidget ?? const DefaultBusMarker(),
              ),
            ],
          ),
      ],
    );
  }
}

/// Default bus marker widget
class DefaultBusMarker extends StatelessWidget {
  final bool isActive;
  final Color? color;
  final double heading;

  const DefaultBusMarker({
    super.key,
    this.isActive = true,
    this.color,
    this.heading = 0,
  });

  @override
  Widget build(BuildContext context) {
    final markerColor =
        color ?? (isActive ? const Color(0xFF1B5E20) : Colors.grey);

    return Transform.rotate(
      angle: heading * 3.14159 / 180,
      child: Container(
        decoration: BoxDecoration(
          color: markerColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Icon(Icons.directions_bus, color: Colors.white, size: 24),
      ),
    );
  }
}

/// Stop marker widget
class StopMarker extends StatelessWidget {
  final Color borderColor;
  final double size;

  const StopMarker({super.key, this.borderColor = Colors.blue, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }
}

/// Helper to create stop markers from stops list
List<Marker> createStopMarkers(
  List<LatLng> stopPositions, {
  Color borderColor = Colors.blue,
  double size = 12,
}) {
  return stopPositions
      .map(
        (pos) => Marker(
          point: pos,
          width: size,
          height: size,
          child: StopMarker(borderColor: borderColor, size: size),
        ),
      )
      .toList();
}
