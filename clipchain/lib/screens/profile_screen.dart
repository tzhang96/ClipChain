import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/video_provider.dart';
import '../providers/likes_provider.dart';
import '../widgets/video_grid_view.dart';
import '../types/firestore_types.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // If null, shows current user's profile

  const ProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Schedule initialization after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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
      final likesProvider = Provider.of<LikesProvider>(context, listen: false);
      
      await Future.wait([
        videoProvider.fetchUserVideos(userId),
        userProvider.fetchUser(userId),
        likesProvider.loadUserLikes(userId),
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
    final likesProvider = context.watch<LikesProvider>();
    
    final userId = widget.userId ?? authProvider.user?.uid;
    final isCurrentUser = widget.userId == null || widget.userId == authProvider.user?.uid;
    final userVideos = userId != null ? videoProvider.getVideosByUserId(userId) : <VideoDocument>[];
    final userData = userId != null ? userProvider.getUser(userId) : null;

    // Build tabs data
    final tabs = [
      TabData(
        label: 'Videos',
        videos: userVideos,
        isLoading: videoProvider.isLoadingUserVideos,
        errorMessage: videoProvider.userVideosError,
      ),
      if (isCurrentUser)
        TabData(
          label: 'Liked',
          videos: userId != null
            ? likesProvider.getLikedVideoIds(userId)
                .map((id) => videoProvider.getVideoById(id))
                .where((video) => video != null)
                .map((video) => video!)
                .toList()
            : <VideoDocument>[],
          isLoading: likesProvider.isLoading,
          errorMessage: likesProvider.error,
        ),
    ];

    return VideoGridView(
      showBackButton: widget.userId != null, // Show back button if viewing another user's profile
      header: Container(
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
      tabs: tabs,
      onVideoTap: _onVideoTap,
    );
  }
} 