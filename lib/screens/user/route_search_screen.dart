import 'package:flutter/material.dart';
import '../../services/supabase_queries.dart';
import '../../models/route_model.dart';
import '../../models/bus_model.dart';
import '../../widgets/bus_card.dart';
import 'bus_tracking_screen.dart';

/// Route search screen with autocomplete
class RouteSearchScreen extends StatefulWidget {
  final String initialQuery;

  const RouteSearchScreen({super.key, required this.initialQuery});

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final _queries = SupabaseQueries();
  final _searchController = TextEditingController();
  List<RouteModel> _routes = [];
  List<BusModel> _busesOnRoute = [];
  RouteModel? _selectedRoute;
  bool _isSearching = false;
  bool _isLoadingBuses = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    if (widget.initialQuery.isNotEmpty) {
      _searchRoutes(widget.initialQuery);
    } else {
      _loadAllRoutes();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllRoutes() async {
    setState(() => _isSearching = true);
    try {
      final routes = await _queries.getAllRoutes();
      setState(() => _routes = routes);
    } catch (e) {
      debugPrint('Error loading routes: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _searchRoutes(String query) async {
    if (query.isEmpty) {
      _loadAllRoutes();
      return;
    }

    setState(() {
      _isSearching = true;
      _selectedRoute = null;
      _busesOnRoute = [];
    });

    try {
      final routes = await _queries.searchRoutes(query);
      setState(() => _routes = routes);
    } catch (e) {
      debugPrint('Error searching routes: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectRoute(RouteModel route) async {
    setState(() {
      _selectedRoute = route;
      _isLoadingBuses = true;
    });

    try {
      final buses = await _queries.getBusesByRoute(route.id);
      setState(() => _busesOnRoute = buses);
    } catch (e) {
      debugPrint('Error loading buses: $e');
    } finally {
      setState(() => _isLoadingBuses = false);
    }
  }

  void _onBusTap(BusModel bus) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BusTrackingScreen(bus: bus)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Search Routes'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _searchRoutes,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by route name or location...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _loadAllRoutes();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _selectedRoute != null
                ? _buildBusesList()
                : _buildRoutesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutesList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No routes found',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _routes.length,
      itemBuilder: (context, index) {
        final route = _routes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.route, color: Color(0xFF1B5E20)),
            ),
            title: Text(
              route.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(route.displayName),
                if (route.distance != null)
                  Text(
                    '${route.distance!.toStringAsFixed(1)} km',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectRoute(route),
          ),
        );
      },
    );
  }

  Widget _buildBusesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Route Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedRoute = null;
                    _busesOnRoute = [];
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedRoute!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _selectedRoute!.displayName,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Buses List
        Expanded(
          child: _isLoadingBuses
              ? const Center(child: CircularProgressIndicator())
              : _busesOnRoute.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_bus_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No buses on this route',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _busesOnRoute.length,
                  itemBuilder: (context, index) {
                    final bus = _busesOnRoute[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BusCard(bus: bus, onTap: () => _onBusTap(bus)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
