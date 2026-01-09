/// Conductor shift model for shift management
library;

class ConductorShiftModel {
  final String id;
  final String conductorId;
  final String busId;
  final String? routeId;
  final DateTime startTime;
  final DateTime endTime;
  final ShiftStatus status;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data
  final String? conductorName;
  final String? busName;
  final String? routeName;

  ConductorShiftModel({
    required this.id,
    required this.conductorId,
    required this.busId,
    this.routeId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.conductorName,
    this.busName,
    this.routeName,
  });

  factory ConductorShiftModel.fromJson(Map<String, dynamic> json) {
    return ConductorShiftModel(
      id: json['id'] as String,
      conductorId: json['conductor_id'] as String,
      busId: json['bus_id'] as String,
      routeId: json['route_id'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      status: ShiftStatus.fromString(json['status'] as String? ?? 'scheduled'),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      conductorName: json['users']?['name'] as String?,
      busName: json['buses']?['name'] as String?,
      routeName: json['routes']?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conductor_id': conductorId,
      'bus_id': busId,
      'route_id': routeId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': status.value,
      'notes': notes,
      'created_by': createdBy,
    };
  }

  /// Duration of the shift
  Duration get duration => endTime.difference(startTime);

  /// Formatted duration
  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
  }

  /// Formatted time range
  String get timeRangeFormatted {
    final startHour = startTime.hour.toString().padLeft(2, '0');
    final startMin = startTime.minute.toString().padLeft(2, '0');
    final endHour = endTime.hour.toString().padLeft(2, '0');
    final endMin = endTime.minute.toString().padLeft(2, '0');
    return '$startHour:$startMin - $endHour:$endMin';
  }

  /// Check if shift is today
  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  /// Check if shift is upcoming
  bool get isUpcoming => startTime.isAfter(DateTime.now());

  /// Check if shift is active now
  bool get isActiveNow {
    final now = DateTime.now();
    return now.isAfter(startTime) &&
        now.isBefore(endTime) &&
        status == ShiftStatus.active;
  }
}

/// Shift status enumeration
enum ShiftStatus {
  scheduled('scheduled', 'Scheduled', '📅'),
  active('active', 'Active', '🟢'),
  completed('completed', 'Completed', '✅'),
  cancelled('cancelled', 'Cancelled', '❌'),
  noShow('no_show', 'No Show', '⚠️');

  final String value;
  final String label;
  final String emoji;

  const ShiftStatus(this.value, this.label, this.emoji);

  static ShiftStatus fromString(String value) {
    return ShiftStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ShiftStatus.scheduled,
    );
  }
}
