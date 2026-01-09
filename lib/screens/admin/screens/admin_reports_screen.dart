import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/bus_model.dart';
import '../../../../models/conductor_report_model.dart';
import '../../../../models/user_model.dart';
import '../../../../services/supabase_queries.dart';

class AdminReportsScreen extends StatefulWidget {
  final List<UserModel> conductors;
  final List<BusModel> buses;

  const AdminReportsScreen({
    super.key,
    required this.conductors,
    required this.buses,
  });

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _queries = SupabaseQueries();

  List<ConductorReportModel> _repairReports = [];
  List<ConductorReportModel> _fuelReports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final repairs = await _queries.getAllConductorReports('repair');
      final fuels = await _queries.getAllConductorReports('fuel');

      if (mounted) {
        setState(() {
          _repairReports = repairs;
          _fuelReports = fuels;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getBusName(String busId) {
    final bus = widget.buses.where((b) => b.id == busId).firstOrNull;
    return bus?.name ?? 'Unknown Bus';
  }

  String _getConductorName(String userId) {
    final conductor = widget.conductors
        .where((u) => u.id == userId)
        .firstOrNull;
    return conductor?.name ?? 'Unknown Conductor';
  }

  Widget _buildReportList(List<ConductorReportModel> reports) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No reports found',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        final dateFormat = DateFormat('MMM d, y • h:mm a');

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getBusName(report.busId),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'By: ${_getConductorName(report.userId)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      dateFormat.format(report.createdAt),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  report.content ?? 'No content provided',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (report.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: report.mediaUrls.length,
                      itemBuilder: (context, imgIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              report.mediaUrls[imgIndex],
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  width: 100,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Repair Reports', icon: Icon(Icons.build)),
              Tab(text: 'Fuel Logs', icon: Icon(Icons.local_gas_station)),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReportList(_repairReports),
                    _buildReportList(_fuelReports),
                  ],
                ),
        ),
      ],
    );
  }
}
