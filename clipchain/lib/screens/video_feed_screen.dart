import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/likes_provider.dart';
import '../models/video_model.dart';
import '../services/cloudinary_service.dart';
import '../types/firestore_types.dart';
import 'profile_screen.dart';
import '../widgets/video_grid_view.dart';
import 'home_screen.dart';
import '../widgets/authenticated_view.dart';

/// Represents the current video state
class CurrentVideoState {
  final int index;
  final String id;
  final VideoPlayerController controller;

  const CurrentVideoState({
    required this.index,
    required this.id,
    required this.controller,
  });

  void dispose() {
    controller.dispose();
  }
}

class VideoFeedScreen extends StatefulWidget {
  final List<VideoDocument>? customVideos;
  final int initialIndex;
  final String? title;
  final String? initialVideoId;
  final VoidCallback? onHeaderTap;

  const VideoFeedScreen({
    super.key,
    this.customVideos,
    this.initialIndex = 0,
    this.title,
    this.initialVideoId,
    this.onHeaderTap,
  });

  @override
  State<VideoFeedScreen> createState() => VideoFeedScreenState();
}

class VideoFeedScreenState extends State<VideoFeedScreen> {
  static const _navigationTimeout = Duration(seconds: 5);

  final PageController _pageController = PageController();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _isInitializing = false;

  CurrentVideoState? _currentVideo;
  bool _isVideoInitializing = false;
  String? _loadingError;
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
    _cleanupCurrentVideo();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cleanupCurrentVideo() async {
    final current = _currentVideo;
    if (current != null) {
      print('VideoFeedScreen: Cleaning up video at index ${current.index}');
      await current.controller.pause();
      current.dispose();
      if (mounted) {
        setState(() => _currentVideo = null);
      }
    }
  }

  Future<void> _initializeVideo(int index) async {
    if (_isInitializing) {
      print('VideoFeedScreen: Video initialization already in progress');
      return;
    }
    _isInitializing = true;

    try {
      if (_isVideoInitializing) {
        print('VideoFeedScreen: Skipping video initialization - already initializing');
        return;
      }

      if (index < 0 || index >= _videos.length) {
        print('VideoFeedScreen: Invalid video index: $index');
        return;
      }

      print('VideoFeedScreen: Starting video initialization for index $index');
      setState(() => _isVideoInitializing = true);

      await _cleanupCurrentVideo();

      final video = _videos[index];
      String videoUrl = _cloudinaryService.getOptimizedVideoUrl(video.videoUrl);
      print('VideoFeedScreen: Optimized URL: $videoUrl');

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      controller.setLooping(true);
      
      if (mounted) {
        setState(() {
          _currentVideo = CurrentVideoState(
            index: index,
            id: video.id,
            controller: controller,
          );
          _isVideoInitializing = false;
        });
        
        // Only play if this is still the current page
        if (_currentVideo?.index == index) {
          print('VideoFeedScreen: Playing video at index $index');
          controller.play();
        }
      }
    } catch (e) {
      print('VideoFeedScreen: Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isVideoInitializing = false;
          _loadingError = _getErrorMessage(e);
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is PlatformException) {
      return 'Video playback error: ${error.message}';
    }
    return 'Error: ${error.toString()}';
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
                  
                  return GestureDetector(
                    onTap: () {
                      if (_currentVideo?.controller.value.isPlaying ?? false) {
                        _currentVideo?.controller.pause();
                      } else {
                        _currentVideo?.controller.play();
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_currentVideo?.controller != null &&
                            _currentVideo?.index == index &&
                            _currentVideo!.controller.value.isInitialized)
                          VideoPlayer(_currentVideo!.controller)
                        else
                          const Center(child: CircularProgressIndicator()),
                        
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

                                  return GestureDetector(
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
                                          radius: 20,
                                          backgroundImage: user?.photoUrl != null
                                              ? NetworkImage(user!.photoUrl!)
                                              : null,
                                          child: user?.photoUrl == null
                                              ? const Icon(Icons.person)
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          user?.username ?? 'Loading...',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                      GestureDetector(
                                        onTap: userId == null ? null : () {
                                          likesProvider.toggleLike(userId, video.id);
                                        },
                                        child: Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: isLiked ? Colors.red : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${video.likes}',
                                        style: const TextStyle(color: Colors.white),
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
                  );
                },
              ),
              if (widget.title != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      print('VideoFeedScreen: Header tapped');
                      if (widget.onHeaderTap != null) {
                        print('VideoFeedScreen: Calling onHeaderTap handler');
                        widget.onHeaderTap!();
                      } else {
                        print('VideoFeedScreen: No onHeaderTap handler provided');
                        Navigator.of(context).pop();
                      }
                    },
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