import 'stop_model.dart';

/// Route model representing a bus route
class RouteModel {
  final String id;
  final String name;
  final String startLocation;
  final String endLocation;
  final List<StopModel> busStops;
  final double? distance; // in kilometers
  final bool isPopular;
  final DateTime? createdAt;

  RouteModel({
    required this.id,
    required this.name,
    required this.startLocation,
    required this.endLocation,
    this.busStops = const [],
    this.distance,
    this.isPopular = false,
    this.createdAt,
  });

  /// Create RouteModel from JSON (Supabase response)
  factory RouteModel.fromJson(Map<String, dynamic> json) {
    var loadedStops = <StopModel>[];

    // Handle stops from JSONB column (denormalized)
    if (json['stops'] != null) {
      final stopsJson = json['stops'];
      if (stopsJson is List) {
        loadedStops = stopsJson
            .map((e) => StopModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    return RouteModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Route',
      startLocation: json['start_location'] as String? ?? '',
      endLocation: json['end_location'] as String? ?? '',
      busStops: loadedStops,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
      isPopular: json['is_popular'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert RouteModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'start_location': startLocation,
      'end_location': endLocation,
      'bus_stops': busStops.map((stop) => stop.toJson()).toList(),
      'distance': distance,
      'is_popular': isPopular,
    };
  }

  /// Get formatted route display (Start → End)
  String get displayName => '$startLocation → $endLocation';

  /// Get number of stops
  int get stopCount => busStops.length;

  /// Copy with new values
  RouteModel copyWith({
    String? id,
    String? name,
    String? startLocation,
    String? endLocation,
    List<StopModel>? busStops,
    double? distance,
    bool? isPopular,
    DateTime? createdAt,
  }) {
    return RouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      busStops: busStops ?? this.busStops,
      distance: distance ?? this.distance,
      isPopular: isPopular ?? this.isPopular,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
