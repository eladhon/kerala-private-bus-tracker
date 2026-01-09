import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/user_preference_model.dart';
import '../../services/supabase_queries.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel currentUser;
  final UserPreferenceModel? userPreferences;
  final Function() onSaveCallback;

  const EditProfileScreen({
    super.key,
    required this.currentUser,
    this.userPreferences,
    required this.onSaveCallback,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _placeController;
  late TextEditingController _addressController;
  late TextEditingController _genderController;
  late TextEditingController _dobController;
  late TextEditingController _homeController;
  late TextEditingController _workController;
  late TextEditingController _schoolController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _placeController = TextEditingController(
      text: widget.userPreferences?.place,
    );
    _addressController = TextEditingController(
      text: widget.userPreferences?.address,
    );
    _genderController = TextEditingController(
      text: widget.userPreferences?.gender,
    );
    _dobController = TextEditingController(
      text: widget.userPreferences?.dateOfBirth?.toIso8601String().split(
        'T',
      )[0],
    );
    _homeController = TextEditingController(
      text: widget.userPreferences?.homeLocation,
    );
    _workController = TextEditingController(
      text: widget.userPreferences?.workLocation,
    );
    _schoolController = TextEditingController(
      text: widget.userPreferences?.schoolLocation,
    );
  }

  @override
  void dispose() {
    _placeController.dispose();
    _addressController.dispose();
    _genderController.dispose();
    _dobController.dispose();
    _homeController.dispose();
    _workController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);

    DateTime? dob;
    if (_dobController.text.isNotEmpty) {
      try {
        dob = DateTime.parse(_dobController.text);
      } catch (e) {
        // Ignore invalid date for now or show error
      }
    }

    final prefs = UserPreferenceModel(
      userId: widget.currentUser.id,
      place: _placeController.text,
      address: _addressController.text,
      gender: _genderController.text,
      dateOfBirth: dob,
      homeLocation: _homeController.text,
      workLocation: _workController.text,
      schoolLocation: _schoolController.text,
      updatedAt: DateTime.now(),
    );

    await SupabaseQueries().upsertUserPreferences(prefs);

    // Also update user name if we had a field for it (requires API change, skipping for now as per plan)

    await widget.onSaveCallback();

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _savePreferences,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _placeController,
                    decoration: const InputDecoration(
                      labelText: 'Place',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.home),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _genderController,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _dobController,
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            hintText: 'YYYY-MM-DD',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  Text(
                    'Saved Locations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _homeController,
                    decoration: const InputDecoration(
                      labelText: 'Home',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.home_filled),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _workController,
                    decoration: const InputDecoration(
                      labelText: 'Work',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _schoolController,
                    decoration: const InputDecoration(
                      labelText: 'College / School',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
