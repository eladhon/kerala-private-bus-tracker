/// Bus model representing a private bus
class BusModel {
  final String id;
  final String name;
  final String registrationNumber;
  final String routeId;
  final String? conductorId;
  final bool isAvailable;
  final DateTime? createdAt;

  BusModel({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.routeId,
    this.conductorId,
    this.isAvailable = false,
    this.createdAt,
  });

  /// Create BusModel from JSON (Supabase response)
  factory BusModel.fromJson(Map<String, dynamic> json) {
    return BusModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Bus',
      registrationNumber: json['registration_number'] as String? ?? '',
      routeId: json['route_id'] as String? ?? '',
      conductorId: json['conductor_id'] as String?,
      isAvailable: json['is_available'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert BusModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'registration_number': registrationNumber,
      'route_id': routeId,
      'conductor_id': conductorId,
      'is_available': isAvailable,
    };
  }

  /// Copy with new values
  BusModel copyWith({
    String? id,
    String? name,
    String? registrationNumber,
    String? routeId,
    String? conductorId,
    bool? isAvailable,
    DateTime? createdAt,
  }) {
    return BusModel(
      id: id ?? this.id,
      name: name ?? this.name,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      routeId: routeId ?? this.routeId,
      conductorId: conductorId ?? this.conductorId,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
