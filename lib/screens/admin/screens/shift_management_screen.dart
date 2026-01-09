/// Shift Management Screen for Admin Panel
///
/// Allows admins to view, create, and manage conductor shifts.
library;

import 'package:flutter/material.dart';
import '../../../models/conductor_shift_model.dart';
import '../../../models/bus_model.dart';
import '../../../models/user_model.dart';
import '../../../services/queries/shift_queries.dart';
import '../../../services/supabase_queries.dart';

/// Admin screen for managing conductor shifts
class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  final _shiftQueries = ShiftQueries();
  final _queries = SupabaseQueries();

  List<ConductorShiftModel> _shifts = [];
  List<UserModel> _conductors = [];
  List<BusModel> _buses = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _shiftQueries.getAllShifts(
          fromDate: _selectedDate,
          toDate: _selectedDate.add(const Duration(days: 7)),
        ),
        _queries.getAllConductors(),
        _queries.getAllBuses(),
      ]);

      if (mounted) {
        setState(() {
          _shifts = results[0] as List<ConductorShiftModel>;
          _conductors = results[1] as List<UserModel>;
          _buses = results[2] as List<BusModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading shifts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Management'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateShiftDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Shift'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date selector
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Week of ${_formatDate(_selectedDate)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            _selectedDate = _selectedDate.subtract(
                              const Duration(days: 7),
                            );
                          });
                          _loadData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            _selectedDate = _selectedDate.add(
                              const Duration(days: 7),
                            );
                          });
                          _loadData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.today),
                        onPressed: () {
                          setState(() => _selectedDate = DateTime.now());
                          _loadData();
                        },
                      ),
                    ],
                  ),
                ),

                // Stats summary
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildMiniStat(
                        context,
                        '${_shifts.length}',
                        'Total Shifts',
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildMiniStat(
                        context,
                        '${_shifts.where((s) => s.status == ShiftStatus.scheduled).length}',
                        'Scheduled',
                        Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _buildMiniStat(
                        context,
                        '${_shifts.where((s) => s.status == ShiftStatus.active).length}',
                        'Active',
                        Colors.green,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Shifts list
                Expanded(
                  child: _shifts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 64,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No shifts scheduled',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () =>
                                    _showCreateShiftDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Create Shift'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _shifts.length,
                          itemBuilder: (context, index) {
                            return _buildShiftCard(context, _shifts[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, ConductorShiftModel shift) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Date badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        shift.startTime.day.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        _getMonthAbbr(shift.startTime.month),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Shift details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.conductorName ?? 'Unknown Conductor',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.directions_bus,
                            size: 14,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            shift.busName ?? 'Unknown Bus',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${shift.timeRangeFormatted} (${shift.durationFormatted})',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(shift.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${shift.status.emoji} ${shift.status.label}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(shift.status),
                    ),
                  ),
                ),
              ],
            ),

            // Actions
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (shift.status == ShiftStatus.scheduled) ...[
                  TextButton.icon(
                    onPressed: () => _updateStatus(shift, ShiftStatus.active),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _updateStatus(shift, ShiftStatus.cancelled),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel'),
                  ),
                ],
                if (shift.status == ShiftStatus.active)
                  TextButton.icon(
                    onPressed: () =>
                        _updateStatus(shift, ShiftStatus.completed),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Complete'),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDelete(shift),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.scheduled:
        return Colors.orange;
      case ShiftStatus.active:
        return Colors.green;
      case ShiftStatus.completed:
        return Colors.blue;
      case ShiftStatus.cancelled:
        return Colors.red;
      case ShiftStatus.noShow:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(
    ConductorShiftModel shift,
    ShiftStatus newStatus,
  ) async {
    final success = await _shiftQueries.updateShiftStatus(shift.id, newStatus);
    if (success && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shift ${newStatus.label.toLowerCase()}')),
      );
    }
  }

  Future<void> _confirmDelete(ConductorShiftModel shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift?'),
        content: Text('Delete shift for ${shift.conductorName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _shiftQueries.deleteShift(shift.id);
      if (mounted && success) {
        _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Shift deleted')));
      }
    }
  }

  void _showCreateShiftDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateShiftSheet(
        conductors: _conductors,
        buses: _buses,
        onCreated: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}';
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

/// Bottom sheet for creating new shifts
class _CreateShiftSheet extends StatefulWidget {
  final List<UserModel> conductors;
  final List<BusModel> buses;
  final VoidCallback onCreated;

  const _CreateShiftSheet({
    required this.conductors,
    required this.buses,
    required this.onCreated,
  });

  @override
  State<_CreateShiftSheet> createState() => _CreateShiftSheetState();
}

class _CreateShiftSheetState extends State<_CreateShiftSheet> {
  final _shiftQueries = ShiftQueries();

  String? _selectedConductorId;
  String? _selectedBusId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 0);
  bool _isCreating = false;

  Future<void> _createShift() async {
    if (_selectedConductorId == null || _selectedBusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select conductor and bus')),
      );
      return;
    }

    setState(() => _isCreating = true);

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final result = await _shiftQueries.createShift(
      conductorId: _selectedConductorId!,
      busId: _selectedBusId!,
      startTime: startDateTime,
      endTime: endDateTime,
    );

    if (mounted) {
      setState(() => _isCreating = false);
      if (result != null) {
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift created'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create shift'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Create New Shift',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Conductor dropdown
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Conductor',
              prefixIcon: Icon(Icons.person),
            ),
            initialValue: _selectedConductorId,
            items: widget.conductors
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (value) => setState(() => _selectedConductorId = value),
          ),
          const SizedBox(height: 16),

          // Bus dropdown
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Bus',
              prefixIcon: Icon(Icons.directions_bus),
            ),
            initialValue: _selectedBusId,
            items: widget.buses
                .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                .toList(),
            onChanged: (value) => setState(() => _selectedBusId = value),
          ),
          const SizedBox(height: 16),

          // Date and time
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('${_selectedDate.day}/${_selectedDate.month}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (time != null) setState(() => _startTime = time);
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_startTime.format(context)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('to'),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (time != null) setState(() => _endTime = time);
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_endTime.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Create button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isCreating ? null : _createShift,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Shift'),
            ),
          ),
        ],
      ),
    );
  }
}
