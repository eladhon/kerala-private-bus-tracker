import 'package:flutter/material.dart';
import '../../models/student_application_model.dart';
import '../../services/supabase_queries.dart';
import '../../services/supabase_service.dart';

class StudentPassScreen extends StatefulWidget {
  final String? currentUserId; // Accepted from parent

  const StudentPassScreen({super.key, this.currentUserId});

  @override
  State<StudentPassScreen> createState() => _StudentPassScreenState();
}

class _StudentPassScreenState extends State<StudentPassScreen> {
  final _queries = SupabaseQueries();
  final _auth = SupabaseService().client.auth;

  StudentApplicationModel? _application;
  bool _isLoading = true;

  // Form handling
  final _formKey = GlobalKey<FormState>();
  final _schoolController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadApplication();
  }

  @override
  void dispose() {
    _schoolController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadApplication() async {
    final userId = widget.currentUserId ?? _auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final app = await _queries.getUserApplication(userId);
      setState(() => _application = app);
    } catch (e) {
      debugPrint('Error loading app: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = widget.currentUserId ?? _auth.currentUser?.id;
    if (userId == null) return;

    // Fetch user details for name (could be optimized)
    String userName = "Student";
    try {
      final dbUser = await _queries.getUserById(userId);
      if (dbUser != null) userName = dbUser.name;
    } catch (_) {}

    setState(() => _isSubmitting = true);
    try {
      await _queries.createStudentApplication(
        userId: userId,
        userName: userName,
        schoolName: _schoolController.text.trim(),
        idCardUrl: _urlController.text.trim(),
      );
      await _loadApplication();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Application Submitted!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Pass')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    if (_application == null) {
      return _buildApplyForm();
    }

    switch (_application!.status) {
      case 'pending':
        return _buildStatusView(
          icon: Icons.hourglass_top,
          color: Colors.orange,
          title: 'Verification Pending',
          message: 'Your student ID is under review. Please check back later.',
        );
      case 'rejected':
        return Column(
          children: [
            _buildStatusView(
              icon: Icons.error_outline,
              color: Colors.red,
              title: 'Application Rejected',
              message:
                  'Your application was not approved. Please ensure the ID is clear and valid.',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Reset to allow re-apply (delete old app logic could be added or just status update)
                // For MVP, we might need a way to 'archive' old rejected ones or just update the existing one.
                // Current backend logic inserts new row. UI assumes single active.
                // Simplest: Show contact support or "Re-apply" which clears local state to show form?
                // But DB constraints might prevent duplicate user_id if we added UNIQUE.
                // Assuming we can submit another request:
                setState(() => _application = null);
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      case 'approved':
        return _buildDigitalCard();
      default:
        return const Center(child: Text('Unknown Status'));
    }
  }

  Widget _buildApplyForm() {
    final userId = widget.currentUserId ?? _auth.currentUser?.id;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (userId == null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.red.shade100,
                child: const Text(
                  'Error: You are not logged in. Please re-login.',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const Text(
              'Apply for Student Concession',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload your school/college ID card to get concession rates.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _schoolController,
              decoration: const InputDecoration(
                labelText: 'School / College Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'ID Card Image URL',
                hintText: 'http://example.com/my_id.jpg',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: In a real app, this would be a file uploader.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitApplication,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusView({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: color),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalCard() {
    return Center(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.directions_bus, color: Colors.white),
                  Text(
                    'STUDENT PASS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              Text(
                _application!.userName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _application!.schoolName,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'VERIFIED',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Valid for Concession Rates',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
