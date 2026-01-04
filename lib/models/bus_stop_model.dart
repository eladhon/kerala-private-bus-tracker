/// Bus stop model representing a stop with location
class BusStopModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? routeId; // Optional - implicit when nested in Route
  final int? orderIndex; // Optional - implicit by list order
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

  /// Create BusStopModel from JSON (Supabase response or JSONB element)
  factory BusStopModel.fromJson(Map<String, dynamic> json) {
    return BusStopModel(
      id: json['id'] as String? ?? '', // Handle missing ID gracefully
      name: json['name'] as String? ?? 'Unknown Stop',
      // Support both 'lat' (user schema) and 'latitude' (canonical) just in case
      latitude: ((json['lat'] ?? json['latitude']) as num?)?.toDouble() ?? 0.0,
      longitude:
          ((json['lng'] ?? json['longitude']) as num?)?.toDouble() ?? 0.0,
      routeId: json['route_id'] as String?,
      // Support 'order' and 'order_index'
      orderIndex: (json['order'] ?? json['order_index']) as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert BusStopModel to JSON (for JSONB storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': latitude,
      'lng': longitude,
      if (routeId != null) 'route_id': routeId,
      if (orderIndex != null) 'order': orderIndex,
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
