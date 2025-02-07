import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../types/firestore_types.dart';
import '../models/feed_source.dart';
import 'video_feed_screen.dart';

/// Key used to control the main "For You" feed
class MainFeedKey extends GlobalKey<VideoFeedScreenState> {
  const MainFeedKey() : super.constructor();
}

class MainFeedScreen extends StatelessWidget {
  final MainFeedKey? feedKey;

  const MainFeedScreen({
    super.key,
    this.feedKey,
  });

  @override
  Widget build(BuildContext context) {
    print('MainFeedScreen: Building');
    final videos = context.watch<VideoProvider>().videos;
    print('MainFeedScreen: Got ${videos.length} videos');
    
    final source = MainFeedSource();
    print('MainFeedScreen: Created feed source: ${source.title}');
    
    return VideoFeedScreen(
      key: feedKey,
      customVideos: videos,
      title: source.title,
      onHeaderTap: () {
        print('MainFeedScreen: Header tapped, navigating to grid view');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => source.buildReturnScreen(),
          ),
          (route) => false,
        );
      },
    );
  }
} 