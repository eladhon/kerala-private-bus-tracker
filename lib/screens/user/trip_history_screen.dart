/// Trip History Screen with Analytics
///
/// Shows user's bus trip history with statistics and insights.
library;

import 'package:flutter/material.dart';
import '../../services/supabase_queries.dart';
import '../../models/user_trip_history_model.dart';

/// Trip history screen showing past trips and analytics
class TripHistoryScreen extends StatefulWidget {
  final String userId;

  const TripHistoryScreen({super.key, required this.userId});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _queries = SupabaseQueries();

  List<UserTripHistoryModel> _trips = [];
  bool _isLoading = true;

  // Analytics
  int _totalTrips = 0;
  int _thisMonthTrips = 0;
  final Set<String> _uniqueRoutes = {};
  String? _mostFrequentRoute;

  @override
  void initState() {
    super.initState();
    _loadTripHistory();
  }

  Future<void> _loadTripHistory() async {
    setState(() => _isLoading = true);

    try {
      final trips = await _queries.getUserTripHistory(widget.userId);

      // Calculate analytics
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);

      int thisMonth = 0;
      Map<String, int> routeCount = {};
      Map<String, String> routeNames = {};

      for (final trip in trips) {
        if (trip.tripDate != null && trip.tripDate!.isAfter(thisMonthStart)) {
          thisMonth++;
        }

        if (trip.routeId != null) {
          _uniqueRoutes.add(trip.routeId!);
          routeCount[trip.routeId!] = (routeCount[trip.routeId!] ?? 0) + 1;
          if (trip.routeName != null) {
            routeNames[trip.routeId!] = trip.routeName!;
          }
        }
      }

      // Find most frequent route
      String? mostFrequentId;
      int maxCount = 0;
      routeCount.forEach((routeId, count) {
        if (count > maxCount) {
          maxCount = count;
          mostFrequentId = routeId;
        }
      });

      if (mounted) {
        setState(() {
          _trips = trips;
          _totalTrips = trips.length;
          _thisMonthTrips = thisMonth;
          _mostFrequentRoute = mostFrequentId != null
              ? routeNames[mostFrequentId]
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trip history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip History'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTripHistory,
              child: CustomScrollView(
                slivers: [
                  // Analytics Cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Stats',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  icon: Icons.directions_bus,
                                  label: 'Total Trips',
                                  value: _totalTrips.toString(),
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  icon: Icons.calendar_month,
                                  label: 'This Month',
                                  value: _thisMonthTrips.toString(),
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  icon: Icons.route,
                                  label: 'Routes Used',
                                  value: _uniqueRoutes.length.toString(),
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  icon: Icons.star,
                                  label: 'Favorite Route',
                                  value: _mostFrequentRoute ?? '-',
                                  color: Colors.purple,
                                  isText: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Trip History Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        'Recent Trips',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Trip List
                  if (_trips.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No trips yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your bus trips will appear here',
                              style: TextStyle(color: colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final trip = _trips[index];
                        return _buildTripCard(context, trip);
                      }, childCount: _trips.length),
                    ),

                  // Bottom padding
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isText = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            isText ? value : value,
            style: TextStyle(
              fontSize: isText ? 14 : 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, UserTripHistoryModel trip) {
    final colorScheme = Theme.of(context).colorScheme;
    final tripDate = trip.tripDate;
    final startStop = trip.startedAtStopName;
    final endStop = trip.endedAtStopName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Date circle
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tripDate?.day.toString() ?? '-',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    _getMonthAbbr(tripDate?.month ?? 0),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Trip details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.routeName ?? 'Unknown Route',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (startStop != null || endStop != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            startStop ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: Colors.red.shade400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            endStop ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Bus icon
            Icon(Icons.directions_bus, color: colorScheme.outline),
          ],
        ),
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month.clamp(0, 12)];
  }
}
