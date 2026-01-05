/// Bus Trip model representing a journey
class BusTripModel {
  final String id;
  final String busId;
  final String routeId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // scheduled, active, completed, cancelled
  final DateTime? createdAt;

  BusTripModel({
    required this.id,
    required this.busId,
    required this.routeId,
    required this.startTime,
    this.endTime,
    this.status = 'scheduled',
    this.createdAt,
  });

  /// Create BusTripModel from JSON (Supabase response)
  factory BusTripModel.fromJson(Map<String, dynamic> json) {
    return BusTripModel(
      id: json['id'] as String? ?? '',
      busId: json['bus_id'] as String? ?? '',
      routeId: json['route_id'] as String? ?? '',
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'] as String)
          : DateTime.now(),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      status: json['status'] as String? ?? 'scheduled',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert BusTripModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_id': busId,
      'route_id': routeId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status,
    };
  }

  /// Copy with new values
  BusTripModel copyWith({
    String? id,
    String? busId,
    String? routeId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    DateTime? createdAt,
  }) {
    return BusTripModel(
      id: id ?? this.id,
      busId: busId ?? this.busId,
      routeId: routeId ?? this.routeId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
