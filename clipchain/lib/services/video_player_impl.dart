import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'video_player_service.dart';

class DefaultVideoPlayerService implements VideoPlayerService {
  VideoPlayerController? _controller;
  
  @override
  Future<void> initialize(String url) async {
    await dispose(); // Clean up any existing controller
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller!.initialize();
    print('Video player initialized: ${_controller?.value.isInitialized}');
    print('Video duration: ${_controller?.value.duration}');
  }
  
  @override
  Future<void> play() async {
    print('Playing video');
    if (_controller?.value.isInitialized ?? false) {
      await _controller?.play();
      print('Video is playing: ${_controller?.value.isPlaying}');
    } else {
      print('Cannot play - video not initialized');
    }
  }
  
  @override
  Future<void> pause() async {
    print('Pausing video');
    if (_controller?.value.isInitialized ?? false) {
      await _controller?.pause();
      print('Video is paused: ${!(_controller?.value.isPlaying ?? true)}');
    }
  }
  
  @override
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }
  
  @override
  Future<void> setLooping(bool looping) async {
    await _controller?.setLooping(looping);
  }
  
  @override
  Duration? get duration => _controller?.value.duration;
  
  @override
  Duration get position => _controller?.value.position ?? Duration.zero;
  
  @override
  bool get isPlaying => _controller?.value.isPlaying ?? false;
  
  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  
  @override
  double get aspectRatio => _controller?.value.aspectRatio ?? 16 / 9;
  
  @override
  Future<void> dispose() async {
    print('Disposing video player');
    await _controller?.dispose();
    _controller = null;
  }
  
  @override
  Widget buildPlayer() {
    if (_controller == null || !isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
  
  @override
  void addListener(VoidCallback listener) {
    _controller?.addListener(listener);
  }
  
  @override
  void removeListener(VoidCallback listener) {
    _controller?.removeListener(listener);
  }
}

class DefaultVideoPlayerFactory implements VideoPlayerFactory {
  @override
  VideoPlayerService createPlayer() => DefaultVideoPlayerService();
} 