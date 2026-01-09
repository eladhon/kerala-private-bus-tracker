/// Bus model representing a private bus
library;

import 'bus_schedule_model.dart';

class BusModel {
  final String id;
  final String name;
  final String registrationNumber;
  final String routeId;
  final String? conductorId;
  final bool isAvailable;
  final String? unavailabilityReason;
  final String? departureTime; // Format: "HH:mm" (Legacy, kept for backup)
  final List<BusScheduleModel> schedule;
  final DateTime? createdAt;

  BusModel({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.routeId,
    this.conductorId,
    this.isAvailable = false,
    this.unavailabilityReason,
    this.departureTime,
    this.schedule = const [],
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
      unavailabilityReason: json['unavailability_reason'] as String?,
      departureTime: json['departure_time'] as String?,
      schedule:
          (json['schedule'] as List<dynamic>?)
              ?.map((e) => BusScheduleModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
      'unavailability_reason': unavailabilityReason,
      'departure_time': departureTime,
      'schedule': schedule.map((e) => e.toJson()).toList(),
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
    String? unavailabilityReason,
    String? departureTime,
    List<BusScheduleModel>? schedule,
    DateTime? createdAt,
  }) {
    return BusModel(
      id: id ?? this.id,
      name: name ?? this.name,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      routeId: routeId ?? this.routeId,
      conductorId: conductorId ?? this.conductorId,
      isAvailable: isAvailable ?? this.isAvailable,
      unavailabilityReason: unavailabilityReason ?? this.unavailabilityReason,
      departureTime: departureTime ?? this.departureTime,
      schedule: schedule ?? this.schedule,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
