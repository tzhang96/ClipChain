import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/video_provider.dart';
import '../providers/likes_provider.dart';
import '../providers/chain_provider.dart';
import '../widgets/video_grid_view.dart';
import '../types/firestore_types.dart';
import '../models/feed_source.dart';

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
    final chainProvider = Provider.of<ChainProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final isCurrentUser = widget.userId == null || widget.userId == authProvider.user?.uid;
    
    await Future.wait([
      videoProvider.fetchUserVideos(userId),
      userProvider.fetchUser(userId),
      likesProvider.loadUserLikes(userId),
      chainProvider.fetchUserChains(userId),
      if (isCurrentUser) chainProvider.loadUserLikedChains(userId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final videoProvider = context.watch<VideoProvider>();
    final likesProvider = context.watch<LikesProvider>();
    final chainProvider = context.watch<ChainProvider>();
    
    final targetUserId = widget.userId ?? authProvider.user?.uid;
    final isCurrentUser = widget.userId == null || widget.userId == authProvider.user?.uid;
    final userVideos = targetUserId != null ? videoProvider.getVideosByUserId(targetUserId) : <VideoDocument>[];
    final userChains = targetUserId != null ? chainProvider.getChainsByUserId(targetUserId) : <ChainDocument>[];
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
    final feedSource = ProfileFeedSource(
      userId: targetUserId,
      username: userData.username,
    );

    final tabs = [
      TabData(
        label: 'Videos',
        videos: userVideos,
        isLoading: videoProvider.isLoadingUserVideos,
        errorMessage: videoProvider.userVideosError,
        feedSource: feedSource,
      ),
      TabData(
        label: 'Chains',
        videos: [],
        chains: userChains,
        isLoading: chainProvider.isLoadingUserChains,
        errorMessage: chainProvider.userChainsError,
        feedSource: feedSource,
      ),
      if (isCurrentUser)
        TabData(
          label: 'Liked',
          videos: [],
          isLoading: likesProvider.isLoading || chainProvider.isLoadingLikes,
          errorMessage: likesProvider.error ?? chainProvider.likesError,
          feedSource: feedSource,
          subtabs: [
            SubTabData(
              label: 'Videos',
              videos: likesProvider.getLikedVideoIds(targetUserId)
                  .map((id) => videoProvider.getVideoById(id))
                  .where((video) => video != null)
                  .map((video) => video!)
                  .toList(),
            ),
            SubTabData(
              label: 'Chains',
              chains: chainProvider.getLikedChainIds(targetUserId)
                  .map((id) => chainProvider.getChainById(id))
                  .where((chain) => chain != null)
                  .map((chain) => chain!)
                  .toList(),
            ),
          ],
        ),
    ];

    return VideoGridView(
      selectedIndex: 2, // Profile is always index 2
      title: userData.username,
      showBackButton: widget.userId != null,
      userId: targetUserId,
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
                    '${userVideos.length} videos • ${userChains.length} chains',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (isCurrentUser)
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await authProvider.signOut(context);
                },
              ),
          ],
        ),
      ),
      tabs: tabs,
    );
  }
} 