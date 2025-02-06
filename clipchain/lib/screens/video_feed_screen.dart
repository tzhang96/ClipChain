import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../providers/user_provider.dart';
import '../models/video_model.dart';
import '../services/cloudinary_service.dart';
import '../types/firestore_types.dart';
import 'profile_screen.dart';

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
  const VideoFeedScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    print('VideoFeedScreen: initState called');
    // Schedule initialization after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFirstVideo();
    });
  }

  Future<void> _initializeFirstVideo() async {
    if (!mounted) return;
    
    final videoProvider = context.read<VideoProvider>();
    if (videoProvider.videos.isEmpty) {
      await videoProvider.fetchVideos();
    }
    if (mounted && videoProvider.videos.isNotEmpty) {
      await _initializeVideo(0);
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

      final videoProvider = context.read<VideoProvider>();
      if (index < 0 || index >= videoProvider.videos.length) {
        print('VideoFeedScreen: Invalid video index: $index');
        return;
      }

      print('VideoFeedScreen: Starting video initialization for index $index');
      setState(() => _isVideoInitializing = true);

      await _cleanupCurrentVideo();

      final video = videoProvider.videos[index];
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
    return Consumer<VideoProvider>(
      builder: (context, videoProvider, child) {
        if (videoProvider.isLoadingFeed) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading videos...'),
              ],
            ),
          );
        }

        if (videoProvider.feedError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(videoProvider.feedError!),
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
          return const Center(child: Text('No videos available'));
        }

        return PageView.builder(
          scrollDirection: Axis.vertical,
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: videoProvider.videos.length,
          itemBuilder: (context, index) {
            final video = videoProvider.videos[index];
            
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(userId: video.userId),
                                  ),
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
                        Row(
                          children: [
                            const Icon(Icons.favorite, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${video.likes}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
} 