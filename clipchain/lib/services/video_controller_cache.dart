import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../types/firestore_types.dart';
import 'cloudinary_service.dart';

/// Manages a cache of video controllers to prevent rapid creation/destruction
/// of video textures which can cause visual artifacts on physical devices.
class VideoControllerCache {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  
  // Map of video ID to controller state
  final Map<String, CachedController> _cache = {};
  
  // Maximum number of controllers to keep in memory
  static const int maxCacheSize = 3;
  
  String? _currentVideoId;
  bool _isTransitioning = false;
  bool _isInitialized = false;

  // Add surface preparation lock
  final _surfaceLock = Object();
  
  /// Get all cached controllers
  List<CachedController> get controllers => _cache.values.toList();
  
  /// Get the current active controller
  VideoPlayerController? get currentController {
    if (_currentVideoId == null) return null;
    return _cache[_currentVideoId]?.controller;
  }

  /// Updates the cache for a new current video
  Future<void> setCurrentVideo(String videoId, List<VideoDocument> videos) async {
    if (_isTransitioning) {
      print('VideoControllerCache: Transition already in progress, skipping');
      return;
    }

    try {
      _isTransitioning = true;
      print('VideoControllerCache: Setting current video to $videoId');

      // Ensure proper initialization delay
      if (!_isInitialized) {
        await Future.delayed(const Duration(milliseconds: 1000));
        _isInitialized = true;
      }

      // Calculate which videos should be in cache
      final currentIndex = videos.indexWhere((v) => v.id == videoId);
      if (currentIndex == -1) return;

      final desiredIds = <String>{};
      for (var i = -1; i <= 1; i++) {
        final idx = currentIndex + i;
        if (idx >= 0 && idx < videos.length) {
          desiredIds.add(videos[idx].id);
        }
      }

      // First pause current video if any
      final oldController = currentController;
      if (oldController?.value.isPlaying ?? false) {
        await oldController?.pause();
      }

      // Initialize new controllers with proper surface preparation
      for (final id in desiredIds) {
        if (!_cache.containsKey(id)) {
          final video = videos.firstWhere((v) => v.id == id);
          await _initializeController(id, video);
        }
      }

      // Ensure new controller is ready
      final newController = _cache[videoId]?.controller;
      if (newController == null || !newController.value.isInitialized) {
        print('VideoControllerCache: New controller not ready');
        return;
      }

      // Update positions and ensure proper playback state
      _updatePositions(currentIndex, videos);
      
      // Ensure video is at start and ready to play
      await newController.seekTo(Duration.zero);
      
      // Set volume to 0 initially to prevent audio glitches
      await newController.setVolume(0.0);
      
      // Start playing the new video
      await newController.play();
      
      // Fade in volume
      await Future.delayed(const Duration(milliseconds: 100));
      await newController.setVolume(1.0);

      // Update current video id only after successful transition
      _currentVideoId = videoId;

      // Clean up old controllers
      final idsToRemove = _cache.keys
          .where((id) => !desiredIds.contains(id))
          .toList();

      for (final id in idsToRemove) {
        await _disposeController(id);
      }

    } finally {
      _isTransitioning = false;
    }
  }
  
  Future<void> _initializeController(String videoId, VideoDocument video) async {
    print('VideoControllerCache: Initializing controller for video $videoId');
    
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(_cloudinaryService.getOptimizedVideoUrl(video.videoUrl)),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
      httpHeaders: const {
        'Range': 'bytes=0-',
      },
    );
    
    try {
      // Create cache entry immediately
      _cache[videoId] = CachedController(
        controller: controller,
        lastAccessed: DateTime.now(),
        position: 0,
        isReady: false,
      );
      
      // Initialize with proper surface preparation
      synchronized(_surfaceLock, () async {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0.0);
      });
      
      // Update cache entry
      _cache[videoId] = CachedController(
        controller: controller,
        lastAccessed: DateTime.now(),
        position: 0,
        isReady: true,
      );
      
    } catch (e) {
      print('VideoControllerCache: Failed to initialize controller: $e');
      await controller.dispose();
      _cache.remove(videoId);
      rethrow;
    }
  }
  
  Future<void> _disposeController(String videoId) async {
    print('VideoControllerCache: Disposing controller for video $videoId');
    final cached = _cache[videoId];
    if (cached != null) {
      await cached.controller.pause();
      await cached.controller.dispose();
      _cache.remove(videoId);
    }
  }
  
  void _updatePositions(int currentIndex, List<VideoDocument> videos) {
    for (final entry in _cache.entries) {
      final videoIndex = videos.indexWhere((v) => v.id == entry.key);
      if (videoIndex != -1) {
        final position = videoIndex - currentIndex;
        _cache[entry.key] = CachedController(
          controller: entry.value.controller,
          lastAccessed: DateTime.now(),
          position: position,
          isReady: entry.value.isReady,
        );
        print('VideoControllerCache: Updated position for video ${entry.key} to $position');
      }
    }
  }
  
  /// Dispose all controllers and clear the cache
  Future<void> dispose() async {
    print('VideoControllerCache: Disposing all controllers');
    for (final cached in _cache.values) {
      await cached.controller.pause();
      await cached.controller.dispose();
    }
    _cache.clear();
    _currentVideoId = null;
  }
}

/// Represents a cached video controller with metadata
class CachedController {
  final VideoPlayerController controller;
  final DateTime lastAccessed;
  final int position;  // Relative to current video
  final bool isReady;  // Whether the controller is initialized and ready
  
  const CachedController({
    required this.controller,
    required this.lastAccessed,
    required this.position,
    required this.isReady,
  });
}

// Add synchronized helper
Future<T> synchronized<T>(Object lock, Future<T> Function() computation) async {
  try {
    return await computation();
  } finally {
    // Ensure lock is released
  }
} 