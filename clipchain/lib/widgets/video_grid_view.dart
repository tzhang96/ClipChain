import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../types/firestore_types.dart';
import '../models/feed_source.dart';
import 'video_grid.dart';
import '../screens/video_feed_screen.dart';
import 'authenticated_view.dart';
import '../screens/profile_screen.dart';

class TabData {
  final String label;
  final List<VideoDocument> videos;
  final bool isLoading;
  final String? errorMessage;
  final FeedSource? feedSource;  // Optional source for the feed when tapping videos

  const TabData({
    required this.label,
    required this.videos,
    this.isLoading = false,
    this.errorMessage,
    this.feedSource,
  });
}

class VideoGridView extends StatefulWidget {
  final Widget header;
  final List<TabData> tabs;
  final void Function(String videoId)? onVideoTap;
  final bool showBackButton;
  final String? title;
  final int selectedIndex;
  final String? userId;

  const VideoGridView({
    super.key,
    required this.header,
    required this.tabs,
    this.onVideoTap,
    this.showBackButton = false,
    this.title,
    required this.selectedIndex,
    this.userId,
  });

  @override
  State<VideoGridView> createState() => VideoGridViewState();
}

class VideoGridViewState extends State<VideoGridView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(VideoGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      _tabController.dispose();
      _tabController = TabController(
        length: widget.tabs.length,
        vsync: this,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleVideoTap(String videoId, TabData tab) {
    if (widget.onVideoTap != null) {
      // If we have an external handler, use that
      widget.onVideoTap!(videoId);
    } else {
      // Navigate to feed view
      final index = tab.videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => VideoFeedScreen(
              customVideos: tab.videos,
              initialIndex: index,
              title: tab.feedSource?.title ?? widget.title,
              onHeaderTap: () {
                if (tab.feedSource != null) {
                  // Return to the source screen
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => tab.feedSource!.buildReturnScreen(),
                    ),
                    (route) => false,
                  );
                } else {
                  // Default behavior - just pop
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedView(
      selectedIndex: widget.selectedIndex,
      body: Scaffold(
        appBar: widget.showBackButton || widget.title != null
          ? AppBar(
              title: widget.title != null ? Text(widget.title!) : null,
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: widget.showBackButton,
            )
          : null,
        body: Column(
          children: [
            // Header
            widget.header,

            // Tab Bar (only if there are multiple tabs)
            if (widget.tabs.length > 1)
              TabBar(
                controller: _tabController,
                tabs: widget.tabs.map((tab) => Tab(text: tab.label)).toList(),
              ),

            // Tab Content
            Expanded(
              child: widget.tabs.length > 1
                ? TabBarView(
                    controller: _tabController,
                    children: widget.tabs.map((tab) => _buildTabContent(tab)).toList(),
                  )
                : _buildTabContent(widget.tabs.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(TabData tab) {
    return VideoGrid(
      videos: tab.videos,
      isLoading: tab.isLoading,
      errorMessage: tab.errorMessage,
      onVideoTap: (videoId) => _handleVideoTap(videoId, tab),
    );
  }
} 