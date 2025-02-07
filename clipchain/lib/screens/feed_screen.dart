import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../types/firestore_types.dart';
import '../models/feed_source.dart';
import '../providers/video_provider.dart';
import 'video_feed_screen.dart';

/// Base class for all feed screens
abstract class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  /// Get the videos to display in this feed
  List<VideoDocument> getVideos(BuildContext context);

  /// Get the feed source for this feed
  FeedSource getFeedSource();

  /// Build the screen that shows this feed
  @override
  Widget build(BuildContext context) {
    final source = getFeedSource();
    print('FeedScreen: Building feed with source ${source.title}');
    print('FeedScreen: Video count: ${getVideos(context).length}');
    
    return VideoFeedScreen(
      customVideos: getVideos(context),
      title: source.title,
      onHeaderTap: () {
        print('FeedScreen: Header tapped for ${source.title}');
        print('FeedScreen: Navigating to return screen');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) {
              print('FeedScreen: Building return screen route');
              final screen = source.buildReturnScreen();
              print('FeedScreen: Return screen built: ${screen.runtimeType}');
              return screen;
            },
          ),
          (route) => false,
        );
      },
    );
  }
}

/// The main "For You" feed
class MainFeedScreen extends FeedScreen {
  const MainFeedScreen({super.key});

  @override
  List<VideoDocument> getVideos(BuildContext context) {
    print('MainFeedScreen: Getting videos');
    final videos = context.watch<VideoProvider>().videos;
    print('MainFeedScreen: Returning ${videos.length} videos');
    return videos;
  }

  @override
  FeedSource getFeedSource() {
    print('MainFeedScreen: Creating MainFeedSource');
    return MainFeedSource();
  }
} 