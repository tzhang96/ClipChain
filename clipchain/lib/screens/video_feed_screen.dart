import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/likes_provider.dart';
import '../providers/video_player_provider.dart';
import '../models/video_model.dart';
import '../services/cloudinary_service.dart';
import '../types/firestore_types.dart';
import '../widgets/video_player_widget.dart';
import 'profile_screen.dart';
import '../widgets/video_grid_view.dart';
import 'home_screen.dart';
import '../widgets/authenticated_view.dart';
import '../widgets/add_to_chain_sheet.dart';
import 'create_chain_screen.dart';

class VideoFeedScreen extends StatefulWidget {
  final List<VideoDocument>? customVideos;
  final int initialIndex;
  final String? title;
  final String? initialVideoId;
  final VoidCallback? onHeaderTap;
  final Widget Function(BuildContext context, VoidCallback onTap)? headerBuilder;

  const VideoFeedScreen({
    super.key,
    this.customVideos,
    this.initialIndex = 0,
    this.title,
    this.initialVideoId,
    this.onHeaderTap,
    this.headerBuilder,
  });

  @override
  State<VideoFeedScreen> createState() => VideoFeedScreenState();
}

class VideoFeedScreenState extends State<VideoFeedScreen> {
  static const _navigationTimeout = Duration(seconds: 5);

  final PageController _pageController = PageController();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _isNavigating = false;
  Timer? _navigationTimer;

  List<VideoDocument> get _videos => widget.customVideos ?? context.read<VideoProvider>().videos;

