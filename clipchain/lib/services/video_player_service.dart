import 'package:flutter/material.dart';

/// Abstract interface for video player implementations
abstract class VideoPlayerService {
  /// Initialize a video from a URL
  Future<void> initialize(String url);
  
  /// Play the video
  Future<void> play();
  
  /// Pause the video
  Future<void> pause();
  
  /// Seek to a specific position
  Future<void> seekTo(Duration position);
  
  /// Set whether the video should loop
  Future<void> setLooping(bool looping);
  
  /// Get the video duration
  Duration? get duration;
  
  /// Get the current position
  Duration get position;
  
  /// Check if the video is playing
  bool get isPlaying;
  
  /// Check if the video is initialized
  bool get isInitialized;
  
  /// Get the video aspect ratio
  double get aspectRatio;
  
  /// Clean up resources
  Future<void> dispose();
  
  /// Build the video player widget
  Widget buildPlayer();
  
  /// Add a listener for video player events
  void addListener(VoidCallback listener);
  
  /// Remove a listener
  void removeListener(VoidCallback listener);
}

/// Factory for creating video player services
abstract class VideoPlayerFactory {
  VideoPlayerService createPlayer();
} 