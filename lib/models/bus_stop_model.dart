/// Bus stop model representing a stop with location
class BusStopModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? routeId; // Optional - can be shared across routes
  final int? orderIndex; // Order in the route
  final DateTime? createdAt;

  BusStopModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.routeId,
    this.orderIndex,
    this.createdAt,
  });

  /// Create BusStopModel from JSON (Supabase response)
  factory BusStopModel.fromJson(Map<String, dynamic> json) {
    return BusStopModel(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      routeId: json['route_id'] as String?,
      orderIndex: json['order_index'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert BusStopModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'route_id': routeId,
      'order_index': orderIndex,
    };
  }

  /// Copy with new values
  BusStopModel copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? routeId,
    int? orderIndex,
    DateTime? createdAt,
  }) {
    return BusStopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      routeId: routeId ?? this.routeId,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
