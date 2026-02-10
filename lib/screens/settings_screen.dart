import 'package:flutter/material.dart';
import '../services/theme_manager.dart';
import '../models/user_model.dart';
import 'auth/login_screen.dart';
import 'user/edit_profile_screen.dart';
import '../models/user_preference_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../services/supabase_queries.dart'; // Unused

class SettingsScreen extends StatelessWidget {
  final UserModel? currentUser;
  final UserPreferenceModel? userPreferences;
  final VoidCallback? onProfileUpdate;

  const SettingsScreen({
    super.key,
    this.currentUser,
    this.userPreferences,
    this.onProfileUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // final textTheme = Theme.of(context).textTheme; // Unused

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Section 1: Account
          _buildSectionHeader(context, 'Account'),
          if (currentUser != null) ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              subtitle: Text(currentUser!.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      currentUser: currentUser!,
                      userPreferences: userPreferences,
                      onSaveCallback: onProfileUpdate ?? () {},
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Phone Number'),
              subtitle: Text(currentUser!.phone),
              // Phone number is usually immutable or requires separate flow
              onTap: null,
            ),
          ] else ...[
            const ListTile(
              leading: Icon(Icons.person_off_outlined),
              title: Text('Not Logged In'),
            ),
          ],
          const Divider(),

          // Section 2: Appearance
          _buildSectionHeader(context, 'Appearance'),
          AnimatedBuilder(
            animation: ThemeManager.instance,
            builder: (context, _) {
              final isDark = ThemeManager.instance.themeMode == ThemeMode.dark;
              return SwitchListTile(
                secondary: Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                ),
                title: const Text('Dark Mode'),
                value: isDark,
                onChanged: (value) {
                  ThemeManager.instance.toggleTheme();
                },
              );
            },
          ),
          const Divider(),

          // Section 3: About
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About App'),
            onTap: () => _showAboutDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Feedback'),
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming Soon!')));
            },
          ),
          const Divider(),

          // Section 4: Actions
          _buildSectionHeader(context, 'Actions'),
          ListTile(
            leading: Icon(Icons.logout, color: colorScheme.error),
            title: Text(
              'Logout',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: 'Kerala Bus Tracker',
        applicationVersion: '1.0.0',
        applicationIcon: const Icon(
          Icons.directions_bus,
          size: 48,
          color: Colors.blue,
        ),
        children: const [
          SizedBox(height: 16),
          Text('Track private buses in Kerala in real-time.'),
          SizedBox(height: 8),
          Text('Designed for Passengers and Conductors.'),
          SizedBox(height: 24),
          Text('Credits', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Lead Developer: Eldho Eapen'),
          Text('Database Management: Aswin Unnikrishnan'),
          Text('Layout Designer: Adithyan EV'),
          Text('System Tester: Nayana C Jayan'),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    // Clear any potential background tasks or services here if needed
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (context.mounted) {
      // Then navigate to login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
