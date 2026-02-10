import 'package:flutter/material.dart';
// For Theme Toggle
import '../settings_screen.dart';
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/user_model.dart';
import '../../models/user_preference_model.dart';
import '../../models/route_model.dart';
import 'bus_tracking_screen.dart';
// import '../../services/theme_manager.dart'; // Unused
import '../../services/reminder_service.dart';

import 'route_search_screen.dart';
import 'edit_profile_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/vehicle_state_model.dart';
import 'student_pass_screen.dart';
// import '../auth/login_screen.dart'; // Unused
import 'trip_history_screen.dart';
import 'nearby_stops_screen.dart';
import '../../widgets/sos_button.dart';

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
  List<RouteModel> _popularRoutes = [];
  UserModel? _currentUser;
  UserPreferenceModel? _userPreferences;
  bool _isLoading = true;
  int _currentIndex = 0;
  List<BusModel> _favoriteBuses = [];
  List<BusModel> _recentBuses = [];
  Map<String, VehicleStateModel> _busLocations = {};
  Position? _userPosition;

  // Quick pick options including static and dynamic
  final List<String> _staticQuickPicks = ['Home', 'Work', 'College', 'School'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all data in parallel
      final prefs = await SharedPreferences.getInstance();
      final recentIds = prefs.getStringList('recent_bus_ids') ?? [];

      final results = await Future.wait([
        _queries.getPopularRoutes(),
        _queries.getAvailableBuses(),
        _queries.getUserByPhone(widget.phoneNumber),
        _queries.getAllVehicleStates(),
        _queries.getBusesByIds(recentIds),
      ]);

      final popularRoutes = results[0] as List<RouteModel>;
      final buses = results[1] as List<BusModel>;
      final user = results[2] as UserModel?;
      final vehicleStates = results[3] as List<VehicleStateModel>;
      final fetchedRecentBuses = results[4] as List<BusModel>;

      // Prepare data locally before setState
      final recentBusMap = {for (var b in fetchedRecentBuses) b.id: b};
      final orderedRecentBuses = recentIds
          .map((id) => recentBusMap[id])
          .whereType<BusModel>()
          .toList();

      final locationMap = {for (var state in vehicleStates) state.busId: state};

      // Fetch user-specific data if logged in
      UserPreferenceModel? prefsModel;
      List<BusModel> favorites = [];
      if (user != null) {
        final userDataResults = await Future.wait([
          _queries.getUserPreferences(user.id),
          _queries.getFavoriteBuses(user.id),
        ]);
        prefsModel = userDataResults[0] as UserPreferenceModel?;
        favorites = userDataResults[1] as List<BusModel>;
      }

      // Single setState with all data
      if (mounted) {
        setState(() {
          _popularRoutes = popularRoutes;
          _availableBuses = buses;
          _currentUser = user;
          _userPreferences = prefsModel;
          _busLocations = locationMap;
          _recentBuses = orderedRecentBuses;
          _favoriteBuses = favorites;
          _isLoading = false;
        });
      }

      // Fetch location asynchronously (non-blocking)
      Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          )
          .then((pos) {
            if (mounted) setState(() => _userPosition = pos);
          })
          .catchError((e) {
            debugPrint("Location error: $e");
            return null;
          });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onQuickPickTap(String query) {
    if (_staticQuickPicks.contains(query)) {
      // Handle static quick picks (Home, Work, etc)
      String? savedLocation;
      if (query == 'Home') {
        savedLocation = _userPreferences?.homeLocation;
      } else if (query == 'Work') {
        savedLocation = _userPreferences?.workLocation;
      } else if (query == 'College' || query == 'School') {
        savedLocation = _userPreferences?.schoolLocation;
      }

      if (savedLocation != null && savedLocation.isNotEmpty) {
        // Search for the saved location directly
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RouteSearchScreen(
              initialQuery: savedLocation!,
              currentUserId: _currentUser?.id,
            ),
          ),
        );
        return;
      } else {
        // If not set, maybe prompt or just search the word (fallback)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$query location not set in "You" tab')),
        );
        // Fallback to searching the word "Home" etc might not be useful, so we stop or open empty search
        // For now, let's open empty search so they can type
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RouteSearchScreen(initialQuery: ''),
          ),
        );
        return;
      }
    }

    // Handle dynamic destination picks
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteSearchScreen(initialQuery: query),
      ),
    );
  }

  Future<void> _onBusTap(BusModel bus) async {
    if (!bus.isAvailable) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text("Bus Unavailable"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This bus is currently marked as unavailable by the conductor.",
              ),
              const SizedBox(height: 12),
              if (bus.unavailabilityReason != null &&
                  bus.unavailabilityReason!.isNotEmpty) ...[
                const Text(
                  "Reason:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(bus.unavailabilityReason!),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        ),
      );
      return;
    }

    // Add to recent buses
    setState(() {
      _recentBuses.removeWhere((b) => b.id == bus.id);
      _recentBuses.insert(0, bus);
      if (_recentBuses.length > 10) _recentBuses.removeLast();
    });

    // Save to prefs (fire and forget)
    SharedPreferences.getInstance().then((prefs) {
      prefs.setStringList(
        'recent_bus_ids',
        _recentBuses.map((b) => b.id).toList(),
      );
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BusTrackingScreen(bus: bus, currentUserId: _currentUser?.id),
      ),
    );
    // Refresh data (especially favorites) when returning
    if (mounted) {
      _loadData();
    }
  }

  String _calculateEtaDisplay(BusModel bus) {
    if (!bus.isAvailable) return "Unavailable";

    final vehicleState = _busLocations[bus.id];
    final userPos = _userPosition;

    if (vehicleState == null || userPos == null) {
      return "Locating...";
    }

    // Calculate distance
    const distance = Distance();
    final double distMeters = distance.as(
      LengthUnit.Meter,
      LatLng(vehicleState.lat, vehicleState.lng),
      LatLng(userPos.latitude, userPos.longitude),
    );

    // Estimate time: assume average speed 25 km/h ≈ 416 m/min
    // Adjust logic as needed. Real traffic is slower.
    const double speedMetersPerMin = 400.0;
    final int minutes = (distMeters / speedMetersPerMin).ceil();

    if (minutes < 1) return "Arriving";
    if (minutes > 60) return "> 1 hr";
    return "~$minutes min";
  }

  // Logout moved to SettingsScreen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background handled by theme
      appBar: _currentIndex == 2
          ? AppBar(
              title: const Text('Profile'),
              centerTitle: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(
                          currentUser: _currentUser,
                          userPreferences: _userPreferences,
                          onProfileUpdate: _loadData,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      floatingActionButton: _currentIndex == 0 && _currentUser != null
          ? SosButton(userId: _currentUser!.id, userRole: 'user')
          : null,
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return RouteSearchScreen(
          initialQuery: '',
          currentUserId: _currentUser?.id,
        );
      case 2:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Reminders Section
          ValueListenableBuilder<List<BusModel>>(
            valueListenable: ReminderService().activeReminders,
            builder: (context, activeReminders, _) {
              if (activeReminders.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'ACTIVE REMINDERS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange, // Highlight color
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: activeReminders.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final bus = activeReminders[index];
                        return InkWell(
                          onTap: () => _onBusTap(bus),
                          child: Container(
                            width: 280,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.notifications_active,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        bus.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        "Notify when ~10m away",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    ReminderService().removeReminder(bus.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Reminder cancelled"),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          // Top Section: Quick picks
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  'Quick picks',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Horizontally scrollable rounded choice chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ..._staticQuickPicks.map(
                  (label) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(label),
                      onPressed: () => _onQuickPickTap(label),
                      // Theme handles styling
                    ),
                  ),
                ),
                ..._popularRoutes.map(
                  (route) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text('To ${route.endLocation}'),
                      onPressed: () => _onQuickPickTap(route.endLocation),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // "Your Favorites" Section
          if (_favoriteBuses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'YOUR FAVORITES',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.outline,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _favoriteBuses.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final bus = _favoriteBuses[index];
                  return InkWell(
                    onTap: () => _onBusTap(bus),
                    child: Container(
                      width: 250,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bus.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.directions_bus,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                bus.registrationNumber,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bus.routeId, // Simplified for now as route object might not be fully populated
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 16),

          // "BUSES" section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'BUSES',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.outline,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Large rounded card with subtle shadow containing bus list
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _availableBuses.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _availableBuses.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          indent: 70, // Align with text
                        ),
                        itemBuilder: (context, index) {
                          final bus = _availableBuses[index];
                          return InkWell(
                            onTap: () => _onBusTap(bus),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  // Circular location icon on the left
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.directions_bus,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Destination name text next to it
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bus.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          bus.registrationNumber,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Status / Time aligned to the right
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bus.isAvailable
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.surface
                                          : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: bus.isAvailable
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant
                                            : Colors.red,
                                      ),
                                    ),
                                    child: Text(
                                      _calculateEtaDisplay(bus),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: bus.isAvailable
                                                ? null
                                                : Colors.red,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No buses found',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Section
          Container(
            width: double.infinity,
            color: colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        _currentUser!.name.isNotEmpty
                            ? _currentUser!.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _navigateToEditProfile,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 3,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.edit,
                            size: 16,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUser!.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentUser!.phone,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _navigateToEditProfile,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: const Text('Edit Profile'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // "Stops Near Me" Feature Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NearbyStopsScreen(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.tertiaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.radar,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\ud83d\ude8f Stops Near Me',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Find bus stops around you. Move the map, find your ride! \ud83c\udfaf',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 2. History Section ("Recently Viewed") - Horizontal Squares
          if (_recentBuses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recently Viewed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Maybe clear logic or see all page?
                      setState(() => _recentBuses.clear());
                    },
                    child: const Text("Clear"),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 140, // Height for square cards
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _recentBuses.length,
                itemBuilder: (context, index) {
                  final bus = _recentBuses[index];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: InkWell(
                        onTap: () => _onBusTap(bus),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.visibility,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const Spacer(),
                                  // Could show time here if we tracked it
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bus.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    bus.routeId,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 2. Student Passes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh,
              child: ListTile(
                leading: const Icon(Icons.school, color: Colors.blue),
                title: const Text('Student Pass'),
                subtitle: const Text('Apply for concession rates'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StudentPassScreen(currentUserId: _currentUser?.id),
                    ),
                  );
                },
              ),
            ),
          ),

          // Trip History Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh,
              child: ListTile(
                leading: const Icon(Icons.history, color: Colors.green),
                title: const Text('Trip History'),
                subtitle: const Text('View your past journeys'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  if (_currentUser != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TripHistoryScreen(userId: _currentUser!.id),
                      ),
                    );
                  }
                },
              ),
            ),
          ),

          // 3. Conductor Ratings - Horizontal List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Rate Conductors',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 16), // More spacing
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: colorScheme.tertiaryContainer,
                            child: Text(
                              'C${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Conductor ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      TextButton(
                        onPressed: () {
                          // Show rating dialog
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Rate'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _navigateToEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          currentUser: _currentUser!,
          userPreferences: _userPreferences,
          onSaveCallback: _loadData,
        ),
      ),
    );
  }
}
