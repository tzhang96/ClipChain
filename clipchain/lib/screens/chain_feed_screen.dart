import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../types/firestore_types.dart';
import '../models/feed_source.dart';
import '../providers/video_provider.dart';
import '../providers/user_provider.dart';
import 'video_feed_screen.dart';

class ChainFeedScreen extends StatelessWidget {
  final ChainDocument chain;
  final int initialVideoIndex;

  const ChainFeedScreen({
    super.key,
    required this.chain,
    this.initialVideoIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Get the chain creator's username
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.getUser(chain.userId);
    
    // If we don't have the user data, fetch it
    if (user == null && !userProvider.isLoading(chain.userId)) {
      userProvider.fetchUser(chain.userId);
    }

    // Get all videos in the chain
    final videoProvider = context.watch<VideoProvider>();
    final videos = chain.videoIds
        .map((id) => videoProvider.getVideoById(id))
        .where((video) => video != null)
        .map((video) => video!)
        .toList();

    // Create feed source for navigation
    final feedSource = ChainFeedSource(
      chain: chain,
      username: user?.username ?? 'Loading...',
    );

    return VideoFeedScreen(
      customVideos: videos,
      initialIndex: initialVideoIndex.clamp(0, videos.length - 1),
      title: chain.title,
      onHeaderTap: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => feedSource.buildReturnScreen(),
          ),
          (route) => false,
        );
      },
    );
  }
} 