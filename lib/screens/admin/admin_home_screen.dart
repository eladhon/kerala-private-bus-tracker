import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/user_model.dart';
import '../../models/route_model.dart';
import '../../models/stop_model.dart';
import '../../widgets/location_picker.dart';
import 'admin_login_screen.dart';

/// Admin home screen with dashboard and management tabs
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  final _queries = SupabaseQueries();
  late TabController _tabController;

  List<BusModel> _buses = [];
  List<UserModel> _conductors = [];
  List<RouteModel> _routes = [];
  List<StopModel> _busStops = [];
  String? _selectedRouteIdForStops;
  bool _isLoading = true;
  int _availableBusCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final buses = await _queries.getAllBuses();
      final conductors = await _queries.getAllConductors();
      final routes = await _queries.getAllRoutes();
      final stops = await _queries.getAllBusStops();
      setState(() {
        _buses = buses;
        _conductors = conductors;
        _routes = routes;
        _busStops = stops;
        _availableBusCount = buses.where((b) => b.isAvailable).length;

        // Initialize selected route if needed
        if (_selectedRouteIdForStops == null && _routes.isNotEmpty) {
          _selectedRouteIdForStops = _routes.first.id;
        }
        // Validate selected route still exists
        if (_selectedRouteIdForStops != null &&
            !_routes.any((r) => r.id == _selectedRouteIdForStops)) {
          _selectedRouteIdForStops = _routes.isNotEmpty
              ? _routes.first.id
              : null;
        }
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================
  // BUS CRUD OPERATIONS
  // ============================================

  Future<void> _toggleBusAvailability(BusModel bus) async {
    try {
      await _queries.setBusAvailability(bus.id, !bus.isAvailable);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${bus.name} is now ${!bus.isAvailable ? "available" : "offline"}',
            ),
            backgroundColor: !bus.isAvailable ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update availability: $e');
    }
  }

  Future<void> _showAddBusDialog() async {
    final nameController = TextEditingController();
    final regController = TextEditingController();
    String? selectedRouteId = _routes.isNotEmpty ? _routes.first.id : null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Bus'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Bus Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: regController,
                decoration: const InputDecoration(
                  labelText: 'Registration Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRouteId,
                decoration: const InputDecoration(
                  labelText: 'Route',
                  border: OutlineInputBorder(),
                ),
                items: _routes
                    .map(
                      (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                    )
                    .toList(),
                onChanged: (v) => selectedRouteId = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true &&
        nameController.text.isNotEmpty &&
        regController.text.isNotEmpty &&
        selectedRouteId != null) {
      try {
        await _queries.createBus(
          name: nameController.text,
          registrationNumber: regController.text,
          routeId: selectedRouteId!,
        );
        await _loadData();
        _showSuccess('Bus added successfully');
      } catch (e) {
        _showError('Failed to add bus: $e');
      }
    }
  }

  Future<void> _showEditBusDialog(BusModel bus) async {
    final nameController = TextEditingController(text: bus.name);
    final regController = TextEditingController(text: bus.registrationNumber);
    String? selectedRouteId = bus.routeId;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bus'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Bus Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: regController,
                decoration: const InputDecoration(
                  labelText: 'Registration Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _routes.any((r) => r.id == selectedRouteId)
                    ? selectedRouteId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Route',
                  border: OutlineInputBorder(),
                ),
                items: _routes
                    .map(
                      (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                    )
                    .toList(),
                onChanged: (v) => selectedRouteId = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _queries.updateBus(bus.id, {
          'name': nameController.text,
          'registration_number': regController.text,
          'route_id': selectedRouteId,
        });
        await _loadData();
        _showSuccess('Bus updated');
      } catch (e) {
        _showError('Failed to update bus: $e');
      }
    }
  }

  Future<void> _deleteBus(BusModel bus) async {
    final confirm = await _showDeleteConfirmation('Delete "${bus.name}"?');
    if (confirm == true) {
      try {
        await _queries.deleteBus(bus.id);
        await _loadData();
        _showSuccess('Bus deleted');
      } catch (e) {
        _showError('Failed to delete bus: $e');
      }
    }
  }

  // ============================================
  // CONDUCTOR CRUD OPERATIONS
  // ============================================

  Future<void> _showAddConductorDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Conductor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: '+91',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true &&
        nameController.text.isNotEmpty &&
        phoneController.text.isNotEmpty) {
      try {
        await _queries.createConductor(
          name: nameController.text,
          phone: '+91${phoneController.text}',
        );
        await _loadData();
        _showSuccess('Conductor added');
      } catch (e) {
        _showError('Failed to add conductor: $e');
      }
    }
  }

  Future<void> _showEditConductorDialog(UserModel conductor) async {
    final nameController = TextEditingController(text: conductor.name);
    final phoneController = TextEditingController(
      text: conductor.phone.replaceAll('+91', ''),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Conductor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: '+91',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _queries.updateConductor(conductor.id, {
          'name': nameController.text,
          'phone': '+91${phoneController.text}',
        });
        await _loadData();
        _showSuccess('Conductor updated');
      } catch (e) {
        _showError('Failed to update conductor: $e');
      }
    }
  }

  Future<void> _deleteConductor(UserModel conductor) async {
    final confirm = await _showDeleteConfirmation(
      'Delete "${conductor.name}"?',
    );
    if (confirm == true) {
      try {
        await _queries.deleteConductor(conductor.id);
        await _loadData();
        _showSuccess('Conductor deleted');
      } catch (e) {
        _showError('Failed to delete conductor: $e');
      }
    }
  }

  Future<void> _assignBusToConductor(UserModel conductor, String? busId) async {
    try {
      await _queries.assignBusToConductor(conductor.id, busId);
      await _loadData();
      _showSuccess(
        busId != null ? 'Bus assigned to ${conductor.name}' : 'Bus unassigned',
      );
    } catch (e) {
      _showError('Failed to assign bus: $e');
    }
  }

  // ============================================
  // BUS STOP CRUD OPERATIONS
  // ============================================

  Future<void> _showEditBusStopDialog(
    StopModel stop, {
    required String routeId,
  }) async {
    final nameController = TextEditingController(text: stop.name);
    LatLng selectedLocation = LatLng(stop.lat, stop.lng);
    final orderController = TextEditingController(
      text: stop.orderIndex?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Bus Stop'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Stop Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Location',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final newLocation = await Navigator.push<LatLng>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LocationPicker(
                                  initialLocation: selectedLocation,
                                ),
                              ),
                            );
                            if (newLocation != null) {
                              setState(() => selectedLocation = newLocation);
                            }
                          },
                          icon: const Icon(Icons.map),
                          label: const Text('Change Location on Map'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Route is fixed to the current context
                TextField(
                  controller: orderController,
                  decoration: const InputDecoration(
                    labelText: 'Order in Route',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await _queries.updateBusStop(stop.id, {
          'name': nameController.text,
          'latitude': selectedLocation.latitude,
          'longitude': selectedLocation.longitude,
          'route_id': routeId, // Use passed routeId
          'order_index': orderController.text.isNotEmpty
              ? int.tryParse(orderController.text)
              : null,
        });
        await _loadData();
        _showSuccess('Bus stop updated');
      } catch (e) {
        _showError('Failed to update bus stop: $e');
      }
    }
  }

  Future<void> _deleteBusStop(StopModel stop, {required String routeId}) async {
    final confirm = await _showDeleteConfirmation('Delete "${stop.name}"?');
    if (confirm == true) {
      try {
        // Use the passed routeId for certain deletion context
        await _queries.deleteBusStop(stop.id, routeId);
        await _loadData();
        _showSuccess('Bus stop deleted');
      } catch (e) {
        _showError('Failed to delete bus stop: $e');
      }
    }
  }

  // ============================================
  // ROUTE CRUD OPERATIONS
  // ============================================

  Future<void> _showAddRouteDialog() async {
    final nameController = TextEditingController();
    final startController = TextEditingController();
    final endController = TextEditingController();
    final distanceController = TextEditingController();
    bool isPopular = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Route'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Route Name',
                    hintText: 'e.g., Thrissur - Ernakulam',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: startController,
                  decoration: const InputDecoration(
                    labelText: 'Start Location',
                    hintText: 'e.g., Thrissur',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: endController,
                  decoration: const InputDecoration(
                    labelText: 'End Location',
                    hintText: 'e.g., Ernakulam',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: distanceController,
                  decoration: const InputDecoration(
                    labelText: 'Distance (km, optional)',
                    hintText: 'e.g., 75',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Popular Route'),
                  subtitle: const Text('Show in quick picks'),
                  value: isPopular,
                  onChanged: (v) => setDialogState(() => isPopular = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        nameController.text.isNotEmpty &&
        startController.text.isNotEmpty &&
        endController.text.isNotEmpty) {
      try {
        await _queries.createRoute(
          name: nameController.text,
          startLocation: startController.text,
          endLocation: endController.text,
          distance: distanceController.text.isNotEmpty
              ? double.tryParse(distanceController.text)
              : null,
          isPopular: isPopular,
        );
        await _loadData();
        _showSuccess('Route added successfully');
      } catch (e) {
        _showError('Failed to add route: $e');
      }
    }
  }

  Future<void> _showEditRouteDialog(RouteModel route) async {
    final nameController = TextEditingController(text: route.name);
    final startController = TextEditingController(text: route.startLocation);
    final endController = TextEditingController(text: route.endLocation);
    final distanceController = TextEditingController(
      text: route.distance?.toString() ?? '',
    );
    bool isPopular = route.isPopular;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Route'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Route Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: startController,
                  decoration: const InputDecoration(
                    labelText: 'Start Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: endController,
                  decoration: const InputDecoration(
                    labelText: 'End Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: distanceController,
                  decoration: const InputDecoration(
                    labelText: 'Distance (km)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Popular Route'),
                  subtitle: const Text('Show in quick picks'),
                  value: isPopular,
                  onChanged: (v) => setDialogState(() => isPopular = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await _queries.updateRoute(route.id, {
          'name': nameController.text,
          'start_location': startController.text,
          'end_location': endController.text,
          'distance': distanceController.text.isNotEmpty
              ? double.tryParse(distanceController.text)
              : null,
          'is_popular': isPopular,
        });
        await _loadData();
        _showSuccess('Route updated');
      } catch (e) {
        _showError('Failed to update route: $e');
      }
    }
  }

  Future<void> _deleteRoute(RouteModel route) async {
    final confirm = await _showDeleteConfirmation(
      'Delete "${route.name}"?\n\nThis will unassign all buses from this route.',
    );
    if (confirm == true) {
      try {
        await _queries.deleteRoute(route.id);
        await _loadData();
        _showSuccess('Route deleted');
      } catch (e) {
        _showError('Failed to delete route: $e');
      }
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  Future<bool?> _showDeleteConfirmation(String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
    );
  }

  String _getAddButtonLabel() {
    switch (_tabController.index) {
      case 0:
        return 'Add Bus';
      case 1:
        return 'Add Conductor';
      case 2:
        return 'Add Route';
      default:
        return 'Add';
    }
  }

  void _handleAddButton() {
    switch (_tabController.index) {
      case 0:
        _showAddBusDialog();
        break;
      case 1:
        _showAddConductorDialog();
        break;
      case 2:
        _showAddRouteDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a237e),
        foregroundColor: Colors.white,
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.directions_bus), text: 'Buses'),
            Tab(icon: Icon(Icons.badge), text: 'Conductors'),
            Tab(icon: Icon(Icons.location_on), text: 'Routes'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleAddButton,
        icon: const Icon(Icons.add),
        label: Text(_getAddButtonLabel()),
        backgroundColor: const Color(0xFF1a237e),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildStatCard(
                        'Buses',
                        '${_buses.length}',
                        Icons.directions_bus,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Available',
                        '$_availableBusCount',
                        Icons.check_circle,
                        Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Conductors',
                        '${_conductors.length}',
                        Icons.badge,
                        Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Stops',
                        '${_busStops.length}',
                        Icons.location_on,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBusManagement(),
                      _buildConductorManagement(),
                      _buildBusStopManagement(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusManagement() {
    if (_buses.isEmpty) {
      return const Center(
        child: Text('No buses found. Add one using the + button.'),
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _buses.length,
        separatorBuilder: (_, i) => const Divider(),
        itemBuilder: (context, index) {
          final bus = _buses[index];
          final conductor = _conductors.cast<UserModel?>().firstWhere(
            (c) => c?.busId == bus.id,
            orElse: () => null,
          );
          final route = _routes.cast<RouteModel?>().firstWhere(
            (r) => r?.id == bus.routeId,
            orElse: () => null,
          );
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (bus.isAvailable ? Colors.green : Colors.grey)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.directions_bus,
                color: bus.isAvailable ? Colors.green : Colors.grey,
              ),
            ),
            title: Text(
              bus.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bus.registrationNumber),
                if (route != null)
                  Text(
                    'Route: ${route.name}',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                if (conductor != null)
                  Text(
                    'Conductor: ${conductor.name}',
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: bus.isAvailable,
                  onChanged: (_) => _toggleBusAvailability(bus),
                  activeThumbColor: Colors.green,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditBusDialog(bus),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteBus(bus),
                ),
              ],
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }

  Widget _buildConductorManagement() {
    if (_conductors.isEmpty) {
      return const Center(
        child: Text('No conductors found. Add one using the + button.'),
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _conductors.length,
        separatorBuilder: (_, i) => const Divider(),
        itemBuilder: (context, index) {
          final conductor = _conductors[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1a237e),
              child: Text(
                conductor.name.isNotEmpty
                    ? conductor.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              conductor.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(conductor.phone),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _buses.any((b) => b.id == conductor.busId)
                        ? conductor.busId
                        : null,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    hint: const Text('Assign Bus'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No Bus'),
                      ),
                      ..._buses.map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (busId) =>
                        _assignBusToConductor(conductor, busId),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditConductorDialog(conductor),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteConductor(conductor),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBusStopManagement() {
    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No routes available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Route" to create your first route',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _routes.length,
      itemBuilder: (context, index) {
        final route = _routes[index];
        return _buildRouteCard(route);
      },
    );
  }

  Widget _buildRouteCard(RouteModel route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1a237e).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route, color: Color(0xFF1a237e)),
          ),
          title: Text(
            route.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${route.startLocation} → ${route.endLocation}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (route.distance != null) ...[
                    Icon(
                      Icons.straighten,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${route.distance} km',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${route.busStops.length} stops',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  if (route.isPopular) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Popular',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditRouteDialog(route);
              } else if (value == 'delete') {
                _deleteRoute(route);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit Route'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Route', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            // Bus stops header with add button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    'Bus Stops',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showAddBusStopDialogForRoute(route.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Stop'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1a237e),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Bus stops list
            if (route.busStops.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade500),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No stops yet. Add stops to define the route path.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...route.busStops.asMap().entries.map((entry) {
                final index = entry.key;
                final stop = entry.value;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.purple.withValues(alpha: 0.1),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    stop.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${stop.lat.toStringAsFixed(4)}, ${stop.lng.toStringAsFixed(4)}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: Colors.blue,
                        onPressed: () =>
                            _showEditBusStopDialog(stop, routeId: route.id),
                        tooltip: 'Edit stop',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red,
                        onPressed: () =>
                            _deleteBusStop(stop, routeId: route.id),
                        tooltip: 'Delete stop',
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// Show add bus stop dialog for a specific route
  Future<void> _showAddBusStopDialogForRoute(String routeId) async {
    final nameController = TextEditingController();
    LatLng? selectedLocation;
    final orderController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Bus Stop'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Stop Name',
                    hintText: 'e.g., Thrissur Bus Stand',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Location',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        if (selectedLocation != null) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${selectedLocation!.latitude.toStringAsFixed(6)}, ${selectedLocation!.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ] else
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'No location selected',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final newLocation = await Navigator.push<LatLng>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LocationPicker(
                                  initialLocation: selectedLocation,
                                ),
                              ),
                            );
                            if (newLocation != null) {
                              setState(() => selectedLocation = newLocation);
                            }
                          },
                          icon: const Icon(Icons.map),
                          label: Text(
                            selectedLocation == null
                                ? 'Pick on Map'
                                : 'Change Location',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: orderController,
                  decoration: const InputDecoration(
                    labelText: 'Order (optional)',
                    hintText: '1, 2, 3...',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedLocation == null) {
                  _showError('Please select a location on the map');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        nameController.text.isNotEmpty &&
        selectedLocation != null) {
      try {
        await _queries.createBusStop(
          name: nameController.text,
          latitude: selectedLocation!.latitude,
          longitude: selectedLocation!.longitude,
          routeId: routeId,
          orderIndex: orderController.text.isNotEmpty
              ? int.tryParse(orderController.text)
              : null,
        );
        await _loadData();
        _showSuccess('Bus stop added');
      } catch (e) {
        _showError('Failed to add bus stop: $e');
      }
    }
  }
}
