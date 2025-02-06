import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../services/video_controller_cache.dart';
import '../services/cloudinary_service.dart';
import '../types/firestore_types.dart';

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
  final VideoControllerCache _controllerCache = VideoControllerCache();
  bool _isInitializing = false;
  String? _loadingError;
  bool _isNavigating = false;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    print('VideoFeedScreen: initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeFirstVideo();
      }
    });
  }

  Future<void> _initializeFirstVideo() async {
    if (_isInitializing) {
      print('VideoFeedScreen: Already initializing');
      return;
    }

    setState(() {
      _isInitializing = true;
      _loadingError = null;
    });

    try {
      final videoProvider = context.read<VideoProvider>();
      await videoProvider.fetchVideos();
      
      if (!mounted) return;
      
      if (videoProvider.videos.isNotEmpty) {
        await _controllerCache.setCurrentVideo(
          videoProvider.videos[0].id,
          videoProvider.videos,
        );
      }
    } catch (e) {
      print('VideoFeedScreen: Error initializing first video: $e');
      if (mounted) {
        setState(() {
          _loadingError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    print('VideoFeedScreen: dispose called');
    _navigationTimer?.cancel();
    _controllerCache.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) async {
    print('VideoFeedScreen: Page changed to index $index');
    if (!_isNavigating) {
      final videoProvider = context.read<VideoProvider>();
      final videos = videoProvider.videos;
      if (index >= 0 && index < videos.length) {
        await _controllerCache.setCurrentVideo(videos[index].id, videos);
      }
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
        await _controllerCache.setCurrentVideo(videoId, videoProvider.videos);
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

        if (_loadingError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_loadingError!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeFirstVideo,
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
                final controller = _controllerCache.currentController;
                if (controller?.value.isPlaying ?? false) {
                  controller?.pause();
                } else {
                  controller?.play();
                }
              },
              child: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    // Video Layer
                    Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: _buildVideoLayer(video),
                      ),
                    ),
                    
                    // Info Overlay
                    Positioned(
                      bottom: 80,
                      left: 16,
                      child: VideoInfoOverlay(video: video),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideoLayer(VideoDocument video) {
    final cachedControllers = _controllerCache.controllers;
    final currentController = cachedControllers
        .where((c) => c.position == 0)
        .map((c) => c.controller)
        .firstOrNull;
    
    if (currentController?.value.isInitialized ?? false) {
      return VideoPlayer(currentController!);
    }
    
    // Show thumbnail while video is loading
    return _buildThumbnail(video);
  }

  Widget _buildThumbnail(VideoDocument video) {
    if (video.thumbnailUrl != null) {
      return Image.network(
        video.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.video_library)),
      );
    }
    return const Center(child: Icon(Icons.video_library));
  }
}

class VideoInfoOverlay extends StatelessWidget {
  final VideoDocument video;

  const VideoInfoOverlay({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          video.description,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
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
    );
  }
} 