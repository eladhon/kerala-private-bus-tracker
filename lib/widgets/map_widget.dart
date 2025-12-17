import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Reusable OpenStreetMap widget
class MapWidget extends StatelessWidget {
  final LatLng? center;
  final double zoom;
  final List<Marker> markers;
  final MapController? controller;

  const MapWidget({
    super.key,
    this.center,
    this.zoom = 12,
    this.markers = const [],
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter:
            center ?? const LatLng(10.8505, 76.2711), // Kerala center
        initialZoom: zoom,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.keralab.bustracker',
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}

/// Custom bus marker builder
class BusMarker extends StatelessWidget {
  final bool isActive;
  final Color? color;

  const BusMarker({super.key, this.isActive = true, this.color});

  @override
  Widget build(BuildContext context) {
    final markerColor =
        color ?? (isActive ? const Color(0xFF1B5E20) : Colors.grey);

    return Container(
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: const Icon(Icons.directions_bus, color: Colors.white, size: 24),
    );
  }
}

/// User location marker
class UserLocationMarker extends StatelessWidget {
  const UserLocationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 20),
    );
  }
}
