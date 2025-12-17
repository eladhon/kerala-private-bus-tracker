import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../widgets/bus_card.dart';
import 'bus_tracking_screen.dart';
import 'route_search_screen.dart';
import '../auth/login_screen.dart';

/// User home screen with quick picks and bus list
class UserHomeScreen extends StatefulWidget {
  final String phoneNumber;

  const UserHomeScreen({super.key, required this.phoneNumber});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final _queries = SupabaseQueries();
  List<BusModel> _availableBuses = [];
  // ignore: unused_field - used for future enhancements
  List<RouteModel> _popularRoutes = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  // Quick pick routes for Kerala
  final List<Map<String, String>> _quickPicks = [
    {'name': 'Thrissur-Guruvayur', 'start': 'Thrissur', 'end': 'Guruvayur'},
    {'name': 'Kochi-Tripunithura', 'start': 'Kochi', 'end': 'Tripunithura'},
    {'name': 'Trivandrum-Kovalam', 'start': 'Trivandrum', 'end': 'Kovalam'},
    {'name': 'Calicut-Wayanad', 'start': 'Calicut', 'end': 'Wayanad'},
    {'name': 'Palakkad-Coimbatore', 'start': 'Palakkad', 'end': 'Coimbatore'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final buses = await _queries.getAvailableBuses();
      final routes = await _queries.getPopularRoutes();
      setState(() {
        _availableBuses = buses;
        _popularRoutes = routes;
      });
    } catch (e) {
      // Handle error silently for demo
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onQuickPickTap(Map<String, String> route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteSearchScreen(initialQuery: route['name']!),
      ),
    );
  }

  void _onBusTap(BusModel bus) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BusTrackingScreen(bus: bus)),
    );
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF1B5E20),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return RouteSearchScreen(initialQuery: '');
      case 2:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 140,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF1B5E20),
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              'Kerala Bus Tracker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 50),
                  child: Text(
                    '🚌 Track buses live',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Quick Picks Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flash_on, color: Color(0xFFFFC107)),
                    SizedBox(width: 8),
                    Text(
                      'Quick Picks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickPicks.length,
                    itemBuilder: (context, index) {
                      final route = _quickPicks[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(route['name']!),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF1B5E20)),
                          onPressed: () => _onQuickPickTap(route),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Map Preview
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: const LatLng(
                        10.8505,
                        76.2711,
                      ), // Kerala center
                      initialZoom: 7,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.keralab.bustracker',
                      ),
                      // Show user's current location
                      CurrentLocationLayer(
                        style: LocationMarkerStyle(
                          marker: const DefaultLocationMarker(
                            color: Colors.blue,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          markerSize: const Size(24, 24),
                          accuracyCircleColor: Colors.blue.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Available Buses Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Buses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _currentIndex = 1);
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
        ),

        // Bus List
        _isLoading
            ? const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            : _availableBuses.isEmpty
            ? SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_bus_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No buses available right now',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pull down to refresh',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final bus = _availableBuses[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: BusCard(bus: bus, onTap: () => _onBusTap(bus)),
                  );
                }, childCount: _availableBuses.length),
              ),

        // Bottom Padding
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildProfileTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF1B5E20),
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              widget.phoneNumber,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Passenger',
                style: TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