  @override
  void initState() {
    super.initState();
    print('VideoFeedScreen: initState called');
    // Schedule initialization after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFirstVideo();
      // Load likes for current user
      final userId = context.read<AuthProvider>().user?.uid;
      if (userId != null) {
        context.read<LikesProvider>().loadUserLikes(userId);
      }
    });
  }

  Future<void> _initializeFirstVideo() async {
    if (!mounted) return;
    
    if (widget.customVideos == null) {
      final videoProvider = context.read<VideoProvider>();
      if (videoProvider.videos.isEmpty) {
        await videoProvider.fetchVideos();
      }
    }

    if (mounted && _videos.isNotEmpty) {
      // Initialize at the specified initial index
      final initialIndex = widget.initialIndex.clamp(0, _videos.length - 1);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(initialIndex);
      }
      await _initializeVideo(initialIndex);
    }
  }

  @override
  void dispose() {
    print('VideoFeedScreen: dispose called');
    _navigationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo(int index) async {
    if (!mounted) return;

      if (index < 0 || index >= _videos.length) {
        print('VideoFeedScreen: Invalid video index: $index');
        return;
      }

      final video = _videos[index];
      String videoUrl = _cloudinaryService.getOptimizedVideoUrl(video.videoUrl);
      print('VideoFeedScreen: Optimized URL: $videoUrl');

    // Initialize video in provider
    await context.read<VideoPlayerProvider>().initializeVideo(video.id, videoUrl);
  }

  void _onPageChanged(int index) async {
    print('VideoFeedScreen: Page changed to index $index');
    if (!_isNavigating) {  // Only handle page changes from user scrolling
      await _initializeVideo(index);
    }
  }

  void _startNavigationTimeout() {
    _navigationTimer?.cancel();
    _navigationTimer = Timer(_navigationTimeout, () {
      _isNavigating = false;
    });
  }

  // Navigate to a specific video by ID
  void navigateToVideo(String videoId) async {
    print('VideoFeedScreen: Navigating to video $videoId');
    final videoProvider = context.read<VideoProvider>();
    final index = videoProvider.videos.indexWhere((v) => v.id == videoId);
    
    if (index != -1) {
      _isNavigating = true;
      _startNavigationTimeout();
      
      try {
        // Initialize video first
        await _initializeVideo(index);
        // Then update page position
        if (_pageController.hasClients) {
          await _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } finally {
        _isNavigating = false;
        _navigationTimer?.cancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('VideoFeedScreen: Building with title: ${widget.title}');
    print('VideoFeedScreen: Has header tap handler: ${widget.onHeaderTap != null}');
    
    final content = Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<VideoProvider>(
        builder: (context, videoProvider, child) {
          print('VideoFeedScreen: Building content');
          
          if (videoProvider.isLoadingFeed) {
            print('VideoFeedScreen: Showing loading state');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading videos...', style: TextStyle(color: Colors.white)),
                ],
              ),
            );
          }

          if (videoProvider.feedError != null) {
            print('VideoFeedScreen: Showing error state: ${videoProvider.feedError}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(videoProvider.feedError!, style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => videoProvider.fetchVideos(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (videoProvider.videos.isEmpty) {
            print('VideoFeedScreen: Showing empty state');
            return const Center(
              child: Text('No videos available', style: TextStyle(color: Colors.white)),
            );
          }

          print('VideoFeedScreen: Building video feed with ${videoProvider.videos.length} videos');
          if (widget.title != null) {
            print('VideoFeedScreen: Adding header with title: ${widget.title}');
          }
          
          return Stack(
            children: [
              PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  
                  return Stack(
                      fit: StackFit.expand,
                      children: [
                      const VideoPlayerWidget(),
                        
                        // Video Info Overlay
                        Positioned(
                          bottom: 80,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User Info Row
                              Consumer<UserProvider>(
                                builder: (context, userProvider, child) {
                                  final user = userProvider.getUser(video.userId);
                                  
                                  // Fetch user data if not available
                                  if (user == null && !userProvider.isLoading(video.userId)) {
                                    // Schedule the fetch after the current build
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        userProvider.fetchUser(video.userId);
                                      }
                                    });
                                  }

                                return Row(
                                  children: [
                                    GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (context) => ProfileScreen(userId: video.userId),
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
                                      ],
                                    ),
                                    ),
                                  ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                video.description,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Consumer2<AuthProvider, LikesProvider>(
                                builder: (context, authProvider, likesProvider, child) {
                                  final userId = authProvider.user?.uid;
                                  final isLiked = userId != null && 
                                      likesProvider.isVideoLiked(userId, video.id);

                                  return Row(
                                    children: [
                                    // Like Button
                                    IconButton(
                                      icon: Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: isLiked ? Colors.red : Colors.white,
                                      ),
                                      onPressed: userId == null
                                          ? null
                                          : () => likesProvider.toggleLike(userId, video.id),
                                    ),
                                      Text(
                                        '${video.likes}',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      const SizedBox(width: 16),
                                    // Add to Chain Button
                                    if (userId != null && userId != video.userId)
                                      IconButton(
                                        icon: const Icon(Icons.playlist_add, color: Colors.white),
                                        onPressed: () {
                                          showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                            builder: (context) => Padding(
                                              padding: EdgeInsets.only(
                                                bottom: MediaQuery.of(context).viewInsets.bottom,
                                              ),
                                                child: AddToChainSheet(
                                                  videoId: video.id,
                                                  userId: userId,
                                                ),
                                              ),
                                            );
                                        },
                                      ),
                                    // Create Chain Button
                                    if (userId != null && userId == video.userId)
                                      IconButton(
                                        icon: const Icon(Icons.playlist_add, color: Colors.white),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => CreateChainScreen(
                                                initialVideoId: video.id,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    if (userId != null && userId == video.userId)
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.white),
                                        color: Colors.white,
                                        onSelected: (value) async {
                                          if (value == 'delete') {
                                            // Show confirmation dialog
                                            final shouldDelete = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete Video'),
                                                content: const Text(
                                                  'Are you sure you want to delete this video?\n\n'
                                                  'This will:\n'
                                                  '• Delete the video permanently\n'
                                                  '• Remove all likes on this video\n'
                                                  '• Remove it from all chains\n\n'
                                                  'This action cannot be undone.'
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.red,
                                                    ),
                                                    onPressed: () => Navigator.of(context).pop(true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (shouldDelete == true) {
                                              try {
                                                // Show loading indicator
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (context) => const Center(
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                );

                                                // Delete the video
                                                await context.read<VideoProvider>().deleteVideo(video.id);

                                                // Dismiss loading indicator
                                                Navigator.of(context).pop();

                                                // Show success message
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Video deleted successfully'),
                                                    ),
                                                  );
                                                }

                                                // Handle navigation
                                                if (_videos.isEmpty) {
                                                  // If no videos left, navigate to profile
                                                  if (mounted) {
                                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                                      '/profile',
                                                      (route) => false,
                                                    );
                                                  }
                                                } else {
                                                  // Move to next video if available
                                                  final currentIndex = _pageController.page?.round() ?? 0;
                                                  if (currentIndex < _videos.length - 1) {
                                                    await _pageController.animateToPage(
                                                      currentIndex + 1,
                                                      duration: const Duration(milliseconds: 300),
                                                      curve: Curves.easeInOut,
                                                    );
                                                  } else if (currentIndex > 0) {
                                                    await _pageController.animateToPage(
                                                      currentIndex - 1,
                                                      duration: const Duration(milliseconds: 300),
                                                      curve: Curves.easeInOut,
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                // Dismiss loading indicator
                                                Navigator.of(context).pop();

                                                // Show error message
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Error deleting video: $e'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          const PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(color: Colors.red),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                  );
                },
              ),

              // Header (if provided)
              if (widget.title != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: widget.onHeaderTap,
                    behavior: HitTestBehavior.opaque,
                    child: widget.headerBuilder?.call(context, widget.onHeaderTap ?? () {}) ??
                      Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.grid_view,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return AuthenticatedView(
      selectedIndex: 0, // Feed is always index 0
      body: content,
    );
  }
} 