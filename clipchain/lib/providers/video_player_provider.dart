import 'package:flutter/foundation.dart';
import '../services/video_player_service.dart';
import '../services/video_player_impl.dart';

class VideoPlayerProvider with ChangeNotifier {
  final VideoPlayerFactory _factory;
  VideoPlayerService? _currentPlayer;
  bool _isInitializing = false;
  String? _error;
  String? _currentVideoId;
  
  VideoPlayerProvider({VideoPlayerFactory? factory}) 
    : _factory = factory ?? DefaultVideoPlayerFactory();
  
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  bool get isPlaying => _currentPlayer?.isPlaying ?? false;
  bool get isInitialized => _currentPlayer?.isInitialized ?? false;
  String? get currentVideoId => _currentVideoId;
  
  Future<void> initializeVideo(String videoId, String videoUrl) async {
    if (_isInitializing) return;
    
    try {
      _isInitializing = true;
      _error = null;
      notifyListeners();
      
      // Clean up existing player
      await _cleanupCurrentPlayer();
      
      // Create and initialize new player
      _currentPlayer = _factory.createPlayer();
      await _currentPlayer!.initialize(videoUrl);
      await _currentPlayer!.setLooping(true);
      _currentVideoId = videoId;
      
      // Start playing immediately after initialization
      await _currentPlayer!.play();
      
      notifyListeners();
      
    } catch (e) {
      _error = 'Failed to initialize video: $e';
      await _cleanupCurrentPlayer();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }
  
  Future<void> _cleanupCurrentPlayer() async {
    if (_currentPlayer != null) {
      await _currentPlayer!.pause();
      await _currentPlayer!.dispose();
      _currentPlayer = null;
      _currentVideoId = null;
    }
  }
  
  Future<void> togglePlayPause() async {
    if (_currentPlayer == null) return;
    
    if (_currentPlayer!.isPlaying) {
      await _currentPlayer!.pause();
    } else {
      await _currentPlayer!.play();
    }
    notifyListeners();
  }
  
  VideoPlayerService? get currentPlayer => _currentPlayer;
  
  @override
  void dispose() {
    _cleanupCurrentPlayer();
    super.dispose();
  }
} 