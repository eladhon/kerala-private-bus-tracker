import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/route_model.dart';
import '../../models/stop_model.dart';
import '../../services/supabase_queries.dart';
import '../../services/routing_service.dart';

class RouteStopManagerScreen extends StatefulWidget {
  final RouteModel route;

  const RouteStopManagerScreen({super.key, required this.route});

  @override
  State<RouteStopManagerScreen> createState() => _RouteStopManagerScreenState();
}

class _RouteStopManagerScreenState extends State<RouteStopManagerScreen> {
  final _queries = SupabaseQueries();
  final _routingService = RoutingService();
  final MapController _mapController = MapController();

  // Local state
  List<StopModel> _stops = [];
  final List<String> _deletedStopIds = []; // IDs of stops to delete on save
  bool _hasUnsavedChanges = false;

  List<LatLng> _routePoints = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Selection / Adding state
  LatLng? _selectedLocation;
  StopModel? _editingStop; // If null, we are adding a new stop

  final _nameController = TextEditingController();
  final _orderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStops();
    _resetForm();
  }

  Future<void> _loadStops() async {
    setState(() => _isLoading = true);
    try {
      final updatedRoute = await _queries.getRouteById(widget.route.id);
      if (updatedRoute != null) {
        if (mounted) {
          setState(() {
            _stops = updatedRoute.busStops;
            _stops.sort(
              (a, b) => (a.orderIndex ?? 999).compareTo(b.orderIndex ?? 999),
            );
            _deletedStopIds.clear();
            _hasUnsavedChanges = false;
            // Preset order for next possible stop
            _orderController.text = '${_stops.length + 1}';
          });

          _updatePolyline();
          _fitBoundsToRoute();
        }
      }
    } catch (e) {
      debugPrint('Error loading stops: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePolyline() async {
    // Only fetch if we have enough stops
    if (_stops.length < 2) {
      setState(() => _routePoints = []);
      return;
    }

    // We should throttle this in a real app, but for now it's okay.
    // We are only calling this after local updates.
    final points = await _routingService.getRoutePolyline(_stops);
    if (mounted) {
      setState(() {
        _routePoints = points;
      });
    }
  }

  void _fitBoundsToRoute() {
    final boundsPoints = _routePoints.isNotEmpty
        ? _routePoints
        : _stops.map((s) => LatLng(s.lat, s.lng)).toList();

    if (boundsPoints.isNotEmpty) {
      try {
        final bounds = LatLngBounds.fromPoints(boundsPoints);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      } catch (e) {
        /* ignore bounds error if points too close */
      }
    } else {
      _mapController.move(const LatLng(10.0, 76.5), 8);
    }
  }

  void _resetForm() {
    setState(() {
      _editingStop = null;
      _selectedLocation = null;
      _nameController.clear();
      // Default to end of list
      _orderController.text = '${_stops.length + 1}';
    });
  }

  // --- SMART INSERT LOGIC ---

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _editingStop = null; // Ensure we are in "Add" mode
    });

    // Smart Insert: Calculate best index
    if (_stops.isNotEmpty) {
      final bestIndex = _calculateBestInsertionIndex(point);
      _orderController.text = (bestIndex + 1).toString(); // 1-based order
    } else {
      _orderController.text = '1';
    }
  }

  /// Calculates the best index to insert [point] into [_stops]
  /// by creating the minimal detour distance.
  int _calculateBestInsertionIndex(LatLng point) {
    if (_stops.isEmpty) return 0;
    if (_stops.length == 1) {
      // Before or after based on... well, just distance? usually after.
      return 1;
    }

    double minDetour = double.infinity;
    int bestIndex = _stops.length; // Default to end

    final Distance dist = const Distance();

    // Check detour for inserting between i and i+1
    // Detour = dist(stop[i], P) + dist(P, stop[i+1]) - dist(stop[i], stop[i+1])
    for (int i = 0; i < _stops.length - 1; i++) {
      final LatLng s1 = LatLng(_stops[i].lat, _stops[i].lng);
      final LatLng s2 = LatLng(_stops[i + 1].lat, _stops[i + 1].lng);

      final currentDist = dist.as(LengthUnit.Meter, s1, s2);
      final newDist =
          dist.as(LengthUnit.Meter, s1, point) +
          dist.as(LengthUnit.Meter, point, s2);

      final detour = newDist - currentDist;

      if (detour < minDetour) {
        minDetour = detour;
        bestIndex = i + 1;
      }
    }

    // Also check beginning and end?
    // Cost to add at start = dist(P, Start)
    // Cost to add at end = dist(End, P)
    // But we are comparing "detour" vs "extension".
    // Usually "detour" is small if it's on the line.
    // If point is far away, it might be an extension.
    // For simplicity, let's strictly check "between" segments first.
    // If the point is "projected" onto a segment, detour is ~0.

    return bestIndex;
  }

  // --- BATCH LOCAL UPDATES ---

  void _onLocalSaveStop() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a stop name')));
      return;
    }
    if (_selectedLocation == null && _editingStop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap on the map select location')),
      );
      return;
    }

    final String name = _nameController.text;
    final int order =
        int.tryParse(_orderController.text) ?? (_stops.length + 1);
    final double lat = _selectedLocation?.latitude ?? _editingStop!.lat;
    final double lng = _selectedLocation?.longitude ?? _editingStop!.lng;

    setState(() {
      if (_editingStop == null) {
        // CREATE NEW
        // Shift existing stops if we are inserting in middle
        // If order <= stops.length, we need to shift everyone >= order up by 1
        // We do this by simply assigning the new order and then re-sorting / re-assigning?
        // Let's just insert at the list? No, order property is key.

        // Strategy: Insert into list, then re-normalize all orders.
        final newStop = StopModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}', // Temp ID
          name: name,
          lat: lat,
          lng: lng,
          orderIndex: order,
        );

        _stops.add(newStop);
      } else {
        // UPDATE EXISTING
        final index = _stops.indexWhere((s) => s.id == _editingStop!.id);
        if (index != -1) {
          _stops[index] = _editingStop!.copyWith(
            name: name,
            lat: lat,
            lng: lng,
            orderIndex: order,
          );
        }
      }

      // Re-normalize orders
      _stops.sort(
        (a, b) => (a.orderIndex ?? 999).compareTo(b.orderIndex ?? 999),
      );

      // If we inserted, we might have duplicates or gaps.
      // The user wants "update order number of next stops increment".
      // Let's strictly enforce 1..N order
      for (int i = 0; i < _stops.length; i++) {
        // If user manually set order X, we respected sort.
        // Now just overwrite with 1..N to be clean?
        // Or keep gaps? User "insert order number as a whole" request implies strict ordering.
        // Let's re-assign i+1 to be safe and clean.
        _stops[i] = _stops[i].copyWith(orderIndex: i + 1);
      }

      _hasUnsavedChanges = true;
      _resetForm();
    });

    _updatePolyline();
  }

  void _onLocalDeleteStop(StopModel stop) {
    setState(() {
      _stops.removeWhere((s) => s.id == stop.id);
      if (!stop.id.startsWith('temp_')) {
        _deletedStopIds.add(stop.id);
      }

      // Re-normalize orders
      for (int i = 0; i < _stops.length; i++) {
        _stops[i] = _stops[i].copyWith(orderIndex: i + 1);
      }

      _hasUnsavedChanges = true;
      if (_editingStop?.id == stop.id) {
        _resetForm();
      }
    });
    _updatePolyline();
  }

  // --- SAVE TO DB ---

  Future<void> _saveAllChanges() async {
    setState(() => _isSaving = true);
    try {
      // 1. Delete removed stops
      for (final id in _deletedStopIds) {
        await _queries.deleteBusStop(id, widget.route.id);
      }
      _deletedStopIds.clear();

      // 2. Upsert current stops
      for (final stop in _stops) {
        if (stop.id.startsWith('temp_')) {
          // Create
          await _queries.createBusStop(
            name: stop.name,
            latitude: stop.lat,
            longitude: stop.lng,
            routeId: widget.route.id,
            orderIndex: stop.orderIndex,
          );
        } else {
          // Update
          await _queries.updateBusStop(stop.id, {
            'name': stop.name,
            'latitude': stop.lat,
            'longitude': stop.lng,
            'order_index': stop.orderIndex,
            'route_id': widget.route.id,
          });
        }
      }

      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All changes saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload to get fresh IDs for temp items
      _loadStops();
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onEditClick(StopModel stop) {
    setState(() {
      _editingStop = stop;
      _selectedLocation = LatLng(stop.lat, stop.lng);
      _nameController.text = stop.name;
      _orderController.text = stop.orderIndex?.toString() ?? '';

      _mapController.move(LatLng(stop.lat, stop.lng), 15);
    });
  }

  @override
  Widget build(BuildContext context) {
    // HORIZONTAL LAYOUT: ROW
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Route Manager: ${widget.route.name}${_hasUnsavedChanges ? " (Unsaved Changes)" : ""}',
        ),
        backgroundColor: _hasUnsavedChanges
            ? Colors.orange.shade800
            : const Color(0xFF1a237e),
        foregroundColor: Colors.white,
        actions: [
          if (_hasUnsavedChanges)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAllChanges,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('SAVE CHANGES'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT: MAP (Flex 2 or 3)
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(10.0, 76.5),
                    initialZoom: 9,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.keralab.bustracker',
                    ),
                    if (_routePoints.isNotEmpty || _stops.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints.isNotEmpty
                                ? _routePoints
                                : _stops
                                      .map((e) => LatLng(e.lat, e.lng))
                                      .toList(),
                            color: Colors.blue.withOpacity(0.7),
                            strokeWidth: 4,
                          ),
                        ],
                      ),

                    MarkerLayer(
                      markers: _stops
                          .map((stop) {
                            final isEditing = _editingStop?.id == stop.id;
                            if (isEditing) {
                              return const Marker(
                                point: LatLng(0, 0),
                                width: 0,
                                height: 0,
                                child: SizedBox.shrink(),
                              );
                            }
                            return Marker(
                              point: LatLng(stop.lat, stop.lng),
                              width: 30,
                              height: 30,
                              child: InkWell(
                                onTap: () => _onEditClick(stop),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    stop.orderIndex?.toString() ?? '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .where((m) => m.width > 0)
                          .toList(),
                    ),

                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                final camera = _mapController.camera;
                                final offset = camera.latLngToScreenOffset(
                                  _selectedLocation!,
                                );
                                final newOffset = offset + details.delta;
                                final newLatLng = camera.screenOffsetToLatLng(
                                  newOffset,
                                );
                                setState(() => _selectedLocation = newLatLng);
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                  Positioned(
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Move',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Helper overlay
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(blurRadius: 4, color: Colors.black26),
                      ],
                    ),
                    child: Text(
                      _editingStop != null
                          ? 'Editing Stop #${_editingStop!.orderIndex}: "${_editingStop!.name}"'
                          : 'Tap on route to insert new stop',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // RIGHT: DETAILS (Flex 2)
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  // Form Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _editingStop == null ? 'New Stop' : 'Edit Stop',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Stop Name',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Order is auto-managed but editable
                        TextField(
                          controller: _orderController,
                          decoration: const InputDecoration(
                            labelText: 'Order (Auto-calc)',
                            isDense: true,
                            border: OutlineInputBorder(),
                            helperText: 'Will auto-shift subsequent stops',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _onLocalSaveStop,
                                icon: const Icon(Icons.check),
                                label: Text(
                                  _editingStop == null
                                      ? 'Insert Stop'
                                      : 'Update Stop',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1a237e),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            if (_editingStop != null) ...[
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _resetForm,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.all(0),
                            itemCount: _stops.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }
                                final item = _stops.removeAt(oldIndex);
                                _stops.insert(newIndex, item);

                                // Renormalize orders
                                for (int i = 0; i < _stops.length; i++) {
                                  _stops[i] = _stops[i].copyWith(
                                    orderIndex: i + 1,
                                  );
                                }
                                _hasUnsavedChanges = true;
                              });
                              _updatePolyline();
                            },
                            itemBuilder: (context, index) {
                              final stop = _stops[index];
                              final isSelected = _editingStop?.id == stop.id;
                              return ListTile(
                                key: ValueKey(stop.id),
                                selected: isSelected,
                                selectedTileColor: Colors.blue.withOpacity(0.1),
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isSelected
                                      ? Colors.orange
                                      : Colors.grey.shade300,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                title: Text(stop.name),
                                subtitle: Text(
                                  '${stop.lat.toStringAsFixed(4)}, ${stop.lng.toStringAsFixed(4)}',
                                ),
                                dense: true,
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () => _onLocalDeleteStop(stop),
                                ),
                                onTap: () => _onEditClick(stop),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
