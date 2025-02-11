import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../types/firestore_types.dart';
import '../models/feed_source.dart';
import 'video_grid.dart';
import 'chain_grid.dart';
import '../screens/video_feed_screen.dart';
import 'authenticated_view.dart';
import '../screens/profile_screen.dart';
import '../screens/chain_feed_screen.dart';
import '../screens/chain_view_screen.dart';

class TabData {
  final String label;
  final List<VideoDocument> videos;
  final List<ChainDocument>? chains;  // Optional list of chains
  final bool isLoading;
  final String? errorMessage;
  final FeedSource? feedSource;  // Optional source for the feed when tapping videos
  final List<SubTabData>? subtabs;  // Optional subtabs for nested navigation

  const TabData({
    required this.label,
    required this.videos,
    this.chains,
    this.isLoading = false,
    this.errorMessage,
    this.feedSource,
    this.subtabs,
  });
}

class SubTabData {
  final String label;
  final List<VideoDocument>? videos;
  final List<ChainDocument>? chains;

  const SubTabData({
    required this.label,
    this.videos,
    this.chains,
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
  final bool showAppBar;  // Add new parameter

  const VideoGridView({
    super.key,
    required this.header,
    required this.tabs,
    this.onVideoTap,
    this.showBackButton = false,
    this.title,
    required this.selectedIndex,
    this.userId,
    this.showAppBar = true,  // Default to true for backward compatibility
  });

  @override
  State<VideoGridView> createState() => VideoGridViewState();
}

class VideoGridViewState extends State<VideoGridView> with TickerProviderStateMixin {
  late TabController _tabController;
  Map<int, TabController> _subTabControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
    );
    _initializeSubTabControllers();
  }

  void _initializeSubTabControllers() {
    _subTabControllers = {};
    for (var i = 0; i < widget.tabs.length; i++) {
      final tab = widget.tabs[i];
      if (tab.subtabs != null && tab.subtabs!.isNotEmpty) {
        _subTabControllers[i] = TabController(
          length: tab.subtabs!.length,
          vsync: this,
        );
      }
    }
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
      _disposeSubTabControllers();
      _initializeSubTabControllers();
    }
  }

  void _disposeSubTabControllers() {
    for (var controller in _subTabControllers.values) {
      controller.dispose();
    }
    _subTabControllers.clear();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeSubTabControllers();
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

  void _handleChainTap(String chainId, TabData tab) {
    // Find the chain in the tab's chains list
    final chain = tab.chains?.firstWhere((c) => c.id == chainId);
    if (chain != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ChainViewScreen(chain: chain),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedView(
      selectedIndex: widget.selectedIndex,
      body: Scaffold(
        appBar: widget.showAppBar && (widget.showBackButton || widget.title != null)
          ? AppBar(
              title: widget.title != null ? Text(widget.title!) : null,
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: widget.showBackButton,
              leading: widget.showBackButton ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/profile',
                    (route) => false,
                    arguments: widget.userId,
                  );
                },
              ) : null,
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
    if (tab.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tab.errorMessage != null) {
      return Center(
        child: Text(tab.errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    // If the tab has subtabs, show them
    if (tab.subtabs != null && tab.subtabs!.isNotEmpty) {
      final tabIndex = widget.tabs.indexOf(tab);
      final subTabController = _subTabControllers[tabIndex];
      if (subTabController == null) return const SizedBox();

      return Column(
        children: [
          TabBar(
            controller: subTabController,
            tabs: tab.subtabs!.map((subtab) => Tab(text: subtab.label)).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: subTabController,
              children: tab.subtabs!.map((subtab) {
                if (subtab.chains != null) {
                  return ChainGrid(
                    chains: subtab.chains!,
                    isLoading: false,
                    onChainTap: (chainId) {
                      final chain = subtab.chains!.firstWhere((c) => c.id == chainId);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => ChainFeedScreen(
                            chain: chain,
                            initialVideoIndex: 0,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                  );
                }
                return VideoGrid(
                  videos: subtab.videos ?? [],
                  isLoading: false,
                  onVideoTap: (videoId) {
                    final videos = subtab.videos ?? [];
                    final index = videos.indexWhere((v) => v.id == videoId);
                    if (index != -1) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => VideoFeedScreen(
                            customVideos: videos,
                            initialIndex: index,
                            title: tab.feedSource?.title ?? widget.title,
                            onHeaderTap: () {
                              if (tab.feedSource != null) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) => tab.feedSource!.buildReturnScreen(),
                                  ),
                                  (route) => false,
                                );
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                        (route) => false,
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ],
      );
    }

    // If the tab has chains, show the chain grid
    if (tab.chains != null) {
      return ChainGrid(
        chains: tab.chains!,
        isLoading: tab.isLoading,
        errorMessage: tab.errorMessage,
        onChainTap: (chainId) => _handleChainTap(chainId, tab),
      );
    }

    // Otherwise show the video grid
    return VideoGrid(
      videos: tab.videos,
      isLoading: tab.isLoading,
      errorMessage: tab.errorMessage,
      onVideoTap: (videoId) => _handleVideoTap(videoId, tab),
    );
  }
} 