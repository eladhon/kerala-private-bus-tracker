class UserTripHistoryModel {
  final String id;
  final String userId;
  final String busId;
  final String? routeId;
  final DateTime? tripDate;
  final String? startedAtStopName;
  final String? endedAtStopName;

  // Optional: Joined bus/route data for display
  final String? busName;
  final String? routeName;
  final String? startLocation;
  final String? endLocation;

  UserTripHistoryModel({
    required this.id,
    required this.userId,
    required this.busId,
    this.routeId,
    this.tripDate,
    this.startedAtStopName,
    this.endedAtStopName,
    this.busName,
    this.routeName,
    this.startLocation,
    this.endLocation,
  });

  factory UserTripHistoryModel.fromJson(Map<String, dynamic> json) {
    return UserTripHistoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      busId: json['bus_id'] as String,
      routeId: json['route_id'] as String?,
      tripDate: json['trip_date'] != null
          ? DateTime.parse(json['trip_date'] as String)
          : null,
      startedAtStopName: json['started_at_stop_name'] as String?,
      endedAtStopName: json['ended_at_stop_name'] as String?,

      // Joined fields (assuming select users:buses(...) and routes(...))
      busName: json['buses'] != null ? json['buses']['name'] as String? : null,
      routeName: json['routes'] != null
          ? json['routes']['name'] as String?
          : null,
      startLocation: json['routes'] != null
          ? json['routes']['start_location'] as String?
          : null,
      endLocation: json['routes'] != null
          ? json['routes']['end_location'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bus_id': busId,
      'route_id': routeId,
      'trip_date': tripDate?.toIso8601String(),
      'started_at_stop_name': startedAtStopName,
      'ended_at_stop_name': endedAtStopName,
    };
  }
}
