import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/stop_model.dart';
import '../../models/route_model.dart';
import '../../shared/services/location_service.dart';
import 'bus_tracking_screen.dart';

/// Route search screen with source/destination inputs and bus results
class RouteSearchScreen extends StatefulWidget {
  final String initialQuery;
  final String? currentUserId; // Manual user ID passing

  const RouteSearchScreen({
    super.key,
    required this.initialQuery,
    this.currentUserId,
  });

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final _queries = SupabaseQueries();
  final _sourceController = TextEditingController();
  final _destController = TextEditingController();

  final _allStops = <StopModel>[];
  final _routesMap = <String, RouteModel>{};

  // Refactored to store search results explicitly
  List<BusSearchResult> _searchResults = [];
  bool _hasSearched = false;
  bool _isSearching = false;
  bool _isResolvingLocation = false;
  LatLng? _sourceLatLng;
  LatLng? _destLatLng;

  @override
  void initState() {
    super.initState();
    _loadStops();
    if (widget.initialQuery.isNotEmpty) {
      _destController.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    super.dispose();
  }

  Future<void> _loadStops() async {
    try {
      // Load both standalone stops and stops embedded in routes
      // This ensures autocomplete works even if stops are only in the JSONB column of routes
      final results = await Future.wait([
        _queries.getAllBusStops(),
        _queries.getAllRoutes(),
      ]);

      final stops = results[0] as List<StopModel>;
      final routes = results[1] as List<RouteModel>;

      // Create a map to deduplicate by name (case-insensitive)
      final Map<String, StopModel> uniqueStops = {};

      // Add standalone stops first
      for (var stop in stops) {
        uniqueStops[stop.name.toLowerCase()] = stop;
      }

      // Add stops from routes (extracted from valid RouteModel which now parses JSONB)
      for (var route in routes) {
        for (var stop in route.busStops) {
          if (!uniqueStops.containsKey(stop.name.toLowerCase())) {
            uniqueStops[stop.name.toLowerCase()] = stop;
          }
        }
      }

      setState(() {
        _routesMap.clear();
        _routesMap.addAll({for (var r in routes) r.id: r});
        _allStops.clear();
        _allStops.addAll(
          uniqueStops.values.toList()..sort((a, b) => a.name.compareTo(b.name)),
        );
      });

      // After stops are loaded, check if initial query needs resolution
      if (widget.initialQuery.isNotEmpty) {
        _resolveInitialQuery();
      }
    } catch (e) {
      debugPrint('Error loading stops: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load bus stops: $e')));
      }
    }
  }

  Future<void> _resolveInitialQuery() async {
    final query = widget.initialQuery;
    // Check if it's already a valid stop
    final isStop = _allStops.any(
      (s) => s.name.toLowerCase() == query.toLowerCase(),
    );

    if (!isStop) {
      // It's a landmark/address, try to resolve it
      debugPrint('Resolving initial query landmark: $query');
      await _resolveLocationToNearestStop(query, _destController);
    }
  }

  Future<void> _findBuses() async {
    // 0. Auto-resolve raw inputs if they are not known stops
    if (_sourceController.text.isNotEmpty &&
        !_isKnownStop(_sourceController.text)) {
      final success = await _resolveLocationToNearestStop(
        _sourceController.text,
        _sourceController,
      );
      if (!success) return; // Stop if resolution failed
    }

    if (_destController.text.isNotEmpty &&
        !_isKnownStop(_destController.text)) {
      final success = await _resolveLocationToNearestStop(
        _destController.text,
        _destController,
      );
      if (!success) return; // Stop if resolution failed
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResults = []; // Clear previous results
    });

    try {
      final source = _sourceController.text.trim().toLowerCase();
      final dest = _destController.text.trim().toLowerCase();

      // 1. Fetch all routes
      final routes = await _queries.getAllRoutes();

      debugPrint('Total routes loaded: ${routes.length}');

      // 2. Filter routes
      final matchingRoutes = routes.where((route) {
        final start = route.startLocation.toLowerCase();
        final end = route.endLocation.toLowerCase();

        // Exact match logic or partial match
        bool matchSource =
            source.isEmpty ||
            start.contains(source) ||
            route.busStops.any((s) => s.name.toLowerCase().contains(source));
        bool matchDest =
            dest.isEmpty ||
            end.contains(dest) ||
            route.busStops.any((s) => s.name.toLowerCase().contains(dest));

        return matchSource && matchDest;
      }).toList();

      debugPrint('Matching routes: ${matchingRoutes.length}');
      if (mounted && matchingRoutes.isEmpty) {
        // Optional: Feedback for no routes found matching criteria
        debugPrint('No routes match the criteria: Source=$source, Dest=$dest');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No routes found matching "$source" to "$dest"'),
          ),
        );
      }

      // 3. Get buses and generate results
      List<BusSearchResult> results = [];

      for (var route in matchingRoutes) {
        final buses = await _queries.getBusesByRoute(route.id);

        for (var bus in buses) {
          // A. Check Schedule matches
          if (bus.schedule.isNotEmpty) {
            for (var scheduleItem in bus.schedule) {
              // Check if this schedule item corresponds to the requested route
              // Or ANY matching route (e.g. return trip)
              if (scheduleItem.routeId == route.id) {
                results.add(
                  BusSearchResult(
                    bus: bus,
                    departureTime: scheduleItem.departureTime,
                    routeId: route.id,
                  ),
                );
              }
            }
          }

          // B. Legacy/Primary Route Check
          // Only if this route is the primary route AND no schedule for it was found?
          // Or just treat primary as another entry if it matches?
          if (bus.routeId == route.id) {
            // Avoid duplicating if we covered it in schedule (if needed)
            // For now, assume if schedule exists, it supersedes primary route
            // UNLESS primary route is not in schedule.
            // Simplification: Just add it if no schedule matches found for this route
            // (Assuming migration to schedule-only eventually)
            bool alreadyAdded = results.any(
              (r) =>
                  r.bus.id == bus.id &&
                  r.routeId == route.id &&
                  r.departureTime == (bus.departureTime ?? 'Scheduled'),
            );

            if (!alreadyAdded) {
              results.add(
                BusSearchResult(
                  bus: bus,
                  departureTime: bus.departureTime ?? 'Scheduled',
                  routeId: route.id,
                ),
              );
            }
          }
        }
      }

      // Sort results by time?
      results.sort((a, b) {
        // Simple string comparison for HH:MM works for today
        return a.departureTime.compareTo(b.departureTime);
      });

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint('Error finding buses: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error finding buses: $e')));
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _swapLocations() {
    setState(() {
      final temp = _sourceController.text;
      _sourceController.text = _destController.text;
      _destController.text = temp;

      final tempLatLng = _sourceLatLng;
      _sourceLatLng = _destLatLng;
      _destLatLng = tempLatLng;
    });
  }

  void _onBusTap(BusModel bus, String routeId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusTrackingScreen(
          bus: bus,
          currentUserId: widget.currentUserId,
          selectedRouteId: routeId,
          userSourceStop: _sourceController.text.trim().isNotEmpty
              ? _sourceController.text.trim()
              : null,
          userDestStop: _destController.text.trim().isNotEmpty
              ? _destController.text.trim()
              : null,
          userSourceLatLng: _sourceLatLng,
          userDestLatLng: _destLatLng,
        ),
      ),
    );
  }

  bool _isKnownStop(String query) {
    if (_allStops.isEmpty) return false;
    final lower = query.toLowerCase().trim();
    return _allStops.any((s) => s.name.toLowerCase() == lower);
  }

  Future<bool> _resolveLocationToNearestStop(
    String query,
    TextEditingController controller,
  ) async {
    setState(() => _isResolvingLocation = true);
    try {
      // Use Nominatim OpenStreetMap API (Same as Admin Panel)
      // This is more reliable for local landmarks in Kerala than the native geocoding package
      debugPrint("Geocoding address via Nominatim: $query");

      LatLng? foundLocation;

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
        );
        final response = await http.get(
          url,
          headers: {'User-Agent': 'KeralaBusTrackerUser/1.0 (internal)'},
        );

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          if (data.isNotEmpty) {
            final firstResult = data[0];
            final double lat = double.parse(firstResult['lat']);
            final double lng = double.parse(firstResult['lon']);
            foundLocation = LatLng(lat, lng);
            debugPrint("Nominatim found: $lat, $lng");
          }
        }
      } catch (e) {
        debugPrint("Nominatim error: $e");
      }

      if (foundLocation != null) {
        if (controller == _sourceController) {
          _sourceLatLng = foundLocation;
        } else {
          _destLatLng = foundLocation;
        }

        // Find nearest stop to this location
        final stops = await _queries.getNearestBusStops(
          foundLocation.latitude,
          foundLocation.longitude,
          limit: 1,
        );
        if (stops.isNotEmpty) {
          if (mounted) controller.text = stops.first.name;
          // Don't show snackbar here during auto-resolve to avoid spam,
          // OR show it to confirm what happened.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Resolved '$query' to nearest stop: ${stops.first.name}",
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return true;
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No bus stops found near '$query'")),
          );
          return false;
        }
      } else if (mounted) {
        // Fallback/Error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not find location '$query'")),
        );
        return false;
      }
      return false;
    } catch (e) {
      if (mounted) {
        debugPrint("Resolution failed for '$query': $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location resolution failed")),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isResolvingLocation = false);
    }
  }

  Future<void> _handleLocationSelection(
    String selection,
    TextEditingController controller,
  ) async {
    // 1. Check for "Use Current Location"
    if (selection == 'Use Current Location') {
      setState(() => _isResolvingLocation = true);
      try {
        final hasPermission = await _checkLocationPermission();
        if (!hasPermission) return;

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );

        final foundLocation = LatLng(position.latitude, position.longitude);
        if (controller == _sourceController) {
          _sourceLatLng = foundLocation;
        } else {
          _destLatLng = foundLocation;
        }

        // Find nearest stop
        final stops = await _queries.getNearestBusStops(
          position.latitude,
          position.longitude,
          limit: 1,
        );
        if (stops.isNotEmpty && mounted) {
          controller.text = stops.first.name;
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No bus stops found near you')),
          );
          // Fallback to coordinates? No, need stop name for routing.
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isResolvingLocation = false);
      }
      return; // Done
    }

    // 2. Check for "Search for '...'"
    if (selection.startsWith('Search for: ')) {
      final query = selection
          .replaceFirst('Search for: ', '')
          .replaceAll("'", "");
      await _resolveLocationToNearestStop(query, controller);
      return;
    }

    // 3. Regular stop selection
    controller.text = selection;
  }

  Future<bool> _checkLocationPermission() async {
    final status = await LocationService().requestPermission();
    if (status == LocationPermissionStatus.serviceDisabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return false;
    }
    if (status == LocationPermissionStatus.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
      }
      return false;
    }
    if (status == LocationPermissionStatus.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied, we cannot request permissions.',
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background handled by theme
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildInputSection(),
            _buildActionButton(),
            Expanded(child: _buildResultsArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        'Route',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildAutocompleteField(
                  controller: _sourceController,
                  hint: 'Source stop',
                  icon: Icons.search,
                  isTop: true,
                  showGpsIcon: true,
                ),
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                  indent: 48,
                  endIndent: 0,
                ),
                _buildAutocompleteField(
                  controller: _destController,
                  hint: 'Destination stop',
                  icon: Icons.location_on_outlined,
                  isTop: false,
                ),
              ],
            ),
          ),
          Positioned(
            right: 24,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _swapLocations,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.swap_vert,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isTop,
    bool showGpsIcon = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: FocusNode(),
          optionsBuilder: (TextEditingValue textEditingValue) {
            final query = textEditingValue.text;
            // Base stops list
            final stops = _allStops
                .where(
                  (stop) =>
                      stop.name.toLowerCase().contains(query.toLowerCase()),
                )
                .map((stop) => stop.name);

            // Special Options
            final List<String> options = [];

            // 1. "Use Current Location" always at top if query is empty or partially matching "current"
            if (query.isEmpty ||
                'use current location'.contains(query.toLowerCase())) {
              options.add('Use Current Location');
            }

            // 2. Bus stops
            options.addAll(stops);

            // 3. Landmark search option (if query is not empty and not matching a stop perfectly)
            if (query.isNotEmpty) {
              // Verify it's not already an exact match
              final exactMatch = _allStops.any(
                (s) => s.name.toLowerCase() == query.toLowerCase(),
              );
              if (!exactMatch) {
                options.add("Search for: '$query'");
              }
            }

            return options;
          },
          onSelected: (String selection) {
            _handleLocationSelection(selection, controller);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: 250.0, // Taller for more options
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);

                      // Custom styling for special options
                      if (option == 'Use Current Location') {
                        return ListTile(
                          leading: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                          ),
                          title: const Text(
                            'Use Current Location',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () => onSelected(option),
                        );
                      }

                      if (option.startsWith('Search for: ')) {
                        return ListTile(
                          leading: const Icon(
                            Icons.search,
                            color: Colors.orange,
                          ),
                          title: Text(
                            option,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                          onTap: () => onSelected(option),
                        );
                      }

                      return ListTile(
                        leading: const Icon(
                          Icons.directions_bus,
                          size: 20,
                          color: Colors.grey,
                        ),
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onSubmitted: (_) => onFieldSubmitted(),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon:
                        _isResolvingLocation &&
                            textEditingController == controller
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Icon(icon, color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                );
              },
        );
      },
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isSearching ? null : _findBuses,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: _isSearching
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Find buses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_isSearching) {
      // Skeleton loader (simplified)
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      );
    }

    if (_hasSearched && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No buses found',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Text(
          'Enter source and destination to find buses',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildBusResultItem(result);
      },
    );
  }

  Widget _buildBusResultItem(BusSearchResult result) {
    final bus = result.bus;
    // Determine bus type/badge (Randomly for demo if not in model, or check data)
    final isKSRTC = bus.name.toUpperCase().contains('KSRTC');
    final badgeColor = isKSRTC ? Colors.orange.shade100 : Colors.blue.shade100;
    final badgeTextColor = isKSRTC
        ? Colors.orange.shade900
        : Colors.blue.shade900;
    final badgeText = isKSRTC ? 'KSRTC' : 'Private';

    // Status logic
    final isOnline = bus.isAvailable; // Use real status field
    final status = isOnline ? 'Live Now' : 'Scheduled';

    // Calculate dynamic time based on specific schedule/route
    String time = 'Check Times';
    final route = _routesMap[result.routeId];

    if (route != null) {
      final sourceName = _sourceController.text.trim();
      if (sourceName.isNotEmpty) {
        try {
          final stop = route.busStops.firstWhere(
            (s) => s.name.toLowerCase() == sourceName.toLowerCase(),
          );

          try {
            final parts = result.departureTime.split(':');
            if (parts.length == 2) {
              final baseTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
              final minutesFromStart = stop.minutesFromStart ?? 0;
              final totalMinutes =
                  (baseTime.hour * 60) + baseTime.minute + minutesFromStart;

              final arrivalHour = (totalMinutes ~/ 60) % 24;
              final arrivalMinute = totalMinutes % 60;
              final arrivalTime = TimeOfDay(
                hour: arrivalHour,
                minute: arrivalMinute,
              );

              time = arrivalTime.format(context);
            } else {
              time = result.departureTime;
            }
          } catch (e) {
            time = result.departureTime;
          }
        } catch (_) {
          time = result.departureTime;
        }
      } else {
        time = result.departureTime;
      }
    } else {
      time = result.departureTime;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onBusTap(bus, result.routeId),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            bus.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            status,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Departs: ${result.departureTime}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BusSearchResult {
  final BusModel bus;
  final String departureTime;
  final String routeId;

  BusSearchResult({
    required this.bus,
    required this.departureTime,
    required this.routeId,
  });
}
