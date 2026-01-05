/// Stop model representing a bus stop
class StopModel {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final DateTime? createdAt;

  // orderIndex is context-dependent (used when part of a route)
  final int? orderIndex;

  StopModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.createdAt,
    this.orderIndex,
  });

  /// Create StopModel from JSON (Supabase response)
  factory StopModel.fromJson(Map<String, dynamic> json) {
    return StopModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Stop',
      // Expecting 'lat' and 'lng' from computed columns or RPC, or just regular columns if flat
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      orderIndex: json['order_index'] as int?,
    );
  }

  /// Create StopModel from joined route_stops query
  /// Structure: { "stop_order": 1, "stops": { "id": "...", "name": "...", ... } }
  factory StopModel.fromRouteStopJson(Map<String, dynamic> json) {
    final stopData = json['stops'] as Map<String, dynamic>? ?? {};
    final order = json['stop_order'] as int?;

    // We expect the 'stops' object to have the details, but lat/lng might be missing if not selected properly
    // We rely on the query selecting stops(id, name, lat, lng)

    return StopModel(
      id: stopData['id'] as String? ?? '',
      name: stopData['name'] as String? ?? 'Unknown Stop',
      lat: (stopData['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (stopData['lng'] as num?)?.toDouble() ?? 0.0,
      createdAt: stopData['created_at'] != null
          ? DateTime.parse(stopData['created_at'] as String)
          : null,
      orderIndex: order,
    );
  }

  /// Convert StopModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'order_index': orderIndex,
    };
  }

  /// Copy with new values
  StopModel copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    DateTime? createdAt,
    int? orderIndex,
  }) {
    return StopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
