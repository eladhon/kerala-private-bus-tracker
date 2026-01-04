import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/bus_stop_model.dart';
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

  List<BusStopModel> _allStops = [];
  List<BusModel> _foundBuses = [];
  bool _isSearching = false;
  bool _hasSearched = false;

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
      final stops = await _queries.getAllBusStops();
      setState(() {
        _allStops = stops;
      });
    } catch (e) {
      debugPrint('Error loading stops: $e');
    }
  }

  Future<void> _findBuses() async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _foundBuses = []; // Clear previous results
    });

    try {
      // 1. Get all routes
      final routes = await _queries.getAllRoutes();
      final source = _sourceController.text.toLowerCase().trim();
      final dest = _destController.text.toLowerCase().trim();

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

      // 3. Get buses for matching routes
      List<BusModel> allBuses = [];
      for (var route in matchingRoutes) {
        final buses = await _queries.getBusesByRoute(route.id);
        allBuses.addAll(buses);
      }

      setState(() {
        _foundBuses = allBuses;
      });
    } catch (e) {
      debugPrint('Error finding buses: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _swapLocations() {
    final temp = _sourceController.text;
    _sourceController.text = _destController.text;
    _destController.text = temp;
  }

  void _onBusTap(BusModel bus) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BusTrackingScreen(bus: bus)),
    );
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
      backgroundColor: Colors.grey.shade50,
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
      child: const Text(
        'Route',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
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
              color: Colors.white,
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
                Divider(height: 1, color: Colors.grey.shade200, indent: 48),
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
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.swap_vert, color: Color(0xFF1B5E20)),
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
        // Use Autocomplete
        return Autocomplete<String>(
          initialValue: TextEditingValue(text: controller.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') {
              return const Iterable<String>.empty();
            }
            return _allStops
                .where(
                  (stop) => stop.name.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                )
                .map((stop) => stop.name);
          },
          onSelected: (String selection) {
            controller.text = selection;
          },
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                // Sync internal controller with external one if needed
                if (controller.text != textEditingController.text) {
                  textEditingController.text = controller.text;
                }

                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onChanged: (val) => controller.text = val, // Sync back
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(icon, color: Colors.grey.shade400),
                    suffixIcon: showGpsIcon
                        ? IconButton(
                            icon: const Icon(
                              Icons.my_location,
                              color: Color(0xFF1B5E20),
                            ),
                            onPressed: () async {
                              final hasPermission =
                                  await _checkLocationPermission();
                              if (hasPermission) {
                                try {
                                  // ignore: unused_local_variable
                                  final position =
                                      await Geolocator.getCurrentPosition(
                                        locationSettings:
                                            const LocationSettings(
                                              accuracy: LocationAccuracy.high,
                                            ),
                                      );
                                  // For now just set text, in real app we might want to geocode or use coords
                                  controller.text = "Current Location";
                                  // TODO: Reverse geocoding to get stop name if possible
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error getting location: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          )
                        : null,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: Colors.grey.shade200,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_bus,
                color: Color(0xFF1B5E20),
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
                      const SizedBox(width: 8),
                      // Text(
                      //   '•  Stop 3', // Example detail
                      //   style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      // ),
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
                // Text(
                //   '₹ 45', // Price
                //   style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                // ),
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
