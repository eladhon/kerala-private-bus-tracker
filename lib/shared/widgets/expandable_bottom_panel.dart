/// Reusable expandable bottom panel widget
///
/// Consolidates bottom panel UI from bus_tracking_screen.dart
/// and conductor_home_screen.dart
library;

import 'package:flutter/material.dart';

/// Expandable bottom panel with swipe gestures
class ExpandableBottomPanel extends StatefulWidget {
  /// Header widget shown when collapsed
  final Widget header;

  /// Content shown when expanded
  final Widget expandedContent;

  /// Initially expanded state
  final bool initiallyExpanded;

  /// Callback when expansion state changes
  final ValueChanged<bool>? onExpandChanged;

  /// Background color (defaults to theme surface)
  final Color? backgroundColor;

  /// Border radius for top corners
  final double borderRadius;

  /// Show drag handle indicator
  final bool showHandle;

  const ExpandableBottomPanel({
    super.key,
    required this.header,
    required this.expandedContent,
    this.initiallyExpanded = true,
    this.onExpandChanged,
    this.backgroundColor,
    this.borderRadius = 24,
    this.showHandle = true,
  });

  @override
  State<ExpandableBottomPanel> createState() => _ExpandableBottomPanelState();
}

class _ExpandableBottomPanelState extends State<ExpandableBottomPanel> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpandChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          // Swipe Up -> Expand
          if (!_isExpanded) _toggle();
        } else if (details.primaryVelocity! > 0) {
          // Swipe Down -> Collapse
          if (_isExpanded) _toggle();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(widget.borderRadius),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            if (widget.showHandle)
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
            if (widget.showHandle) const SizedBox(height: 16),

            // Header (tappable to toggle)
            InkWell(
              onTap: _toggle,
              child: Row(
                children: [
                  Expanded(child: widget.header),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),

            // Expandable content
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        widget.expandedContent,
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header widget for bus info panels
class BusPanelHeader extends StatelessWidget {
  final String busName;
  final String? subtitle;
  final IconData icon;
  final Color? iconBackgroundColor;
  final Widget? trailing;

  const BusPanelHeader({
    super.key,
    required this.busName,
    this.subtitle,
    this.icon = Icons.directions_bus,
    this.iconBackgroundColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconBackgroundColor ?? colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 32, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                busName,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
