import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/video_provider.dart';
import '../providers/likes_provider.dart';
import '../widgets/video_grid_view.dart';
import '../types/firestore_types.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    final userId = widget.userId ?? 
        Provider.of<AuthProvider>(context, listen: false).user?.uid;
    
    if (userId == null) return;

    final videoProvider = Provider.of<VideoProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final likesProvider = Provider.of<LikesProvider>(context, listen: false);
    
    await Future.wait([
      videoProvider.fetchUserVideos(userId),
      userProvider.fetchUser(userId),
      likesProvider.loadUserLikes(userId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final videoProvider = context.watch<VideoProvider>();
    final likesProvider = context.watch<LikesProvider>();
    
    final targetUserId = widget.userId ?? authProvider.user?.uid;
    final isCurrentUser = widget.userId == null || widget.userId == authProvider.user?.uid;
    final userVideos = targetUserId != null ? videoProvider.getVideosByUserId(targetUserId) : <VideoDocument>[];
    final userData = targetUserId != null ? userProvider.getUser(targetUserId) : null;

    if (targetUserId == null) {
      return const Center(child: Text('Not logged in'));
    }

    if (userData == null) {
      // Fetch user data if not available
      if (!userProvider.isLoading(targetUserId)) {
        userProvider.fetchUser(targetUserId);
      }
      return const Center(child: CircularProgressIndicator());
    }

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
          videos: likesProvider.getLikedVideoIds(targetUserId)
              .map((id) => videoProvider.getVideoById(id))
              .where((video) => video != null)
              .map((video) => video!)
              .toList(),
          isLoading: likesProvider.isLoading,
          errorMessage: likesProvider.error,
        ),
    ];

    return VideoGridView(
      selectedIndex: 2, // Profile is always index 2
      title: userData.username,
      showBackButton: widget.userId != null,
      header: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: userData.photoUrl != null
                  ? NetworkImage(userData.photoUrl!)
                  : null,
              child: userData.photoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userData.username,
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
    );
  }
} 