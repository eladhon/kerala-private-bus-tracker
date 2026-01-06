import 'package:flutter/material.dart';
// For Theme Toggle
import '../../services/supabase_queries.dart';
import '../../models/bus_model.dart';
import '../../models/user_model.dart';
import '../../models/user_preference_model.dart';
import 'bus_tracking_screen.dart';
import '../../services/theme_manager.dart';

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
  UserModel? _currentUser;
  UserPreferenceModel? _userPreferences;
  bool _isLoading = true;
  int _currentIndex = 0;

  // Quick pick options including static and dynamic
  final List<String> _staticQuickPicks = ['Home', 'Work', 'College'];

  // Quick pick routes for Kerala (Dynamic destination names)
  final List<Map<String, String>> _destinationPicks = [
    {'name': 'Thodupuzha Private Bus Stand', 'label': 'To Thodupuzha'},
    {'name': 'Muvattupuzha Private Bus Stand', 'label': 'To Muvattupuzha'},
    {'name': 'Moolamattom Private Bus Stand', 'label': 'To Moolamattom'},
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

      // Load user details
      final user = await _queries.getUserByPhone(widget.phoneNumber);

      UserPreferenceModel? prefs;
      if (user != null) {
        prefs = await _queries.getUserPreferences(user.id);
      }

      if (mounted) {
        setState(() {
          _availableBuses = buses;
          _currentUser = user;
          _userPreferences = prefs;
        });
      }
    } catch (e) {
      // Handle error silently for demo
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
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
      } else if (query == 'College') {
        savedLocation = _userPreferences?.schoolLocation;
      }

      if (savedLocation != null && savedLocation.isNotEmpty) {
        // Search for the saved location directly
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RouteSearchScreen(initialQuery: savedLocation!),
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
      // Background handled by theme
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
        return RouteSearchScreen(initialQuery: '');
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
                ..._destinationPicks.map(
                  (pick) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(pick['label']!),
                      onPressed: () => _onQuickPickTap(pick['name']!),
                    ),
                  ),
                ),
              ],
            ),
          ),

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

                                  // Time aligned to the right
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      '10 min', // Placeholder
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 50,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _currentUser!.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _currentUser!.phone,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentUser!.role.toUpperCase(),
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 32),

          _buildPersonalDetailsSection(),

          const SizedBox(height: 24),

          // Settings Section
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  secondary: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                  ),
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (bool value) {
                    ThemeManager.instance.toggleTheme();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsSection() {
    return Card(
      // Card theme handles styling
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Personal Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _showEditPreferencesDialog,
                ),
              ],
            ),
            const Divider(),
            _buildDetailRow('Place', _userPreferences?.place ?? 'Not set'),
            _buildDetailRow('Address', _userPreferences?.address ?? 'Not set'),
            _buildDetailRow('Gender', _userPreferences?.gender ?? 'Not set'),
            _buildDetailRow(
              'Date of Birth',
              _userPreferences?.dateOfBirth?.toIso8601String().split('T')[0] ??
                  'Not set',
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Saved Places',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _buildDetailRow(
              'Home',
              _userPreferences?.homeLocation ?? 'Not set',
            ),
            _buildDetailRow(
              'Work',
              _userPreferences?.workLocation ?? 'Not set',
            ),
            _buildDetailRow(
              'College',
              _userPreferences?.schoolLocation ?? 'Not set',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPreferencesDialog() {
    final placeController = TextEditingController(
      text: _userPreferences?.place,
    );
    final addressController = TextEditingController(
      text: _userPreferences?.address,
    );
    final genderController = TextEditingController(
      text: _userPreferences?.gender,
    );
    // Simplified date handling for now, user can type YYYY-MM-DD
    final dobController = TextEditingController(
      text: _userPreferences?.dateOfBirth?.toIso8601String().split('T')[0],
    );
    final homeController = TextEditingController(
      text: _userPreferences?.homeLocation,
    );
    final workController = TextEditingController(
      text: _userPreferences?.workLocation,
    );
    final schoolController = TextEditingController(
      text: _userPreferences?.schoolLocation,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Personal Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: placeController,
                decoration: const InputDecoration(labelText: 'Place'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: genderController,
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              TextField(
                controller: dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth (YYYY-MM-DD)',
                ),
              ),
              const Divider(),
              TextField(
                controller: homeController,
                decoration: const InputDecoration(labelText: 'Home Location'),
              ),
              TextField(
                controller: workController,
                decoration: const InputDecoration(labelText: 'Work Location'),
              ),
              TextField(
                controller: schoolController,
                decoration: const InputDecoration(
                  labelText: 'College/School Location',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _savePreferences(
                place: placeController.text,
                address: addressController.text,
                gender: genderController.text,
                dob: dobController.text,
                home: homeController.text,
                work: workController.text,
                school: schoolController.text,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePreferences({
    required String place,
    required String address,
    required String gender,
    required String dob,
    required String home,
    required String work,
    required String school,
  }) async {
    if (_currentUser == null) return;

    DateTime? parsedDob;
    try {
      parsedDob = DateTime.parse(dob);
    } catch (_) {}

    final newPrefs = UserPreferenceModel(
      userId: _currentUser!.id,
      place: place,
      address: address,
      gender: gender,
      dateOfBirth: parsedDob,
      homeLocation: home,
      workLocation: work,
      schoolLocation: school,
      updatedAt: DateTime.now(),
    );

    try {
      await _queries.upsertUserPreferences(newPrefs);

      setState(() {
        _userPreferences = newPrefs;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Preferences updated!')));
      }
    } catch (e) {
      debugPrint('Error updating preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow; // Rethrow to prevent dialog from closing if handled upstream
    }
  }
}
