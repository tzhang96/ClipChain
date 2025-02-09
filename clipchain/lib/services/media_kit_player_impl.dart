import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'video_player_service.dart';

class MediaKitVideoPlayerService implements VideoPlayerService {
  Player? _player;
  VideoController? _controller;
  
  @override
  Future<void> initialize(String url) async {
    await dispose(); // Clean up any existing player
    
    // Create a new player instance
    _player = Player();
    // Create a video controller
    _controller = VideoController(_player!);
    // Open the media
    await _player!.open(Media(url));
    
    print('MediaKit player initialized');
    print('Video duration: ${_player?.state.duration}');
  }
  
  @override
  Future<void> play() async {
    print('Playing video with MediaKit');
    await _player?.play();
    print('Video is playing: ${_player?.state.playing}');
  }
  
  @override
  Future<void> pause() async {
    print('Pausing video with MediaKit');
    await _player?.pause();
    print('Video is paused: ${!(_player?.state.playing ?? true)}');
  }
  
  @override
  Future<void> seekTo(Duration position) async {
    await _player?.seek(position);
  }
  
  @override
  Future<void> setLooping(bool looping) async {
    if (_player != null) {
      _player!.setPlaylistMode(looping ? PlaylistMode.loop : PlaylistMode.none);
    }
  }
  
  @override
  Duration? get duration => _player?.state.duration;
  
  @override
  Duration get position => _player?.state.position ?? Duration.zero;
  
  @override
  bool get isPlaying => _player?.state.playing ?? false;
  
  @override
  bool get isInitialized => _player != null && _controller != null;
  
  @override
  double get aspectRatio {
    // Default to 16:9 if no video dimensions available
    return 16 / 9;
  }
  
  @override
  Future<void> dispose() async {
    print('Disposing MediaKit player');
    _controller = null; // VideoController is disposed with Player
    await _player?.dispose();
    _player = null;
  }
  
  @override
  Widget buildPlayer() {
    if (_controller == null || !isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Video(
      controller: _controller!,
      controls: null, // No controls
      fill: Colors.black,
    );
  }
  
  @override
  void addListener(VoidCallback listener) {
    _player?.stream.playing.listen((_) => listener());
    _player?.stream.position.listen((_) => listener());
    _player?.stream.completed.listen((_) => listener());
  }
  
  @override
  void removeListener(VoidCallback listener) {
    // MediaKit handles cleanup automatically when the player is disposed
  }
}

class MediaKitVideoPlayerFactory implements VideoPlayerFactory {
  @override
  VideoPlayerService createPlayer() => MediaKitVideoPlayerService();
} 