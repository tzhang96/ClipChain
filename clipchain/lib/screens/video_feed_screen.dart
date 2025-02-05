import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/video_model.dart';
import '../services/cloudinary_service.dart';
import '../providers/auth_provider.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => VideoFeedScreenState();
}

class VideoFeedScreenState extends State<VideoFeedScreen> {
  final PageController _pageController = PageController();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  List<VideoModel> _videos = [];
  int _currentPageIndex = 0;
  VideoPlayerController? _currentController;
  bool _isLoading = true;
  bool _isVideoInitializing = false;
  String? _loadingError;
  StreamSubscription<QuerySnapshot>? _videosSubscription;
  String? _currentVideoId;

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
        .limit(10)
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
        if (_currentController == null && _videos.isNotEmpty) {
          print('VideoFeedScreen: Initializing first video...');
          await _initializeVideo(0);
        }
      },
      onError: (error) {
        print('VideoFeedScreen: Error in video subscription: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingError = 'Error loading videos: ${error.toString()}';
          });
        }
      },
    );
  }

  Future<void> _cleanupCurrentController() async {
    if (_currentController != null) {
      print('VideoFeedScreen: Cleaning up current controller');
      await _currentController!.pause();
      await _currentController!.dispose();
      _currentController = null;
    }
  }

  Future<void> _initializeVideo(int index) async {
    if (_isVideoInitializing || index < 0 || index >= _videos.length) {
      print('VideoFeedScreen: Skipping video initialization - invalid state');
      return;
    }

    print('VideoFeedScreen: Starting video initialization for index $index');
    setState(() => _isVideoInitializing = true);

    try {
      await _cleanupCurrentController();

      // Get optimized video URL
      String videoUrl = _cloudinaryService.getOptimizedVideoUrl(_videos[index].videoUrl);
      print('VideoFeedScreen: Optimized URL: $videoUrl');

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      controller.setLooping(true);
      
      if (mounted) {
        setState(() {
          _currentController = controller;
          _isVideoInitializing = false;
          _currentVideoId = _videos[index].id;
          _currentPageIndex = index;  // Update index here to ensure sync
        });
        
        // Only play if this is still the current page
        if (_currentPageIndex == index) {
          print('VideoFeedScreen: Playing video at index $index');
          _currentController?.play();
        }
      }
    } catch (e) {
      print('VideoFeedScreen: Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isVideoInitializing = false;
          _loadingError = 'Error playing video: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    print('VideoFeedScreen: dispose called');
    _videosSubscription?.cancel();
    _pageController.dispose();
    _cleanupCurrentController();
    super.dispose();
  }

  void _onPageChanged(int index) async {
    print('VideoFeedScreen: Page changed to index $index');
    // Don't update state here to prevent race conditions
    await _initializeVideo(index);
  }

  // Navigate to a specific video by ID
  void navigateToVideo(String videoId) {
    final index = _videos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      _pageController.jumpToPage(index);
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
            if (_currentController?.value.isPlaying ?? false) {
              _currentController?.pause();
            } else {
              _currentController?.play();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_currentController != null &&
                  _currentPageIndex == index &&
                  _currentController!.value.isInitialized)
                VideoPlayer(_currentController!)
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