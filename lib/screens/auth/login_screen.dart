import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_queries.dart';
import 'otp_screen.dart';

/// Login screen with mobile number input
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _queries = SupabaseQueries();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your mobile number';
    }
    // Remove any spaces or dashes
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.length != 10) {
      return 'Please enter a valid 10-digit number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Please enter a valid Indian mobile number';
    }
    return null;
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone =
          '+91${_phoneController.text.replaceAll(RegExp(r'[\s\-]'), '')}';

      // Check if user exists in database
      final user = await _queries.getUserByPhone(phone);

      String role = 'user';

      if (user == null) {
        // Auto-register new user as Passenger
        try {
          await _queries.createUser(
            phone: phone,
            name: 'Passenger',
            role: 'user',
          );
        } catch (e) {
          debugPrint('Error creating user: $e');
        }
      } else {
        role = user.role;
      }

      // For now, navigate directly to home based on role (simplified auth)
      // In production, you would use Supabase OTP authentication
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(phoneNumber: phone, userRole: role),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
      body: Container(
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      size: 80,
                      color: isDark
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App Title
                  Text(
                    'Kerala Bus Tracker',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track private buses in real-time',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Login Card
                  Card(
                    elevation: 8,
                    // Card color handled by Theme (CardTheme)
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Login with Mobile',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            // Phone Input
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: _validatePhone,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                                hintText: '9876543210',
                                prefixText: '+91 ',
                                prefixIcon: Icon(Icons.phone_android),
                                // Borders handled by Theme (InputDecorationTheme)
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Login Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _sendOtp,
                              // Style handled by Theme
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
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
                  const SizedBox(height: 24),

                  // Footer
                  Text(
                    'By continuing, you agree to our Terms of Service',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
