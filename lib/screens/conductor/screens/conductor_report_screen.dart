import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:uuid/uuid.dart';

import '../../../models/conductor_report_model.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_queries.dart';
import '../../../services/supabase_storage_service.dart';

class ConductorReportScreen extends StatefulWidget {
  final UserModel user;
  final String reportType; // 'repair' or 'fuel'
  final VoidCallback onBack;

  const ConductorReportScreen({
    super.key,
    required this.user,
    required this.reportType,
    required this.onBack,
  });

  @override
  State<ConductorReportScreen> createState() => _ConductorReportScreenState();
}

class _ConductorReportScreenState extends State<ConductorReportScreen> {
  final _queries = SupabaseQueries();
  final _storage = SupabaseStorageService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  List<ConductorReportModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _queries.getConductorReports(
        userId: widget.user.id,
        type: widget.reportType,
      );
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      // Scroll to bottom after frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent, // List is reversed
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _selectedImage == null) {
      return;
    }
    if (widget.user.busId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No bus assigned to you!')));
      return;
    }

    setState(() => _isSending = true);

    try {
      List<String> mediaUrls = [];

      // 1. Upload Image if exists
      if (_selectedImage != null) {
        final url = await _storage.uploadFile(
          _selectedImage!,
          folder: '${widget.user.id}/${widget.user.busId}',
        );
        if (url != null) mediaUrls.add(url);
      }

      // 2. Create Report
      final report = ConductorReportModel(
        id: const Uuid().v4(),
        userId: widget.user.id,
        busId: widget.user.busId!,
        type: widget.reportType,
        content: _messageController.text.trim(),
        mediaUrls: mediaUrls,
        createdAt: DateTime.now(),
      );

      // 3. Submit
      await _queries.submitConductorReport(report);

      // 4. Update UI
      setState(() {
        _messages.insert(0, report); // Prepend for reverse list
        _messageController.clear();
        _selectedImage = null;
        _isSending = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRepair = widget.reportType == 'repair';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Header (Custom embedded AppBar)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRepair ? 'Report Repair' : 'Fuel Log',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                isRepair ? Icons.build_circle : Icons.local_gas_station,
                color: isRepair ? Colors.red : Colors.blue,
              ),
            ],
          ),
        ),

        // Chat List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? Center(
                  child: Text(
                    'No reports yet. Send your first ${isRepair ? 'repair request' : 'fuel log'}!',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Chat bottom-up
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
        ),

        // Image Preview
        if (_selectedImage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_selectedImage!.path.split('/').last)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedImage = null),
                ),
              ],
            ),
          ),

        // Input Area
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: () => _pickImage(ImageSource.camera),
                color: theme.colorScheme.primary,
              ),
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: () => _pickImage(ImageSource.gallery),
                color: theme.colorScheme.primary,
              ),
              // Voice placeholder
              IconButton(
                icon: const Icon(Icons.mic),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voice notes coming soon!')),
                  );
                },
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: _isSending ? null : _sendMessage,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ConductorReportModel msg) {
    // Determine align based on user ID if we had admin replies
    // For now, assuming Conductor sees their own messages on right
    // Real implementation: if (msg.userId == widget.user.id) ...

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 40),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.mediaUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    msg.mediaUrls.first,
                    width: 150,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 150,
                        height: 100,
                        color: Colors.grey.shade300,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              ),
            if (msg.content != null && msg.content!.isNotEmpty)
              Text(
                msg.content!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatDate(msg.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.month}/${date.day}";
  }
}
