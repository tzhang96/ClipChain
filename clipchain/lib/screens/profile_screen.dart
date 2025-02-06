import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
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

  @override
  void initState() {
    super.initState();
    final isCurrentUser = widget.userId == null || 
        widget.userId == Provider.of<AuthProvider>(context, listen: false).user?.uid;
    _tabController = TabController(
      length: isCurrentUser ? 2 : 1,
      vsync: this,
    );
    // Schedule initialization after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Public method to refresh data
  void refreshVideos() {
    // Schedule loading after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    try {
      final userId = widget.userId ?? 
          Provider.of<AuthProvider>(context, listen: false).user?.uid;
      
      if (userId == null) {
        throw Exception('No user ID available');
      }

      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      await Future.wait([
        videoProvider.fetchUserVideos(userId),
        userProvider.fetchUser(userId),
      ]);

    } catch (e) {
      print('ProfileScreen: Error loading data: $e');
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
    final userProvider = context.watch<UserProvider>();
    final userId = widget.userId ?? authProvider.user?.uid;
    final isCurrentUser = widget.userId == null || widget.userId == authProvider.user?.uid;

    final userVideos = userId != null ? videoProvider.getVideosByUserId(userId) : [];
    final userData = userId != null ? userProvider.getUser(userId) : null;

    return Scaffold(
      body: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: userData?.photoUrl != null
                      ? NetworkImage(userData!.photoUrl!)
                      : null,
                  child: userData?.photoUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userData?.username ?? 'Loading...',
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