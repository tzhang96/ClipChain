import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../types/firestore_types.dart';
import 'video_grid.dart';
import '../screens/video_feed_screen.dart';
import 'authenticated_view.dart';

class TabData {
  final String label;
  final List<VideoDocument> videos;
  final bool isLoading;
  final String? errorMessage;

  const TabData({
    required this.label,
    required this.videos,
    this.isLoading = false,
    this.errorMessage,
  });
}

class VideoGridView extends StatefulWidget {
  final Widget header;
  final List<TabData> tabs;
  final void Function(String videoId)? onVideoTap;
  final bool showBackButton;
  final String? title;
  final int selectedIndex;

  const VideoGridView({
    super.key,
    required this.header,
    required this.tabs,
    this.onVideoTap,
    this.showBackButton = false,
    this.title,
    required this.selectedIndex,
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

  void _handleVideoTap(String videoId, List<VideoDocument> videos) {
    if (widget.onVideoTap != null) {
      // If we have an external handler, use that
      widget.onVideoTap!(videoId);
    } else {
      // Navigate to feed view
      final index = videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => VideoFeedScreen(
              customVideos: videos,
              initialIndex: index,
              title: widget.title,
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
      onVideoTap: (videoId) => _handleVideoTap(videoId, tab.videos),
    );
  }
} 