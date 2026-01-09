/// ETA calculation service for accurate bus arrival predictions
///
/// Uses real-time bus position, speed, and route geometry to calculate
/// estimated time of arrival at any stop along the route.
library;

import 'package:latlong2/latlong.dart';
import '../models/vehicle_state_model.dart';
import '../models/stop_model.dart';

/// Service for calculating estimated time of arrival
class EtaService {
  static final EtaService _instance = EtaService._internal();
  factory EtaService() => _instance;
  EtaService._internal();

  /// Haversine distance calculator
  static const Distance _distanceCalculator = Distance();

  /// Minimum speed assumption when bus is stationary (m/s)
  /// Assumes bus will resume at ~20 km/h average
  static const double _minimumAssumedSpeed = 5.5; // ~20 km/h

  /// Average stop dwell time in seconds
  static const int _averageStopDwellSeconds = 30;

  /// Calculate ETA from bus current position to a target stop
  ///
  /// Returns Duration.zero if bus has passed the stop or data is invalid
  EtaResult calculateEta({
    required VehicleStateModel busState,
    required StopModel targetStop,
    required List<StopModel> routeStops,
    StopModel? userSourceStop,
  }) {
    if (routeStops.isEmpty) {
      return EtaResult.unknown();
    }

    final busLatLng = busState.latLng;
    final targetLatLng = LatLng(targetStop.lat, targetStop.lng);

    // Find the index of target stop in route
    int targetStopIndex = _findStopIndex(routeStops, targetStop);
    if (targetStopIndex == -1) {
      return EtaResult.unknown();
    }

    // Find which stop the bus is closest to (current position on route)
    int currentStopIndex = _findNearestStopIndex(busLatLng, routeStops);

    // Calculate stops remaining
    int stopsRemaining = targetStopIndex - currentStopIndex;

    // If bus has passed the target stop
    if (stopsRemaining < 0) {
      return EtaResult.passed();
    }

    // If bus is at the target stop
    if (stopsRemaining == 0) {
      double distanceToStop = _distanceCalculator.as(
        LengthUnit.Meter,
        busLatLng,
        targetLatLng,
      );
      if (distanceToStop < 100) {
        return EtaResult.arriving();
      }
    }

    // Calculate total distance along route from bus to target
    double totalDistance = _calculateRouteDistance(
      busLatLng,
      routeStops,
      currentStopIndex,
      targetStopIndex,
    );

    // Get current speed, use minimum if stationary
    double speedMps = busState.speedMps > _minimumAssumedSpeed
        ? busState.speedMps
        : _minimumAssumedSpeed;

    // Calculate travel time
    double travelTimeSeconds = totalDistance / speedMps;

    // Add dwell time for each stop between current and target
    int dwellStops = stopsRemaining > 0 ? stopsRemaining - 1 : 0;
    int dwellTimeSeconds = dwellStops * _averageStopDwellSeconds;

    // Total ETA
    int totalSeconds = (travelTimeSeconds + dwellTimeSeconds).round();
    Duration eta = Duration(seconds: totalSeconds);

    return EtaResult(
      eta: eta,
      distanceMeters: totalDistance,
      stopsRemaining: stopsRemaining,
      status: _getStatus(eta),
    );
  }

  /// Find the index of a stop in the route
  int _findStopIndex(List<StopModel> routeStops, StopModel target) {
    for (int i = 0; i < routeStops.length; i++) {
      if (routeStops[i].id == target.id ||
          routeStops[i].name.toLowerCase() == target.name.toLowerCase()) {
        return i;
      }
    }
    return -1;
  }

