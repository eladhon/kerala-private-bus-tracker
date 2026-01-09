import 'package:flutter/material.dart';
import '../../../models/conductor_review_model.dart';
import '../../../services/supabase_queries.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _queries = SupabaseQueries();
  final _wordController = TextEditingController();

  // State
  List<String> _filters = [];
  List<ConductorReviewModel> _reviews = [];
  bool _isLoadingFilters = true;
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFilters();
    _loadReviews();
  }

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _tabController.dispose();
    _wordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- DATA LOADING ---

  Future<void> _loadFilters() async {
    setState(() => _isLoadingFilters = true);
    try {
      final filters = await _queries.getModerationFilters();
      setState(() => _filters = filters);
    } catch (e) {
      debugPrint('Error loading filters: $e');
    } finally {
      setState(() => _isLoadingFilters = false);
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoadingReviews = true);
    try {
      final reviews = await _queries.getAllReviews();
      setState(() => _reviews = reviews);
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    } finally {
      setState(() => _isLoadingReviews = false);
    }
  }

  // --- ACTIONS ---

  Future<void> _addFilter() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) return;

    if (_filters.contains(word)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Word already in list')));
      return;
    }

    try {
      await _queries.addModerationFilter(word);
      _wordController.clear();
      await _loadFilters(); // Refresh
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added "$word" to blocklist')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding word: $e')));
      }
    }
  }

  Future<void> _deleteFilter(String word) async {
    try {
      await _queries.deleteModerationFilter(word);
      await _loadFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting word: $e')));
      }
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review?'),
        content: const Text(
          'Are you sure you want to delete this review? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _queries.deleteReview(reviewId);
      await _loadReviews();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting review: $e')));
      }
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.password), text: 'Banned Words'),
              Tab(icon: Icon(Icons.reviews), text: 'Review Management'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildFilterTab(), _buildReviewTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab() {
    return Column(
      children: [
        // Add Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wordController,
                  decoration: const InputDecoration(
                    labelText: 'Add bad word/phrase',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addFilter(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _addFilter,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingFilters
              ? const Center(child: CircularProgressIndicator())
              : _filters.isEmpty
              ? const Center(
                  child: Text(
                    'No banned words yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filters.map((word) {
                        return Chip(
                          label: Text(word),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => _deleteFilter(word),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ... (keeping existing methods)

  Widget _buildReviewTab() {
    // Filter Logic
    final query = _searchController.text.toLowerCase();
    final filteredReviews = _reviews.where((r) {
      final text = (r.reviewText ?? '').toLowerCase();
      final user = (r.userName ?? '').toLowerCase();
      return text.contains(query) || user.contains(query);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search reviews',
              hintText: 'Filter by text or username',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _searchController.clear());
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() {}), // Trigger rebuild on type
          ),
        ),

        // List
        Expanded(
          child: _isLoadingReviews
              ? const Center(child: CircularProgressIndicator())
              : filteredReviews.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty
                        ? 'No reviews found.'
                        : 'No matching reviews.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredReviews.length,
                  itemBuilder: (context, index) {
                    final review = filteredReviews[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rating: ${review.rating}/5',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: review.rating < 3
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                                Text(
                                  review.createdAt != null
                                      ? '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}'
                                      : '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              review.reviewText ?? 'No text',
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            const Divider(),
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  review.userName ?? 'Unknown User',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _deleteReview(review.id),
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('Delete Review'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ],
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
  }
}
