/// SOS Alert model for emergency feature
library;

class SosAlertModel {
  final String id;
  final String userId;
  final String userRole;
  final String? busId;
  final String? routeId;
  final double lat;
  final double lng;
  final SosAlertType alertType;
  final String? description;
  final SosStatus status;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  // Joined data
  final String? userName;
  final String? busName;

  SosAlertModel({
    required this.id,
    required this.userId,
    required this.userRole,
    this.busId,
    this.routeId,
    required this.lat,
    required this.lng,
    required this.alertType,
    this.description,
    required this.status,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolvedAt,
    required this.createdAt,
    this.userName,
    this.busName,
  });

  factory SosAlertModel.fromJson(Map<String, dynamic> json) {
    return SosAlertModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userRole: json['user_role'] as String? ?? 'user',
      busId: json['bus_id'] as String?,
      routeId: json['route_id'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      alertType: SosAlertType.fromString(
        json['alert_type'] as String? ?? 'emergency',
      ),
      description: json['description'] as String?,
      status: SosStatus.fromString(json['status'] as String? ?? 'active'),
      acknowledgedBy: json['acknowledged_by'] as String?,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.tryParse(json['acknowledged_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      userName: json['users']?['name'] as String?,
      busName: json['buses']?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_role': userRole,
      'bus_id': busId,
      'route_id': routeId,
      'lat': lat,
      'lng': lng,
      'alert_type': alertType.value,
      'description': description,
      'status': status.value,
    };
  }

  /// Check if alert is still active
  bool get isActive =>
      status == SosStatus.active || status == SosStatus.acknowledged;
}

/// SOS alert type enumeration
enum SosAlertType {
  emergency('emergency', 'Emergency', '🆘', 'General emergency'),
  harassment('harassment', 'Harassment', '⚠️', 'Report harassment'),
  accident('accident', 'Accident', '💥', 'Vehicle accident'),
  medical('medical', 'Medical', '🏥', 'Medical emergency'),
  other('other', 'Other', '❓', 'Other issue');

  final String value;
  final String label;
  final String emoji;
  final String description;

  const SosAlertType(this.value, this.label, this.emoji, this.description);

  static SosAlertType fromString(String value) {
    return SosAlertType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => SosAlertType.emergency,
    );
  }
}

/// SOS status enumeration
enum SosStatus {
  active('active', 'Active'),
  acknowledged('acknowledged', 'Acknowledged'),
  responding('responding', 'Responding'),
  resolved('resolved', 'Resolved'),
  falseAlarm('false_alarm', 'False Alarm');

  final String value;
  final String label;

  const SosStatus(this.value, this.label);

  static SosStatus fromString(String value) {
    return SosStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => SosStatus.active,
    );
  }
}
