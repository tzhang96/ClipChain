import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
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
import '../widgets/add_to_chain_sheet.dart';
import 'create_chain_screen.dart';

/// Represents the current video state with improved caching and hardware decoder management
class CurrentVideoState {
  static const int maxHardwareDecoders = 2;  // Limit concurrent hardware decoders
  static int activeDecoders = 0;  // Track active hardware decoders
  static bool _canUseHardwareDecoder = true;  // Global hardware decoder capability flag

  final int index;
  final String id;
  final VideoPlayerController controller;
  bool isInitialized = false;
  bool hasError = false;
  String? errorMessage;
  bool _isUsingHardwareDecoder = false;

  CurrentVideoState({
    required this.index,
    required this.id,
    required this.controller,
  });

  static Future<void> checkDeviceCapabilities() async {
    try {
      // Check for known problematic GPUs
      final renderer = await SystemChannels.skia.invokeMethod('getRenderer') as String;
      if (renderer.contains('PowerVR') || renderer.contains('Mali-G31')) {
        _canUseHardwareDecoder = false;
        print('Forcing software decoding due to problematic GPU: $renderer');
      }
    } catch (e) {
      print('Error checking GPU capabilities: $e');
    }
  }

  Future<void> initialize() async {
    if (isInitialized) return;
    try {
      if (_canUseHardwareDecoder && activeDecoders < maxHardwareDecoders) {
        activeDecoders++;
        _isUsingHardwareDecoder = true;
        await controller.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Video initialization timed out');
          },
        );
      } else {
        // Force software decoder
        _isUsingHardwareDecoder = false;
        await controller.initialize();
      }
      isInitialized = true;
      controller.setLooping(true);
    } catch (e) {
      if (_isUsingHardwareDecoder) {
        // If hardware decoder fails, try software decoder
        _isUsingHardwareDecoder = false;
        activeDecoders--;
        controller.dispose();
        hasError = false;
        errorMessage = null;
        // Retry with software decoder will be handled by the parent widget
      } else {
        hasError = true;
        errorMessage = e.toString();
        print('Error initializing video: $e');
      }
    }
  }

  void dispose() {
    if (_isUsingHardwareDecoder) {
      activeDecoders--;
    }
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

class VideoFeedScreenState extends State<VideoFeedScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const _navigationTimeout = Duration(seconds: 5);
  final int _preloadDistance = kIsWeb ? 2 : 1; // Removed const since kIsWeb is not const

  final PageController _pageController = PageController();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final Map<int, CurrentVideoState> _videoCache = {};
  
  bool _isInitializing = false;
  String? _loadingError;
  bool _isNavigating = false;
  Timer? _navigationTimer;
  int _currentIndex = 0;
  bool _showVideo = true;
  NetworkImage? _fallbackImage;

  List<VideoDocument> get _videos => widget.customVideos ?? context.read<VideoProvider>().videos;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('VideoFeedScreen: initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await CurrentVideoState.checkDeviceCapabilities();
      _initializeFirstVideo();
    });
  }

  @override
  void dispose() {
    print('VideoFeedScreen: dispose called');
    WidgetsBinding.instance.removeObserver(this);
    _navigationTimer?.cancel();
    _cleanupCache();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background - pause video and release resources
      final currentVideo = _videoCache[_currentIndex];
      if (currentVideo?.controller.value.isPlaying ?? false) {
        currentVideo?.controller.pause();
      }
      _handleMemoryPressure();
    }
  }

  void _handleMemoryPressure() {
    // Keep only the current video and one adjacent video in each direction
    final keysToKeep = <int>{
      _currentIndex,
      _currentIndex - 1,
      _currentIndex + 1,
    };

    _videoCache.removeWhere((index, video) {
      if (!keysToKeep.contains(index)) {
        video.dispose();
        return true;
      }
      return false;
    });
  }

  void _cleanupCache() {
    for (var video in _videoCache.values) {
      video.dispose();
    }
    _videoCache.clear();
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
      final initialIndex = widget.initialIndex.clamp(0, _videos.length - 1);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(initialIndex);
      }
      await _preloadVideos(initialIndex);
    }
  }

  Future<void> _preloadVideos(int centerIndex) async {
    final start = (centerIndex - _preloadDistance).clamp(0, _videos.length - 1);
    final end = (centerIndex + _preloadDistance).clamp(0, _videos.length - 1);

    for (var i = start; i <= end; i++) {
      if (!_videoCache.containsKey(i)) {
        await _initializeVideo(i, autoplay: i == centerIndex);
      }
    }

    // Cleanup videos outside preload range
    _videoCache.removeWhere((index, video) {
      if (index < start || index > end) {
        video.dispose();
        return true;
      }
      return false;
    });
  }

  Future<void> _initializeVideo(int index, {bool autoplay = false}) async {
    if (_isInitializing || index < 0 || index >= _videos.length) return;
    
    _isInitializing = true;
    try {
      final video = _videos[index];
      print('VideoFeedScreen: Initializing video at index $index with ID: ${video.id}');
      
      String videoUrl = _cloudinaryService.getOptimizedVideoUrl(video.videoUrl);
      print('VideoFeedScreen: Optimized URL: $videoUrl');

      // Create fallback image URL first
      final fallbackImageUrl = videoUrl
        .replaceAll('/video/upload/', '/image/upload/')
        .replaceAll('.mp4', '.jpg');
      print('VideoFeedScreen: Fallback image URL: $fallbackImageUrl');

      // Pre-load fallback image
      _fallbackImage = NetworkImage(fallbackImageUrl);
      
      try {
        print('VideoFeedScreen: Attempting to initialize video controller');
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );

        // Set a shorter timeout for initialization
        await controller.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('VideoFeedScreen: Video initialization timed out');
            throw TimeoutException('Video initialization timed out');
          },
        );

        print('VideoFeedScreen: Video controller initialized successfully');
        
        if (mounted) {
          setState(() {
            _showVideo = true;
            _videoCache[index] = CurrentVideoState(
              index: index,
              id: video.id,
              controller: controller,
            );
          });

          if (autoplay) {
            print('VideoFeedScreen: Starting autoplay');
            await controller.play();
          }
        }
      } catch (e) {
        print('VideoFeedScreen: Failed to initialize video: $e');
        // Fallback to static image
        if (mounted) {
          setState(() {
            _showVideo = false;
          });
        }
      }

    } catch (e) {
      print('VideoFeedScreen: Error in _initializeVideo: $e');
    } finally {
      _isInitializing = false;
    }
  }

  void _onPageChanged(int index) async {
    if (_isNavigating) return;
    
    setState(() => _currentIndex = index);
    
    // Pause previous video
    final previousVideo = _videoCache[_currentIndex - 1];
    if (previousVideo?.controller.value.isPlaying ?? false) {
      await previousVideo?.controller.pause();
    }

    // Play current video
    final currentVideo = _videoCache[index];
    if (currentVideo?.isInitialized ?? false) {
      await currentVideo?.controller.play();
    }

    // Preload adjacent videos
    await _preloadVideos(index);
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

  void _startNavigationTimeout() {
    _navigationTimer?.cancel();
    _navigationTimer = Timer(_navigationTimeout, () {
      _isNavigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    print('VideoFeedScreen: Building with title: ${widget.title}');
    print('VideoFeedScreen: Has header tap handler: ${widget.onHeaderTap != null}');
    
    final content = Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<VideoProvider>(
        builder: (context, videoProvider, child) {
          if (videoProvider.isLoadingFeed) {
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

          if (_videos.isEmpty) {
            return const Center(
              child: Text('No videos available', style: TextStyle(color: Colors.white)),
            );
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
                  final videoState = _videoCache[index];
                  
                  return Container(
                    key: ValueKey(video.id),
                    color: Colors.black,
                    child: GestureDetector(
                      onTap: () {
                        if (videoState?.controller.value.isPlaying ?? false) {
                          videoState?.controller.pause();
                        } else {
                          videoState?.controller.play();
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (videoState?.isInitialized ?? false)
                            _showVideo 
                              ? VideoPlayer(videoState!.controller)
                              : (_fallbackImage != null 
                                  ? Image(image: _fallbackImage!, fit: BoxFit.cover)
                                  : const Center(child: CircularProgressIndicator()))
                          else if (videoState?.hasError ?? false)
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error loading video: ${videoState?.errorMessage}',
                                    style: const TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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
      selectedIndex: 0,
      body: content,
    );
  }
} 