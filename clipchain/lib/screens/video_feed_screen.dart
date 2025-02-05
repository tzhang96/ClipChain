import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../services/cloudinary_service.dart';
import '../providers/auth_provider.dart';

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
  static const _pageSize = 10;
  static const _navigationTimeout = Duration(seconds: 5);

  final PageController _pageController = PageController();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _isInitializing = false; // Simple lock for initialization

  List<VideoModel> _videos = [];
  CurrentVideoState? _currentVideo;
  bool _isLoading = true;
  bool _isVideoInitializing = false;
  String? _loadingError;
  StreamSubscription<QuerySnapshot>? _videosSubscription;
  bool _isNavigating = false;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    print('VideoFeedScreen: initState called');
    _subscribeToVideos();
  }

  void _subscribeToVideos() {
    print('VideoFeedScreen: Starting video subscription...');
    _videosSubscription = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .snapshots()
        .listen(
      (snapshot) async {
        print('VideoFeedScreen: Received video update. Found ${snapshot.docs.length} videos');
        
        if (!mounted) {
          print('VideoFeedScreen: Widget not mounted after update');
          return;
        }

        final newVideos = snapshot.docs
            .map((doc) {
              try {
                return VideoModel.fromMap(
                    {...doc.data() as Map<String, dynamic>, 'id': doc.id});
              } catch (e) {
                print('VideoFeedScreen: Error parsing video document: $e');
                return null;
              }
            })
            .where((video) => video != null)
            .cast<VideoModel>()
            .toList();

        setState(() {
          _videos = newVideos;
          _isLoading = false;
        });

        // Initialize first video if needed
        if (_currentVideo == null && _videos.isNotEmpty) {
          print('VideoFeedScreen: Initializing first video...');
          await _initializeVideo(0);
        }
      },
      onError: (error) {
        print('VideoFeedScreen: Error in video subscription: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingError = _getErrorMessage(error);
          });
        }
      },
    );
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      return 'Firebase error: ${error.message}';
    }
    if (error is PlatformException) {
      return 'Video playback error: ${error.message}';
    }
    return 'Error: ${error.toString()}';
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
    // Simple lock implementation
    if (_isInitializing) {
      print('VideoFeedScreen: Video initialization already in progress');
      return;
    }
    _isInitializing = true;

    try {
      if (_isVideoInitializing || index < 0 || index >= _videos.length) {
        print('VideoFeedScreen: Skipping video initialization - invalid state');
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

  @override
  void dispose() {
    print('VideoFeedScreen: dispose called');
    _navigationTimer?.cancel();
    _videosSubscription?.cancel();
    _pageController.dispose();
    _cleanupCurrentVideo();
    super.dispose();
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
    final index = _videos.indexWhere((v) => v.id == videoId);
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
    if (_isLoading) {
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
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadingError = null;
                });
                _subscribeToVideos();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Center(child: Text('No videos available'));
    }

    return PageView.builder(
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
                child: Column(
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 