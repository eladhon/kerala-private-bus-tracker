import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/user_model.dart';
import '../../models/bus_schedule_model.dart';
import 'widgets/bus_schedule_editor.dart';
import '../../models/route_model.dart';
import '../../models/stop_model.dart';

import 'admin_login_screen.dart';
import 'widgets/route_stop_manager_widget.dart';
import '../../services/theme_manager.dart';
import 'screens/moderation_screen.dart';
import 'screens/approvals_screen.dart';
import 'screens/admin_reports_screen.dart';
import 'screens/admin_analytics_screen.dart';
import 'screens/shift_management_screen.dart';
import '../../widgets/sos_button.dart';

/// Admin home screen with dashboard and management tabs

/// Admin home screen with dashboard and management tabs
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _queries = SupabaseQueries();
  int _selectedIndex = 0;

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
    _loadData();
  }

  // Dispose not needed as TabController is removed

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
    List<BusScheduleModel> tempSchedule = [];

    // Use StatefulBuilder to manage local state inside the dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
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
                  BusScheduleEditor(
                    routes: _routes,
                    initialSchedule: tempSchedule,
                    onScheduleChanged: (newSchedule) {
                      tempSchedule = newSchedule;
                    },
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
          );
        },
      ),
    );

    if (result == true &&
        nameController.text.isNotEmpty &&
        regController.text.isNotEmpty &&
        tempSchedule.isNotEmpty) {
      try {
        await _queries.createBus(
          name: nameController.text,
          registrationNumber: regController.text,
          routeId:
              tempSchedule.first.routeId, // Use first trip's route as primary
          schedule: tempSchedule,
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
    List<BusScheduleModel> tempSchedule = List.from(bus.schedule);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
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
                  BusScheduleEditor(
                    routes: _routes,
                    initialSchedule: tempSchedule,
                    onScheduleChanged: (newSchedule) {
                      tempSchedule = newSchedule;
                    },
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
          );
        },
      ),
    );

    if (result == true) {
      try {
        await _queries.updateBus(bus.id, {
          'name': nameController.text,
          'registration_number': regController.text,
          'schedule': tempSchedule,
          if (tempSchedule.isNotEmpty) 'route_id': tempSchedule.first.routeId,
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
        final phone = '+91${phoneController.text.trim()}';

        // Check if user exists
        final existingUser = await _queries.getUserByPhone(phone);

        if (existingUser == null) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('User Not Found'),
                content: const Text(
                  'This phone number is not registered. The conductor needs to create a user account in the app first.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          // Verify if already a conductor
          if (existingUser.role == 'conductor') {
            _showSuccess('User is already a conductor');
          } else {
            // Promote to conductor
            await _queries.updateUser(existingUser.id, {
              'role': 'conductor',
              // Optionally update name if admin wants to force a name?
              // For now let's keep the user's name or update it?
              // The prompt implies just changing the role.
              // But since the dialog asks for Name, maybe we should update it.
              'name': nameController.text.trim(),
            });
            await _loadData();
            _showSuccess('User promoted to Conductor');
          }
        }
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
    switch (_selectedIndex) {
      case 0:
        return 'Add Bus';
      case 1:
        return 'Add Conductor';
      case 2:
        return 'Add Route';
      case 3:
        return 'Add Word'; // Logic handled inside ModerationScreen mostly, but for consistency
      default:
        return 'Add';
    }
  }

  void _handleAddButton() {
    switch (_selectedIndex) {
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

  Future<void> _createReturnRoute(RouteModel route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Return Route'),
        content: Text(
          'Create a return route for "${route.name}"?\n\n'
          'This will duplicate stops in reverse order and swap Start/End locations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (route.busStops.isEmpty) {
        _showError('Cannot reverse a route with no stops.');
        return;
      }

      try {
        // 1. Swap Start/End
        final newName = '${route.endLocation} - ${route.startLocation}';

        // 2. Reverse Stops
        // Logic:
        // Total Duration = LastStop.minutesFromStart of original route
        // New Stop[i] is Old Stop[N-1-i]
        // New Minutes = Total Minutes - Old Stop[N-1-i].minutesFromStart

        final totalMinutes = route.busStops.last.minutesFromStart ?? 0;

        final reversedStops = route.busStops.reversed
            .toList()
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final stop = entry.value;

              int? newMinutes;
              if (stop.minutesFromStart != null) {
                newMinutes = totalMinutes - stop.minutesFromStart!;
                if (newMinutes < 0) newMinutes = 0;
              }

              // Create new Stop copy with new ID (temp) and reversed logic
              return stop.copyWith(
                id: 'temp_rev_$index',
                minutesFromStart: newMinutes,
                orderIndex: index + 1,
              );
            })
            .toList();

        await _queries.createRoute(
          name: newName,
          startLocation: route.endLocation,
          endLocation: route.startLocation,
          distance: route.distance,
          isPopular: route.isPopular,
          stops: reversedStops,
        );

        await _loadData();
        _showSuccess('Return route created: "$newName"');
      } catch (e) {
        _showError('Failed to create return route: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background handled by theme
      appBar: AppBar(
        // Colors handled by theme
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              ThemeManager.instance.toggleTheme();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Theme toggled'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            },
            tooltip: 'Toggle Theme',
          ),
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
      ),
      floatingActionButton: _selectedIndex < 2
          ? FloatingActionButton.extended(
              onPressed: _handleAddButton,
              icon: const Icon(Icons.add),
              label: Text(_getAddButtonLabel()),
              // Theme handled
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.directions_bus_outlined),
                      selectedIcon: Icon(Icons.directions_bus),
                      label: Text('Buses'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people),
                      selectedIcon: Icon(Icons.people_alt),
                      label: Text('Conductors'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.map),
                      selectedIcon: Icon(Icons.map_outlined),
                      label: Text('Routes'),
                    ),
                    // New Moderation Tab
                    NavigationRailDestination(
                      icon: Icon(Icons.shield),
                      selectedIcon: Icon(Icons.shield),
                      label: Text('Moderation'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.verified_user_outlined),
                      selectedIcon: Icon(Icons.verified_user),
                      label: Text('Approvals'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment),
                      label: Text('Reports'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.analytics_outlined),
                      selectedIcon: Icon(Icons.analytics),
                      label: Text('Analytics'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.schedule_outlined),
                      selectedIcon: Icon(Icons.schedule),
                      label: Text('Shifts'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.sos_outlined),
                      selectedIcon: Icon(Icons.sos),
                      label: Text('SOS'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      // Stats Cards (Only show on dashboard tabs?)
                      // User feedback implies they want RouteStopEditor in NavRail.
                      // Maybe hide stats for Routes tab to give max space for map?
                      if (_selectedIndex != 2)
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
                      Expanded(child: _buildMainContent()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildBusManagement();
      case 1:
        return _buildConductorManagement();
      case 2:
        return _buildRouteManager();
      case 3:
        return const ModerationScreen();
      case 4:
        return const ApprovalsScreen();
      case 5:
        return AdminReportsScreen(conductors: _conductors, buses: _buses);
      case 6:
        return const AdminAnalyticsScreen();
      case 7:
        return const ShiftManagementScreen();
      case 8:
        return const SosAlertsScreen();
      default:
        return _buildBusManagement();
    }
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

  Widget _buildRouteManager() {
    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No routes found.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showAddRouteDialog,
              child: const Text('Add Route'),
            ),
          ],
        ),
      );
    }

    // Ensure selected route is valid
    final selectedRoute = _routes.firstWhere(
      (r) => r.id == _selectedRouteIdForStops,
      orElse: () => _routes.first,
    );
    // Update state if fallback occurred
    if (selectedRoute.id != _selectedRouteIdForStops) {
      if (mounted) {
        // Using addPostFrameCallback to avoid state setting during build if this is called from build
        // But since this is a build method, we should avoid setState.
        // Just return the UI for the first route.
        _selectedRouteIdForStops = selectedRoute.id;
      }
    }

    return Column(
      children: [
        // Route Selector Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Row(
            children: [
              Text(
                'Select Route:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRoute.id,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      items: _routes.map((route) {
                        return DropdownMenuItem(
                          value: route.id,
                          child: Row(
                            children: [
                              Text(
                                route.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              if (route.isPopular) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.orange.shade700,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    'POPULAR',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRouteIdForStops = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showAddRouteDialog,
                icon: const Icon(Icons.add),
                label: const Text('New Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.purple),
                onPressed: () => _createReturnRoute(selectedRoute),
                tooltip: 'Create Return Route',
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditRouteDialog(selectedRoute),
                tooltip: 'Edit Route',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _deleteRoute(selectedRoute),
                tooltip: 'Delete Route',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // The Route Editor Widget
        Expanded(
          child: RouteStopManagerWidget(
            key: ValueKey(selectedRoute.id), // Force rebuild on change
            route: selectedRoute,
          ),
        ),
      ],
    );
  }
}