  /// Find the stop nearest to the bus's current position
  int _findNearestStopIndex(LatLng busLatLng, List<StopModel> stops) {
    if (stops.isEmpty) return -1;

    int nearestIndex = 0;
    double nearestDistance = double.infinity;

    for (int i = 0; i < stops.length; i++) {
      final stopLatLng = LatLng(stops[i].lat, stops[i].lng);
      final distance = _distanceCalculator.as(
        LengthUnit.Meter,
        busLatLng,
        stopLatLng,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  /// Calculate distance along the route from bus position to target stop
  double _calculateRouteDistance(
    LatLng busLatLng,
    List<StopModel> routeStops,
    int currentStopIndex,
    int targetStopIndex,
  ) {
    double totalDistance = 0;

    // Distance from bus to next stop
    if (currentStopIndex < routeStops.length) {
      final nextStop = routeStops[currentStopIndex];
      totalDistance += _distanceCalculator.as(
        LengthUnit.Meter,
        busLatLng,
        LatLng(nextStop.lat, nextStop.lng),
      );
    }

    // Distance between intermediate stops
    for (
      int i = currentStopIndex;
      i < targetStopIndex && i < routeStops.length - 1;
      i++
    ) {
      final from = LatLng(routeStops[i].lat, routeStops[i].lng);
      final to = LatLng(routeStops[i + 1].lat, routeStops[i + 1].lng);
      totalDistance += _distanceCalculator.as(LengthUnit.Meter, from, to);
    }

    return totalDistance;
  }

  /// Determine ETA status based on duration
  EtaStatus _getStatus(Duration eta) {
    if (eta.inSeconds < 60) {
      return EtaStatus.arriving;
    } else if (eta.inMinutes <= 5) {
      return EtaStatus.soon;
    } else if (eta.inMinutes <= 15) {
      return EtaStatus.onTheWay;
    } else {
      return EtaStatus.farAway;
    }
  }

  /// Format ETA for display
  static String formatEta(Duration eta) {
    if (eta == Duration.zero) {
      return 'Arriving';
    }

    if (eta.inMinutes < 1) {
      return '< 1 min';
    } else if (eta.inMinutes < 60) {
      return '${eta.inMinutes} min';
    } else {
      int hours = eta.inHours;
      int minutes = eta.inMinutes % 60;
      if (minutes == 0) {
        return '$hours hr';
      }
      return '$hours hr ${minutes}m';
    }
  }

  /// Format distance for display
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
}

/// Result of ETA calculation
class EtaResult {
  final Duration eta;
  final double distanceMeters;
  final int stopsRemaining;
  final EtaStatus status;

  EtaResult({
    required this.eta,
    required this.distanceMeters,
    required this.stopsRemaining,
    required this.status,
  });

  factory EtaResult.unknown() => EtaResult(
    eta: Duration.zero,
    distanceMeters: 0,
    stopsRemaining: 0,
    status: EtaStatus.unknown,
  );

  factory EtaResult.passed() => EtaResult(
    eta: Duration.zero,
    distanceMeters: 0,
    stopsRemaining: 0,
    status: EtaStatus.passed,
  );

  factory EtaResult.arriving() => EtaResult(
    eta: Duration.zero,
    distanceMeters: 0,
    stopsRemaining: 0,
    status: EtaStatus.arriving,
  );

  bool get isValid => status != EtaStatus.unknown && status != EtaStatus.passed;

  String get formattedEta => EtaService.formatEta(eta);
  String get formattedDistance => EtaService.formatDistance(distanceMeters);

  String get statusText {
    switch (status) {
      case EtaStatus.arriving:
        return 'Arriving now';
      case EtaStatus.soon:
        return 'Arriving soon';
      case EtaStatus.onTheWay:
        return 'On the way';
      case EtaStatus.farAway:
        return 'En route';
      case EtaStatus.passed:
        return 'Bus passed';
      case EtaStatus.unknown:
        return 'Calculating...';
    }
  }
}

/// ETA status enumeration
enum EtaStatus {
  arriving, // < 1 min
  soon, // 1-5 min
  onTheWay, // 5-15 min
  farAway, // > 15 min
  passed, // Bus already passed the stop
  unknown, // Cannot calculate
}
