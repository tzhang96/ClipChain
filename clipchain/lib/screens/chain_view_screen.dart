import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../types/firestore_types.dart';
import '../providers/video_provider.dart';
import '../providers/user_provider.dart';
import '../providers/chain_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/video_grid.dart';
import '../models/feed_source.dart';
import '../widgets/video_thumbnail.dart';
import 'profile_screen.dart';
import 'video_feed_screen.dart';
import '../widgets/authenticated_view.dart';

class ChainViewScreen extends StatelessWidget {
  final ChainDocument chain;

  const ChainViewScreen({
    super.key,
    required this.chain,
  });

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final userProvider = context.watch<UserProvider>();
    final chainProvider = context.watch<ChainProvider>();
    final user = userProvider.getUser(chain.userId);
    
    // Fetch user data if not available
    if (user == null && !userProvider.isLoading(chain.userId)) {
      userProvider.fetchUser(chain.userId);
    }

    // Get all videos in the chain
    final videos = chain.videoIds
        .map((id) => videoProvider.getVideoById(id))
        .where((video) => video != null)
        .map((video) => video!)
        .toList();

    final content = CustomScrollView(
      slivers: [
        // App Bar with chain info
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        chain.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (chain.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          chain.description!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Creator info row
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(userId: chain.userId),
                            ),
                            (route) => false,
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[300],
                              child: Text(
                                user?.username.substring(0, 1).toUpperCase() ?? '?',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              user?.username ?? 'Loading...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            // Like button
                            Consumer2<AuthProvider, ChainProvider>(
                              builder: (context, authProvider, chainProvider, _) {
                                final userId = authProvider.user?.uid;
                                final isLiked = userId != null && 
                                    chainProvider.isItemLiked(userId, chain.id);
                                final liveChain = chainProvider.getChainById(chain.id) ?? chain;

                                return Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (userId != null) {
                                          chainProvider.toggleLike(userId, chain.id);
                                        }
                                      },
                                      child: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: isLiked ? Colors.red : Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${liveChain.likes}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Videos grid
        SliverPadding(
          padding: const EdgeInsets.all(8.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 9 / 16,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final video = videos[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => VideoFeedScreen(
                          customVideos: videos,
                          initialIndex: index,
                          title: chain.title,
                          onHeaderTap: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    );
                  },
                  child: VideoThumbnail(video: video),
                );
              },
              childCount: videos.length,
            ),
          ),
        ),
      ],
    );

    return AuthenticatedView(
      selectedIndex: 0,  // We can treat this as part of the feed section
      body: content,
    );
  }
} 