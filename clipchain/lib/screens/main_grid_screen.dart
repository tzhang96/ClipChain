import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../widgets/video_grid_view.dart';
import '../models/feed_source.dart';

class MainGridScreen extends StatefulWidget {
  const MainGridScreen({super.key});

  @override
  State<MainGridScreen> createState() => _MainGridScreenState();
}

class _MainGridScreenState extends State<MainGridScreen> {
  @override
  void initState() {
    super.initState();
    print('MainGridScreen: initState called');
    print('MainGridScreen: Starting video load check');
    _ensureVideosLoaded();
  }

  Future<void> _ensureVideosLoaded() async {
    if (!mounted) {
      print('MainGridScreen: Widget not mounted, skipping video load');
      return;
    }
    
    print('MainGridScreen: Checking video provider state');
    final videoProvider = context.read<VideoProvider>();
    print('MainGridScreen: Current video count: ${videoProvider.videos.length}');
    print('MainGridScreen: Loading state: ${videoProvider.isLoadingFeed}');
    
    if (videoProvider.videos.isEmpty && !videoProvider.isLoadingFeed) {
      print('MainGridScreen: No videos loaded, triggering fetch');
      await videoProvider.fetchVideos();
      print('MainGridScreen: Fetch complete, new video count: ${videoProvider.videos.length}');
    } else {
      print('MainGridScreen: Videos already loaded: ${videoProvider.videos.length}');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('MainGridScreen: build called');
    final videoProvider = context.watch<VideoProvider>();
    print('MainGridScreen: Building with ${videoProvider.videos.length} videos');
    print('MainGridScreen: Loading state: ${videoProvider.isLoadingFeed}');
    print('MainGridScreen: Error state: ${videoProvider.feedError}');
    
    final feedSource = MainFeedSource();
    print('MainGridScreen: Created feed source: ${feedSource.title}');
    
    final tabs = [
      TabData(
        label: 'All Videos',
        videos: videoProvider.videos,
        isLoading: videoProvider.isLoadingFeed,
        errorMessage: videoProvider.feedError,
        feedSource: feedSource,
      ),
    ];
    print('MainGridScreen: Created tabs with ${tabs.length} tabs');

    return VideoGridView(
      selectedIndex: 0, // Main feed is always index 0
      title: 'For You',
      showBackButton: false,
      header: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For You',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Discover the latest videos from everyone',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
      tabs: tabs,
    );
  }
} 