import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chain_provider.dart';
import '../providers/likes_provider.dart';
import '../types/firestore_types.dart';
import '../widgets/video_grid.dart';
import '../screens/chain_view_screen.dart';

class CreateChainScreen extends StatefulWidget {
  final String? initialVideoId;

  const CreateChainScreen({
    super.key,
    this.initialVideoId,
  });

  @override
  State<CreateChainScreen> createState() => _CreateChainScreenState();
}

class _CreateChainScreenState extends State<CreateChainScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedVideoIds = {};
  bool _isCreating = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialVideoId != null) {
      _selectedVideoIds.add(widget.initialVideoId!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createChain() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVideoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one video')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final userId = context.read<AuthProvider>().user?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final chainProvider = context.read<ChainProvider>();
      final chain = await chainProvider.createChain(
        userId: userId,
        title: _titleController.text,
        description: _descriptionController.text,
        initialVideoIds: _selectedVideoIds.toList(),
      );

      if (mounted && chain != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chain created successfully!')),
        );
        if (widget.initialVideoId != null) {
          Navigator.of(context).pop(chain.id);
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => ChainViewScreen(chain: chain),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating chain: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _toggleVideoSelection(String videoId) {
    setState(() {
      if (_selectedVideoIds.contains(videoId)) {
        _selectedVideoIds.remove(videoId);
      } else {
        _selectedVideoIds.add(videoId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().user?.uid;
    final userVideos = userId != null 
        ? context.watch<VideoProvider>().getVideosByUserId(userId)
        : <VideoDocument>[];
    final likedVideoIds = userId != null
        ? context.watch<LikesProvider>().getLikedVideoIds(userId)
        : <String>{};
    final likedVideos = likedVideoIds
        .map((id) => context.watch<VideoProvider>().getVideoById(id))
        .where((video) => video != null)
        .map((video) => video!)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Chain'),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Input
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                    enabled: !_isCreating,
                  ),
                  const SizedBox(height: 16),

                  // Description Input
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: !_isCreating,
                  ),
                  const SizedBox(height: 16),

                  // Selected Videos Count
                  Text(
                    'Selected Videos: ${_selectedVideoIds.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  // Video Selection Tabs
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'My Videos'),
                      Tab(text: 'Liked Videos'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Video Selection Grid
                  SizedBox(
                    height: 400,
                    child: GestureDetector(
                      onTap: () {
                        // Dismiss keyboard when tapping the video grid area
                        FocusScope.of(context).unfocus();
                      },
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // My Videos Tab
                          VideoGrid(
                            videos: userVideos,
                            isLoading: false,
                            onVideoTap: (videoId) {
                              // Dismiss keyboard when selecting videos
                              FocusScope.of(context).unfocus();
                              if (!_isCreating) {
                                _toggleVideoSelection(videoId);
                              }
                            },
                            selectedVideoIds: _selectedVideoIds,
                          ),
                          // Liked Videos Tab
                          VideoGrid(
                            videos: likedVideos,
                            isLoading: false,
                            onVideoTap: (videoId) {
                              // Dismiss keyboard when selecting videos
                              FocusScope.of(context).unfocus();
                              if (!_isCreating) {
                                _toggleVideoSelection(videoId);
                              }
                            },
                            selectedVideoIds: _selectedVideoIds,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Create Button
                  if (_isCreating)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      onPressed: _createChain,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Create Chain'),
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