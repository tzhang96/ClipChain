import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/video_grid.dart';
import '../types/firestore_types.dart';
import 'home_screen.dart';
import '../providers/video_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // If null, shows current user's profile

  const ProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Use post-frame callback to avoid state changes during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadVideos();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Public method to refresh videos
  void refreshVideos() {
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      final userId = widget.userId ?? 
          Provider.of<AuthProvider>(context, listen: false).user?.uid;
      
      if (userId == null) {
        throw Exception('No user ID available');
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      await videoProvider.fetchUserVideos(userId);

    } catch (e) {
      print('ProfileScreen: Error loading videos: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onVideoTap(String videoId) {
    // Find the ancestor HomeScreen's state and navigate to the video
    final homeState = context.findAncestorStateOfType<HomeScreenState>();
    if (homeState != null) {
      homeState.showVideo(videoId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final videoProvider = context.watch<VideoProvider>();
    final userId = widget.userId ?? authProvider.user?.uid;
    final isCurrentUser = widget.userId == null || widget.userId == authProvider.user?.uid;

    final userVideos = userId != null ? videoProvider.getVideosByUserId(userId) : [];

    return Scaffold(
      body: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authProvider.user?.email ?? 'User',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${userVideos.length} videos',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (isCurrentUser)
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => authProvider.signOut(),
                  ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: 'Videos'),
              if (isCurrentUser) const Tab(text: 'Liked'),
            ],
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                VideoGrid(
                  videos: userVideos.map((doc) => VideoModel.fromDocument(doc)).toList(),
                  isLoading: videoProvider.isLoadingUserVideos,
                  errorMessage: videoProvider.userVideosError,
                  onVideoTap: _onVideoTap,
                ),
                if (isCurrentUser)
                  const Center(child: Text('Liked videos coming soon')),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 