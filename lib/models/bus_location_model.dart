import 'package:latlong2/latlong.dart';

/// Bus location model for real-time GPS tracking
class BusLocationModel {
  final String busId;
  final double latitude;
  final double longitude;
  final double? speed; // in km/h
  final double? heading; // in degrees
  final DateTime updatedAt;

  BusLocationModel({
    required this.busId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    required this.updatedAt,
  });

  /// Create BusLocationModel from JSON (Supabase response)
  factory BusLocationModel.fromJson(Map<String, dynamic> json) {
    return BusLocationModel(
      busId: json['bus_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speed: json['speed'] != null ? (json['speed'] as num).toDouble() : null,
      heading: json['heading'] != null
          ? (json['heading'] as num).toDouble()
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert BusLocationModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'bus_id': busId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get LatLng for map display
  LatLng get latLng => LatLng(latitude, longitude);

  /// Check if location is recent (within last 5 minutes)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);
    return difference.inMinutes < 5;
  }

  /// Get formatted speed string
  String get speedDisplay {
    if (speed == null) return 'N/A';
    return '${speed!.toStringAsFixed(1)} km/h';
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
  BusLocationModel copyWith({
    String? busId,
    double? latitude,
    double? longitude,
    double? speed,
    double? heading,
    DateTime? updatedAt,
  }) {
    return BusLocationModel(
      busId: busId ?? this.busId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
