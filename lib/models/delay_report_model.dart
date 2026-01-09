/// Delay report model for conductor delay reporting
library;

class DelayReportModel {
  final String id;
  final String busId;
  final String? routeId;
  final int delayMinutes;
  final DelayReason reason;
  final String? notes;
  final String reportedBy;
  final DateTime expiresAt;
  final bool isActive;
  final DateTime createdAt;

  DelayReportModel({
    required this.id,
    required this.busId,
    this.routeId,
    required this.delayMinutes,
    required this.reason,
    this.notes,
    required this.reportedBy,
    required this.expiresAt,
    required this.isActive,
    required this.createdAt,
  });

  factory DelayReportModel.fromJson(Map<String, dynamic> json) {
    return DelayReportModel(
      id: json['id'] as String,
      busId: json['bus_id'] as String,
      routeId: json['route_id'] as String?,
      delayMinutes: json['delay_minutes'] as int,
      reason: DelayReason.fromString(json['reason'] as String? ?? 'other'),
      notes: json['notes'] as String?,
      reportedBy: json['reported_by'] as String,
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bus_id': busId,
      'route_id': routeId,
      'delay_minutes': delayMinutes,
      'reason': reason.value,
      'notes': notes,
      'reported_by': reportedBy,
    };
  }

  /// Formatted delay text
  String get formattedDelay {
    if (delayMinutes < 60) {
      return '$delayMinutes min late';
    } else {
      final hours = delayMinutes ~/ 60;
      final mins = delayMinutes % 60;
      return mins > 0 ? '$hours hr $mins min late' : '$hours hr late';
    }
  }

  /// Check if delay is still active
  bool get isStillActive => isActive && expiresAt.isAfter(DateTime.now());
}

/// Delay reason enumeration
enum DelayReason {
  traffic('traffic', 'Traffic', '🚗'),
  breakdown('breakdown', 'Breakdown', '🔧'),
  weather('weather', 'Weather', '🌧️'),
  accident('accident', 'Accident', '🚨'),
  strike('strike', 'Strike', '✊'),
  other('other', 'Other', '📝');

  final String value;
  final String label;
  final String emoji;

  const DelayReason(this.value, this.label, this.emoji);

  static DelayReason fromString(String value) {
    return DelayReason.values.firstWhere(
      (r) => r.value == value,
      orElse: () => DelayReason.other,
    );
  }
}
