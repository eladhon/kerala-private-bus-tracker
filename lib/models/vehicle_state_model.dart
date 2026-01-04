import 'package:latlong2/latlong.dart';

/// Vehicle state model for smoothed GPS position (from Postgres trigger)
/// This is the single source of truth for vehicle position.
class VehicleStateModel {
  final String busId;
  final double lat;
  final double lng;
  final double speedMps; // in m/s
  final double headingDeg; // in degrees [0, 360)
  final DateTime updatedAt;
  final int? observationId;

  VehicleStateModel({
    required this.busId,
    required this.lat,
    required this.lng,
    required this.speedMps,
    required this.headingDeg,
    required this.updatedAt,
    this.observationId,
  });

  /// Create VehicleStateModel from JSON (Supabase response)
  factory VehicleStateModel.fromJson(Map<String, dynamic> json) {
    return VehicleStateModel(
      busId: json['bus_id'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      speedMps: (json['speed_mps'] as num?)?.toDouble() ?? 0,
      headingDeg: (json['heading_deg'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      observationId: json['observation_id'] as int?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'bus_id': busId,
      'lat': lat,
      'lng': lng,
      'speed_mps': speedMps,
      'heading_deg': headingDeg,
      'updated_at': updatedAt.toIso8601String(),
      'observation_id': observationId,
    };
  }

  /// Get LatLng for map display
  LatLng get latLng => LatLng(lat, lng);

  /// Speed in km/h for display
  double get speedKmh => speedMps * 3.6;

  /// Get formatted speed string
  String get speedDisplay => '${speedKmh.toStringAsFixed(1)} km/h';

  /// Check if state is recent (within last 2 minutes)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);
    return difference.inSeconds < 120;
  }

  /// Get time since last update
  String get lastUpdatedDisplay {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  /// Copy with new values
  VehicleStateModel copyWith({
    String? busId,
    double? lat,
    double? lng,
    double? speedMps,
    double? headingDeg,
    DateTime? updatedAt,
    int? observationId,
  }) {
    return VehicleStateModel(
      busId: busId ?? this.busId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      speedMps: speedMps ?? this.speedMps,
      headingDeg: headingDeg ?? this.headingDeg,
      updatedAt: updatedAt ?? this.updatedAt,
      observationId: observationId ?? this.observationId,
    );
  }
}
