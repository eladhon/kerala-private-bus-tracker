import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/user_model.dart';
import '../../models/route_model.dart';
import '../../models/bus_stop_model.dart';
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
  List<BusStopModel> _busStops = [];
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

  Future<void> _showAddBusStopDialog() async {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String? selectedRouteId;
    final orderController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Bus Stop'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        hintText: '10.5276',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        hintText: '76.2144',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: selectedRouteId,
                decoration: const InputDecoration(
                  labelText: 'Assign to Route (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No Route'),
                  ),
                  ..._routes.map(
                    (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                  ),
                ],
                onChanged: (v) => selectedRouteId = v,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: orderController,
                decoration: const InputDecoration(
                  labelText: 'Order in Route (Optional)',
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true &&
        nameController.text.isNotEmpty &&
        latController.text.isNotEmpty &&
        lngController.text.isNotEmpty) {
      try {
        await _queries.createBusStop(
          name: nameController.text,
          latitude: double.parse(latController.text),
          longitude: double.parse(lngController.text),
          routeId: selectedRouteId,
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

  Future<void> _showEditBusStopDialog(BusStopModel stop) async {
    final nameController = TextEditingController(text: stop.name);
    final latController = TextEditingController(text: stop.latitude.toString());
    final lngController = TextEditingController(
      text: stop.longitude.toString(),
    );
    String? selectedRouteId = stop.routeId;
    final orderController = TextEditingController(
      text: stop.orderIndex?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: selectedRouteId,
                decoration: const InputDecoration(
                  labelText: 'Assign to Route',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No Route'),
                  ),
                  ..._routes.map(
                    (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                  ),
                ],
                onChanged: (v) => selectedRouteId = v,
              ),
              const SizedBox(height: 16),
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
    );

    if (result == true) {
      try {
        await _queries.updateBusStop(stop.id, {
          'name': nameController.text,
          'latitude': double.parse(latController.text),
          'longitude': double.parse(lngController.text),
          'route_id': selectedRouteId,
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

  Future<void> _deleteBusStop(BusStopModel stop) async {
    final confirm = await _showDeleteConfirmation('Delete "${stop.name}"?');
    if (confirm == true) {
      try {
        await _queries.deleteBusStop(stop.id);
        await _loadData();
        _showSuccess('Bus stop deleted');
      } catch (e) {
        _showError('Failed to delete bus stop: $e');
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
        return 'Add Stop';
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
        _showAddBusStopDialog();
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
            Tab(icon: Icon(Icons.location_on), text: 'Stops'),
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
                    initialValue: conductor.busId,
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
    if (_busStops.isEmpty) {
      return const Center(
        child: Text('No bus stops found. Add one using the + button.'),
      );
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _busStops.length,
        separatorBuilder: (_, i) => const Divider(),
        itemBuilder: (context, index) {
          final stop = _busStops[index];
          final route = _routes.cast<RouteModel?>().firstWhere(
            (r) => r?.id == stop.routeId,
            orElse: () => null,
          );
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on, color: Colors.purple),
            ),
            title: Text(
              stop.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                if (route != null)
                  Text(
                    'Route: ${route.name}',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                if (stop.orderIndex != null)
                  Text(
                    'Stop #${stop.orderIndex}',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditBusStopDialog(stop),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteBusStop(stop),
                ),
              ],
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}
