/// SOS Emergency Button Widget
///
/// Floating emergency button that triggers SOS alerts.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/sos_alert_model.dart';
import '../../services/queries/sos_queries.dart';

/// Floating SOS button for emergency alerts
class SosButton extends StatefulWidget {
  final String userId;
  final String userRole;
  final String? busId;
  final String? routeId;

  const SosButton({
    super.key,
    required this.userId,
    this.userRole = 'user',
    this.busId,
    this.routeId,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: FloatingActionButton(
            heroTag: 'sos_button',
            backgroundColor: Colors.red,
            onPressed: () => _showSosDialog(context),
            child: const Icon(Icons.sos, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }

  void _showSosDialog(BuildContext context) {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SosDialog(
        userId: widget.userId,
        userRole: widget.userRole,
        busId: widget.busId,
        routeId: widget.routeId,
      ),
    );
  }
}

/// SOS confirmation and type selection dialog
class _SosDialog extends StatefulWidget {
  final String userId;
  final String userRole;
  final String? busId;
  final String? routeId;

  const _SosDialog({
    required this.userId,
    required this.userRole,
    this.busId,
    this.routeId,
  });

  @override
  State<_SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<_SosDialog> {
  final _sosQueries = SosQueries();
  final _descriptionController = TextEditingController();

  SosAlertType _selectedType = SosAlertType.emergency;
  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _sendAlert() async {
    setState(() => _isSending = true);

    // Get current location
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
    }

    final result = await _sosQueries.createAlert(
      userId: widget.userId,
      userRole: widget.userRole,
      busId: widget.busId,
      routeId: widget.routeId,
      lat: position?.latitude ?? 0,
      lng: position?.longitude ?? 0,
      alertType: _selectedType,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
    );

    if (mounted) {
      if (result != null) {
        setState(() {
          _isSending = false;
          _sent = true;
        });
        HapticFeedback.heavyImpact();
      } else {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send SOS. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 48, color: Colors.green.shade700),
            ),
            const SizedBox(height: 24),
            const Text(
              'SOS Sent!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Help is on the way. Stay calm.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sos, color: Colors.red),
          ),
          const SizedBox(width: 12),
          const Text('Emergency SOS'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select emergency type:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Alert type selection
            ...SosAlertType.values.map(
              (type) => RadioListTile<SosAlertType>(
                title: Text('${type.emoji} ${type.label}'),
                subtitle: Text(type.description),
                value: type,
                // ignore: deprecated_member_use
                groupValue: _selectedType,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  if (value != null) setState(() => _selectedType = value);
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),

            const SizedBox(height: 16),

            // Optional description
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Additional details (optional)',
                hintText: 'Describe the situation...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'False SOS alerts may result in action.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSending ? null : _sendAlert,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('SEND SOS'),
        ),
      ],
    );
  }
}

/// Admin view for SOS alerts
class SosAlertsScreen extends StatefulWidget {
  const SosAlertsScreen({super.key});

  @override
  State<SosAlertsScreen> createState() => _SosAlertsScreenState();
}

class _SosAlertsScreenState extends State<SosAlertsScreen> {
  final _sosQueries = SosQueries();
  List<SosAlertModel> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final alerts = await _sosQueries.getActiveAlerts();
    if (mounted) {
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Alerts'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAlerts),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No active alerts',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'All clear!',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                return _buildAlertCard(context, _alerts[index]);
              },
            ),
    );
  }

  Widget _buildAlertCard(BuildContext context, SosAlertModel alert) {
    final timeSince = DateTime.now().difference(alert.createdAt);
    final timeText = timeSince.inMinutes < 60
        ? '${timeSince.inMinutes}m ago'
        : '${timeSince.inHours}h ago';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: alert.status == SosStatus.active
          ? Colors.red.shade50
          : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert.alertType.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.alertType.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'From: ${alert.userName ?? 'Unknown'} (${alert.userRole})',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (alert.busName != null)
                        Text(
                          'Bus: ${alert.busName}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(alert.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        alert.status.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (alert.description != null) ...[
              const SizedBox(height: 12),
              Text(
                alert.description!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (alert.status == SosStatus.active)
                  TextButton(
                    onPressed: () => _acknowledgeAlert(alert),
                    child: const Text('Acknowledge'),
                  ),
                TextButton(
                  onPressed: () => _resolveAlert(alert, false),
                  child: const Text('Resolve'),
                ),
                TextButton(
                  onPressed: () => _resolveAlert(alert, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  child: const Text('False Alarm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SosStatus status) {
    switch (status) {
      case SosStatus.active:
        return Colors.red;
      case SosStatus.acknowledged:
        return Colors.orange;
      case SosStatus.responding:
        return Colors.blue;
      case SosStatus.resolved:
        return Colors.green;
      case SosStatus.falseAlarm:
        return Colors.grey;
    }
  }

  Future<void> _acknowledgeAlert(SosAlertModel alert) async {
    // Uses 'admin' as placeholder ID until auth system carries admin IDs
    final success = await _sosQueries.acknowledgeAlert(alert.id, 'admin');
    if (success && mounted) {
      _loadAlerts();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Alert acknowledged')));
    }
  }

  Future<void> _resolveAlert(SosAlertModel alert, bool isFalseAlarm) async {
    final success = await _sosQueries.resolveAlert(
      alert.id,
      isFalseAlarm: isFalseAlarm,
    );
    if (success && mounted) {
      _loadAlerts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFalseAlarm ? 'Marked as false alarm' : 'Alert resolved',
          ),
        ),
      );
    }
  }
}
