/// Proximity alert service for bus approach notifications
///
/// Monitors bus location and triggers push notifications when the bus
/// is approaching the user's selected stop at configurable distances.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/vehicle_state_model.dart';
import '../models/stop_model.dart';
import 'eta_service.dart';
import 'notification_service.dart';

/// Service for proximity-based bus approach alerts
class ProximityAlertService {
  static final ProximityAlertService _instance =
      ProximityAlertService._internal();
  factory ProximityAlertService() => _instance;
  ProximityAlertService._internal();

  final NotificationService _notificationService = NotificationService();
  final EtaService _etaService = EtaService();
  static const Distance _distanceCalculator = Distance();

  // Alert thresholds in meters
  static const List<int> _defaultThresholds = [2000, 1000, 500, 200];

  // Track which thresholds have been triggered per bus
  final Map<String, Set<int>> _triggeredThresholds = {};

  // Active monitoring subscriptions
  final Map<String, StreamSubscription> _activeMonitors = {};

  // Current monitoring state
  String? _currentBusId;
  StopModel? _currentStop;
  String? _busName;
  List<StopModel>? _routeStops;

  /// Start monitoring bus proximity to a stop
  void startMonitoring({
    required String busId,
    required String busName,
    required StopModel userStop,
    required List<StopModel> routeStops,
    required Stream<VehicleStateModel?> busStateStream,
    List<int> alertThresholds = _defaultThresholds,
  }) {
    // Stop any existing monitoring
    stopMonitoring();

    _currentBusId = busId;
    _currentStop = userStop;
    _busName = busName;
    _routeStops = routeStops;
    _triggeredThresholds[busId] = {};

    debugPrint(
      'ProximityAlert: Started monitoring $busName → ${userStop.name}',
    );

    // Subscribe to bus state updates
    final subscription = busStateStream.listen(
      (state) {
        if (state != null) {
          _checkProximity(state, alertThresholds);
        }
      },
      onError: (error) {
        debugPrint('ProximityAlert: Stream error - $error');
      },
    );

    _activeMonitors[busId] = subscription;
  }

  /// Stop all monitoring
  void stopMonitoring() {
    for (final subscription in _activeMonitors.values) {
      subscription.cancel();
    }
    _activeMonitors.clear();
    _triggeredThresholds.clear();
    _currentBusId = null;
    _currentStop = null;
    _busName = null;
    _routeStops = null;
    debugPrint('ProximityAlert: Stopped monitoring');
  }

  /// Check proximity and trigger alerts
  void _checkProximity(VehicleStateModel busState, List<int> thresholds) {
    if (_currentStop == null || _currentBusId == null) return;

    final busLatLng = busState.latLng;
    final stopLatLng = LatLng(_currentStop!.lat, _currentStop!.lng);

    // Calculate direct distance
    final distanceMeters = _distanceCalculator.as(
      LengthUnit.Meter,
      busLatLng,
      stopLatLng,
    );

    // Calculate ETA for more accurate messaging
    EtaResult? etaResult;
    if (_routeStops != null && _routeStops!.isNotEmpty) {
      etaResult = _etaService.calculateEta(
        busState: busState,
        targetStop: _currentStop!,
        routeStops: _routeStops!,
      );
    }

    // Check each threshold
    for (final threshold in thresholds) {
      if (distanceMeters <= threshold &&
          !_triggeredThresholds[_currentBusId]!.contains(threshold)) {
        // Mark as triggered
        _triggeredThresholds[_currentBusId]!.add(threshold);

        // Send notification
        _sendProximityNotification(
          threshold: threshold,
          distanceMeters: distanceMeters,
          etaResult: etaResult,
        );
      }
    }

    // Check if bus has arrived (within 50m)
    if (distanceMeters <= 50 &&
        !_triggeredThresholds[_currentBusId]!.contains(0)) {
      _triggeredThresholds[_currentBusId]!.add(0);
      _sendArrivalNotification();
    }
  }

  /// Send proximity alert notification
  void _sendProximityNotification({
    required int threshold,
    required double distanceMeters,
    EtaResult? etaResult,
  }) {
    String title;
    String body;

    if (etaResult != null && etaResult.isValid) {
      title = '🚌 ${_busName ?? "Bus"} approaching!';
      body =
          '${etaResult.formattedEta} away from ${_currentStop?.name ?? "your stop"}';
    } else {
      title = '🚌 ${_busName ?? "Bus"} nearby!';
      body =
          '${EtaService.formatDistance(distanceMeters)} from ${_currentStop?.name ?? "your stop"}';
    }

    _notificationService.showNotification(
      id: _getNotificationId(threshold),
      title: title,
      body: body,
    );

    debugPrint('ProximityAlert: Sent notification - $title: $body');
  }

  /// Send arrival notification
  void _sendArrivalNotification() {
    _notificationService.showNotification(
      id: _getNotificationId(0),
      title: '🚌 ${_busName ?? "Bus"} arriving!',
      body: 'Bus is now at ${_currentStop?.name ?? "your stop"}',
    );

    debugPrint('ProximityAlert: Bus arrived at stop');
  }

  /// Get unique notification ID based on threshold
  int _getNotificationId(int threshold) {
    // Use threshold + a base to ensure unique IDs
    return 1000 + threshold;
  }

  /// Check if currently monitoring
  bool get isMonitoring => _currentBusId != null;

  /// Get current stop being monitored
  StopModel? get currentStop => _currentStop;

  /// Get current bus being monitored
  String? get currentBusId => _currentBusId;
}

/// Proximity alert levels for UI display
enum ProximityLevel {
  farAway, // > 2km
  approaching, // 1-2km
  nearby, // 500m-1km
  veryClose, // 200-500m
  arriving, // < 200m
}

extension ProximityLevelExtension on ProximityLevel {
  static ProximityLevel fromDistance(double meters) {
    if (meters > 2000) return ProximityLevel.farAway;
    if (meters > 1000) return ProximityLevel.approaching;
    if (meters > 500) return ProximityLevel.nearby;
    if (meters > 200) return ProximityLevel.veryClose;
    return ProximityLevel.arriving;
  }

  String get displayText {
    switch (this) {
      case ProximityLevel.farAway:
        return 'En route';
      case ProximityLevel.approaching:
        return 'Approaching';
      case ProximityLevel.nearby:
        return 'Nearby';
      case ProximityLevel.veryClose:
        return 'Very close';
      case ProximityLevel.arriving:
        return 'Arriving';
    }
  }

  String get emoji {
    switch (this) {
      case ProximityLevel.farAway:
        return '🚌';
      case ProximityLevel.approaching:
        return '🚌';
      case ProximityLevel.nearby:
        return '🚌💨';
      case ProximityLevel.veryClose:
        return '🚌💨💨';
      case ProximityLevel.arriving:
        return '🎉';
    }
  }
}
