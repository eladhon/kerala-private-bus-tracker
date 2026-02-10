import 'package:flutter/material.dart';
import '../../services/supabase_queries.dart';
import 'otp_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String phoneNumber;

  const RegistrationScreen({super.key, required this.phoneNumber});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isStudent = false;
  bool _applyConcession = false;
  bool _isLoading = false;
  final _queries = SupabaseQueries();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final isStudent = _isStudent && _applyConcession;

      // Create the user in public.users
      final user = await _queries.createUser(
        phone: widget.phoneNumber,
        name: _nameController.text,
        role: 'user',
        isStudent: isStudent,
      );

      if (mounted) {
        // Navigate to OTP Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                OtpScreen(phoneNumber: widget.phoneNumber, userRole: user.role),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating account: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B5E20), // Kerala green
                    Color(0xFF2E7D32),
                    Color(0xFF388E3C),
                  ],
                ),
          color: isDark ? Theme.of(context).colorScheme.surface : null,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Welcome!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Complete your profile for ${widget.phoneNumber}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Personal Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter your name'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person),
                          hintText: 'Enter your name',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Student Switch
                      SwitchListTile(
                        title: const Text('Are you a student?'),
                        value: _isStudent,
                        onChanged: (value) {
                          setState(() {
                            _isStudent = value;
                            if (!value) _applyConcession = false;
                          });
                        },
                        secondary: const Icon(Icons.school),
                      ),

                      // Concession Switch (Visible if Student)
                      if (_isStudent)
                        SwitchListTile(
                          title: const Text('Apply for Student Concession?'),
                          subtitle: const Text(
                            'You may need to upload ID proof later',
                          ),
                          value: _applyConcession,
                          onChanged: (value) {
                            setState(() => _applyConcession = value);
                          },
                          secondary: const Icon(Icons.discount),
                        ),

                      const SizedBox(height: 32),

                      // Create Account Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _registerUser,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
