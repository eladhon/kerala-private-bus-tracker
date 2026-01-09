/// Delay Reporting Dialog for Conductors
///
/// Allows conductors to report bus delays with reason and duration.
library;

import 'package:flutter/material.dart';
import '../../../models/delay_report_model.dart';
import '../../../services/queries/delay_queries.dart';

/// Dialog for reporting bus delays
class DelayReportDialog extends StatefulWidget {
  final String busId;
  final String? routeId;
  final String conductorId;
  final VoidCallback? onReported;

  const DelayReportDialog({
    super.key,
    required this.busId,
    this.routeId,
    required this.conductorId,
    this.onReported,
  });

  /// Show the delay report dialog
  static Future<void> show(
    BuildContext context, {
    required String busId,
    String? routeId,
    required String conductorId,
    VoidCallback? onReported,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DelayReportDialog(
        busId: busId,
        routeId: routeId,
        conductorId: conductorId,
        onReported: onReported,
      ),
    );
  }

  @override
  State<DelayReportDialog> createState() => _DelayReportDialogState();
}

class _DelayReportDialogState extends State<DelayReportDialog> {
  final _delayQueries = DelayQueries();
  final _notesController = TextEditingController();

  DelayReason _selectedReason = DelayReason.traffic;
  int _delayMinutes = 15;
  bool _isSubmitting = false;

  final List<int> _delayOptions = [5, 10, 15, 20, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitDelay() async {
    setState(() => _isSubmitting = true);

    final result = await _delayQueries.reportDelay(
      busId: widget.busId,
      routeId: widget.routeId,
      delayMinutes: _delayMinutes,
      reason: _selectedReason,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      reportedBy: widget.conductorId,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (result != null) {
        widget.onReported?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delay reported: ${result.formattedDelay}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to report delay'),
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
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Report Delay',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Delay Duration
            Text(
              'Delay Duration',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _delayOptions.map((mins) {
                final isSelected = _delayMinutes == mins;
                return ChoiceChip(
                  label: Text(_formatMinutes(mins)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _delayMinutes = mins);
                    }
                  },
                  selectedColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Reason
            Text(
              'Reason',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DelayReason.values.map((reason) {
                final isSelected = _selectedReason == reason;
                return ChoiceChip(
                  label: Text('${reason.emoji} ${reason.label}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedReason = reason);
                    }
                  },
                  selectedColor: colorScheme.secondaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Notes (optional)
            Text(
              'Additional Notes (optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'E.g., Heavy traffic near MG Road...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitDelay,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Report ${_formatMinutes(_delayMinutes)} Delay',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int mins) {
    if (mins < 60) {
      return '$mins min';
    } else {
      final hours = mins ~/ 60;
      final remaining = mins % 60;
      return remaining > 0 ? '$hours hr ${remaining}m' : '$hours hr';
    }
  }
}

/// Widget to display active delay on bus tracking screen
class ActiveDelayBadge extends StatelessWidget {
  final DelayReportModel delay;
  final VoidCallback? onTap;

  const ActiveDelayBadge({super.key, required this.delay, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Text(
              delay.formattedDelay,
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${delay.reason.label})',
              style: TextStyle(color: Colors.orange.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
