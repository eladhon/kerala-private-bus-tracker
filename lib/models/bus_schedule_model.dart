class BusScheduleModel {
  final String routeId;
  final String departureTime; // "HH:mm"

  BusScheduleModel({required this.routeId, required this.departureTime});

  factory BusScheduleModel.fromJson(Map<String, dynamic> json) {
    return BusScheduleModel(
      routeId: json['route_id'] as String? ?? '',
      departureTime: json['departure_time'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'route_id': routeId, 'departure_time': departureTime};
  }
}
