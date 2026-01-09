/// Compact bus status card for home screen quick check
///
/// Shows live bus status, ETA, and location at a glance.
/// Tap to open full tracking screen.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../models/vehicle_state_model.dart';
import '../models/route_model.dart';
import '../services/eta_service.dart';
import '../services/supabase_queries.dart';

/// Compact mini card showing bus status
class BusStatusMiniCard extends StatefulWidget {
  final BusModel bus;
  final RouteModel? route;
  final String? userStopName;
  final VoidCallback? onTap;

  const BusStatusMiniCard({
    super.key,
    required this.bus,
    this.route,
    this.userStopName,
    this.onTap,
  });

  @override
  State<BusStatusMiniCard> createState() => _BusStatusMiniCardState();
}

class _BusStatusMiniCardState extends State<BusStatusMiniCard> {
  final SupabaseQueries _queries = SupabaseQueries();
  final EtaService _etaService = EtaService();

  StreamSubscription? _stateSubscription;
  VehicleStateModel? _vehicleState;
  EtaResult? _etaResult;

  @override
  void initState() {
    super.initState();
    _subscribeToVehicleState();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToVehicleState() {
    _stateSubscription = _queries.streamVehicleState(widget.bus.id).listen((
      state,
    ) {
      if (mounted && state != null) {
        setState(() => _vehicleState = state);
        _calculateEta();
      }
    });
  }

  void _calculateEta() {
    if (_vehicleState == null || widget.route == null) return;
    if (widget.userStopName == null || widget.route!.busStops.isEmpty) return;

    // Find user's stop
    final userStop = widget.route!.busStops.firstWhere(
      (s) => s.name.toLowerCase() == widget.userStopName!.toLowerCase(),
      orElse: () => widget.route!.busStops.first,
    );

    final result = _etaService.calculateEta(
      busState: _vehicleState!,
      targetStop: userStop,
      routeStops: widget.route!.busStops,
    );

    if (mounted) {
      setState(() => _etaResult = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLive = widget.bus.isAvailable && _vehicleState != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isLive
            ? BorderSide(color: Colors.green.shade400, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Bus Icon with status indicator
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.green.shade50
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      size: 28,
                      color: isLive
                          ? Colors.green.shade700
                          : colorScheme.outline,
                    ),
                  ),
                  if (isLive)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Bus info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.bus.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (widget.route != null)
                      Text(
                        '${widget.route!.startLocation} → ${widget.route!.endLocation}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    _buildStatusRow(isLive, colorScheme),
                  ],
                ),
              ),

              // ETA display
              if (_etaResult != null && _etaResult!.isValid)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getEtaColor(
                      _etaResult!.status,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _etaResult!.formattedEta,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _getEtaColor(_etaResult!.status),
                        ),
                      ),
                      if (_etaResult!.stopsRemaining > 0)
                        Text(
                          '${_etaResult!.stopsRemaining} stops',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                )
              else
                Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(bool isLive, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isLive ? Colors.green.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isLive ? 'LIVE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isLive ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ),
        if (_vehicleState != null) ...[
          const SizedBox(width: 8),
          Text(
            '${(_vehicleState!.speedMps * 3.6).toStringAsFixed(0)} km/h',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Color _getEtaColor(EtaStatus status) {
    switch (status) {
      case EtaStatus.arriving:
        return Colors.green;
      case EtaStatus.soon:
        return Colors.orange;
      case EtaStatus.onTheWay:
        return Colors.blue;
      case EtaStatus.farAway:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

/// Section widget for displaying tracked buses on home screen
class TrackedBusesSection extends StatelessWidget {
  final List<BusModel> buses;
  final Map<String, RouteModel> routesMap;
  final String? defaultStopName;
  final Function(BusModel) onBusTap;

  const TrackedBusesSection({
    super.key,
    required this.buses,
    required this.routesMap,
    this.defaultStopName,
    required this.onBusTap,
  });

  @override
  Widget build(BuildContext context) {
    if (buses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.near_me,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Recently Viewed',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: buses.length,
            itemBuilder: (context, index) {
              final bus = buses[index];
              final route = routesMap[bus.routeId];
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.75,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: BusStatusMiniCard(
                    bus: bus,
                    route: route,
                    userStopName: defaultStopName,
                    onTap: () => onBusTap(bus),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
