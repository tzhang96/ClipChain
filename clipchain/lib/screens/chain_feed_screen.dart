import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../types/firestore_types.dart';
import '../models/feed_source.dart';
import '../providers/video_provider.dart';
import '../providers/user_provider.dart';
import '../providers/chain_provider.dart';
import '../providers/auth_provider.dart';
import 'video_feed_screen.dart';
import 'chain_view_screen.dart';

class ChainFeedScreen extends StatelessWidget {
  final ChainDocument chain;
  final int initialVideoIndex;

  const ChainFeedScreen({
    super.key,
    required this.chain,
    this.initialVideoIndex = 0,
  });

  Widget _buildHeader(BuildContext context, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Consumer<ChainProvider>(
                builder: (context, chainProvider, _) {
                  final liveChain = chainProvider.getChainById(chain.id) ?? chain;
                  print('ChainFeedScreen: Rebuilding title with chain ${liveChain.id}, likes: ${liveChain.likes}');
                  return Text(
                    liveChain.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            Consumer2<AuthProvider, ChainProvider>(
              builder: (context, authProvider, chainProvider, _) {
                final userId = authProvider.user?.uid;
                final isLiked = userId != null && 
                    chainProvider.isItemLiked(userId, chain.id);
                final liveChain = chainProvider.getChainById(chain.id) ?? chain;
                print('ChainFeedScreen: Rebuilding like button with chain ${liveChain.id}, likes: ${liveChain.likes}, isLiked: $isLiked');

                return Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (userId != null) {
                          print('ChainFeedScreen: Like button tapped for chain ${chain.id}');
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
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.grid_view,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the chain creator's username
    final userProvider = context.watch<UserProvider>();
    final chainProvider = context.watch<ChainProvider>();
    final user = userProvider.getUser(chain.userId);
    
    // If we don't have the user data, fetch it
    if (user == null && !userProvider.isLoading(chain.userId)) {
      userProvider.fetchUser(chain.userId);
    }

    // Ensure chain is in the main cache
    if (chainProvider.getChainById(chain.id) == null) {
      print('ChainFeedScreen: Adding chain to main cache');
      chainProvider.addToMainCache(chain);
    }

    // Get all videos in the chain
    final videoProvider = context.watch<VideoProvider>();
    final videos = chain.videoIds
        .map((id) => videoProvider.getVideoById(id))
        .where((video) => video != null)
        .map((video) => video!)
        .toList();

    return VideoFeedScreen(
      customVideos: videos,
      initialIndex: initialVideoIndex.clamp(0, videos.length - 1),
      title: chain.title,
      onHeaderTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChainViewScreen(chain: chain),
          ),
        );
      },
      headerBuilder: (context, onTap) => _buildHeader(context, onTap),
    );
  }
} 