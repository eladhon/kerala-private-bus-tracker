import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/stop_model.dart';
import '../../models/route_model.dart';
import 'bus_tracking_screen.dart';

/// Route search screen with source/destination inputs and bus results
class RouteSearchScreen extends StatefulWidget {
  final String initialQuery;

  const RouteSearchScreen({super.key, required this.initialQuery});

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final _queries = SupabaseQueries();
  final _sourceController = TextEditingController();
  final _destController = TextEditingController();

  List<StopModel> _allStops = [];
  List<BusModel> _foundBuses = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isResolvingLocation = false;

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
        _allStops = uniqueStops.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      });
    } catch (e) {
      debugPrint('Error loading stops: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load bus stops: $e')));
      }
    }
  }

  Future<void> _findBuses() async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _foundBuses = []; // Clear previous results
    });

    try {
      // DEBUG: Check if we can see ANY buses at all
      final allBusesDebug = await _queries.getAllBuses();
      debugPrint('DEBUG: Global bus count: ${allBusesDebug.length}');
      if (allBusesDebug.isNotEmpty) {
        debugPrint('DEBUG: First bus route_id: ${allBusesDebug.first.routeId}');
        debugPrint('DEBUG: First bus ID: ${allBusesDebug.first.id}');
      } else {
        debugPrint(
          'DEBUG: No buses visible globally. Likely RLS or empty table.',
        );
      }

      // 1. Get all routes
      final routes = await _queries.getAllRoutes();
      final source = _sourceController.text.toLowerCase().trim();
      final dest = _destController.text.toLowerCase().trim();

      debugPrint('Total routes loaded: ${routes.length}');

      // 2. Filter routes that match source and/or destination
      // Ideally this should be backend logic, but doing client-side for now
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

      // 3. Get buses for matching routes
      List<BusModel> allBuses = [];
      for (var route in matchingRoutes) {
        debugPrint('Checking buses for route: ${route.name} (${route.id})');
        final buses = await _queries.getBusesByRoute(route.id);
        allBuses.addAll(buses);
      }

      debugPrint('Found buses: ${allBuses.length}');
      if (mounted && matchingRoutes.isNotEmpty && allBuses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${matchingRoutes.length} routes, but no buses assigned to them.',
            ),
          ),
        );
      }

      setState(() {
        _foundBuses = allBuses;
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
    });
  }

  void _onBusTap(BusModel bus) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusTrackingScreen(
          bus: bus,
          userSourceStop: _sourceController.text.isNotEmpty
              ? _sourceController.text
              : null,
          userDestStop: _destController.text.isNotEmpty
              ? _destController.text
              : null,
        ),
      ),
    );
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
      setState(() => _isResolvingLocation = true);
      try {
        // Geocoding
        final locations = await locationFromAddress(query);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          // Find nearest stop to this location
          final stops = await _queries.getNearestBusStops(
            loc.latitude,
            loc.longitude,
            limit: 1,
          );
          if (stops.isNotEmpty && mounted) {
            controller.text = stops.first.name;
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("No bus stops found near '$query'")),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not find location '$query'")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Geocoding failed: $e")));
        }
      } finally {
        if (mounted) setState(() => _isResolvingLocation = false);
      }
      return;
    }

    // 3. Regular stop selection
    controller.text = selection;
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
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
            child: InkWell(
              onTap: _swapLocations,
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
                      color: Colors.black.withValues(alpha: 0.05),
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

    if (_hasSearched && _foundBuses.isEmpty) {
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
      itemCount: _foundBuses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final bus = _foundBuses[index];
        return _buildBusListItem(bus);
      },
    );
  }

  Widget _buildBusListItem(BusModel bus) {
    // Determine bus type/badge (Randomly for demo if not in model, or check data)
    final isKSRTC = bus.name.toUpperCase().contains('KSRTC');
    final badgeColor = isKSRTC ? Colors.orange.shade100 : Colors.blue.shade100;
    final badgeTextColor = isKSRTC
        ? Colors.orange.shade800
        : Colors.blue.shade800;
    final badgeText = isKSRTC ? 'KSRTC' : 'Private';

    // Status (Mock logic)
    final status = 'Arriving'; // In real app, calculate from live data
    final time = '10:30 AM'; // Schedule time

    return InkWell(
      onTap: () => _onBusTap(bus),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
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
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}
