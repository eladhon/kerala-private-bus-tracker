/// Admin Analytics Dashboard
///
/// Shows fleet-wide statistics, bus performance, and conductor metrics.
library;

import 'package:flutter/material.dart';
import '../../../services/supabase_queries.dart';
import '../../../services/supabase_service.dart';

/// Analytics dashboard for admin panel
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _queries = SupabaseQueries();
  final _supabase = SupabaseService().client;
  bool _isLoading = true;

  // Fleet Stats
  int _totalBuses = 0;
  int _activeBuses = 0;
  int _totalConductors = 0;
  int _activeConductors = 0;
  int _totalRoutes = 0;
  int _totalUsers = 0;

  // Performance Stats
  List<Map<String, dynamic>> _recentDelays = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      // Load all stats in parallel
      final results = await Future.wait([
        _queries.getAllBuses(),
        _queries.getAllConductors(),
        _queries.getAllRoutes(),
        _loadUserCount(),
        _loadActiveStats(),
        _loadRecentDelays(),
      ]);

      final buses = results[0] as List;
      final conductors = results[1] as List;
      final routes = results[2] as List;
      final userCount = results[3] as int;
      final activeStats = results[4] as Map<String, int>;
      final delays = results[5] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _totalBuses = buses.length;
          _activeBuses = activeStats['activeBuses'] ?? 0;
          _totalConductors = conductors.length;
          _activeConductors = activeStats['activeConductors'] ?? 0;
          _totalRoutes = routes.length;
          _totalUsers = userCount;
          _recentDelays = delays;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _loadUserCount() async {
    try {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'user');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, int>> _loadActiveStats() async {
    try {
      // Count buses with recent vehicle state updates
      final activeBusesResponse = await _supabase
          .from('vehicle_state')
          .select('bus_id')
          .gt(
            'updated_at',
            DateTime.now()
                .subtract(const Duration(minutes: 30))
                .toIso8601String(),
          );

      // Count available conductors
      final activeConductorsResponse = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'conductor')
          .eq('is_available', true);

      return {
        'activeBuses': (activeBusesResponse as List).length,
        'activeConductors': (activeConductorsResponse as List).length,
      };
    } catch (e) {
      return {'activeBuses': 0, 'activeConductors': 0};
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentDelays() async {
    try {
      final response = await _supabase
          .from('delay_reports')
          .select('*, buses(name)')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    // final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fleet Overview
                    Text(
                      'Fleet Overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _buildStatCard(
                          context,
                          icon: Icons.directions_bus,
                          title: 'Buses',
                          value: '$_activeBuses / $_totalBuses',
                          subtitle: 'Active now',
                          color: Colors.blue,
                          progress: _totalBuses > 0
                              ? _activeBuses / _totalBuses
                              : 0,
                        ),
                        _buildStatCard(
                          context,
                          icon: Icons.person,
                          title: 'Conductors',
                          value: '$_activeConductors / $_totalConductors',
                          subtitle: 'On duty',
                          color: Colors.green,
                          progress: _totalConductors > 0
                              ? _activeConductors / _totalConductors
                              : 0,
                        ),
                        _buildStatCard(
                          context,
                          icon: Icons.route,
                          title: 'Routes',
                          value: _totalRoutes.toString(),
                          subtitle: 'Total routes',
                          color: Colors.orange,
                        ),
                        _buildStatCard(
                          context,
                          icon: Icons.people,
                          title: 'Users',
                          value: _totalUsers.toString(),
                          subtitle: 'Registered',
                          color: Colors.purple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Active Delays
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Delays',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_recentDelays.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_recentDelays.length} active',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_recentDelays.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'No active delays! All buses running on time.',
                              style: TextStyle(color: Colors.green.shade700),
                            ),
                          ],
                        ),
                      )
                    else
                      ...(_recentDelays.map(
                        (delay) => _buildDelayCard(context, delay),
                      )),

                    const SizedBox(height: 32),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildActionChip(
                          context,
                          icon: Icons.download,
                          label: 'Export Report',
                          onTap: () => _showExportDialog(context),
                        ),
                        _buildActionChip(
                          context,
                          icon: Icons.notifications_active,
                          label: 'Send Alert',
                          onTap: () => _showAlertDialog(context),
                        ),
                        _buildActionChip(
                          context,
                          icon: Icons.schedule,
                          label: 'View Shifts',
                          onTap: () => _showShiftsInfo(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    double? progress,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              if (progress != null)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: progress,
                    backgroundColor: color.withValues(alpha: 0.2),
                    color: color,
                    strokeWidth: 4,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelayCard(BuildContext context, Map<String, dynamic> delay) {
    final busName = delay['buses']?['name'] ?? 'Unknown Bus';
    final minutes = delay['delay_minutes'] as int? ?? 0;
    final reason = delay['reason'] as String? ?? 'other';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.timer, color: Colors.orange.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  busName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$minutes min delay • ${_getReasonEmoji(reason)} $reason',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getReasonEmoji(String reason) {
    switch (reason) {
      case 'traffic':
        return '🚗';
      case 'breakdown':
        return '🔧';
      case 'weather':
        return '🌧️';
      case 'accident':
        return '🚨';
      case 'strike':
        return '✊';
      default:
        return '📝';
    }
  }

  Widget _buildActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: const Text('Report export feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Fleet Alert'),
        content: const Text('Fleet-wide alert feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showShiftsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shift Management'),
        content: const Text('Shift management feature coming in next phase!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
