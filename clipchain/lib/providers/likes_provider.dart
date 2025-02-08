import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../types/firestore_types.dart';
import 'video_provider.dart';

class LikesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  VideoProvider? _videoProvider;
  
  // Cache of liked video IDs for each user
  Map<String, Set<String>> _userLikes = {}; // userId -> Set of videoIds
  
  // Loading states
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void initialize(VideoProvider videoProvider) {
    if (_videoProvider != null) return; // Prevent re-initialization
    _videoProvider = videoProvider;
  }

  /// Clear all cached data
  void clear() {
    _userLikes.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Check if a video is liked by a user
  bool isVideoLiked(String userId, String videoId) {
    return _userLikes[userId]?.contains(videoId) ?? false;
  }

  /// Toggle like status for a video
  Future<void> toggleLike(String userId, String videoId) async {
    if (_videoProvider == null) return;  // Guard against uninitialized provider
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoading = true;
        _error = null;
        notifyListeners();
      });

      final isLiked = isVideoLiked(userId, videoId);
      
      if (isLiked) {
        // Unlike
        await _firestore
            .collection(FirestorePaths.likes)
            .where('userId', isEqualTo: userId)
            .where('videoId', isEqualTo: videoId)
            .get()
            .then((snapshot) {
          return Future.wait(
            snapshot.docs.map((doc) => doc.reference.delete()),
          );
        });

        // Update video likes count
        await _firestore
            .collection(FirestorePaths.videos)
            .doc(videoId)
            .update({'likes': FieldValue.increment(-1)});

        // Schedule state update
        Future.microtask(() {
          _userLikes[userId]?.remove(videoId);
          _isLoading = false;
          notifyListeners();
        });

      } else {
        // Like
        await _firestore
            .collection(FirestorePaths.likes)
            .add({
              'userId': userId,
              'videoId': videoId,
              'createdAt': Timestamp.now(),
            });

        // Update video likes count
        await _firestore
            .collection(FirestorePaths.videos)
            .doc(videoId)
            .update({'likes': FieldValue.increment(1)});

        // Schedule state update
        Future.microtask(() {
          _userLikes.putIfAbsent(userId, () => {}).add(videoId);
          _isLoading = false;
          notifyListeners();
        });
      }

    } catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _error = 'Failed to toggle like: $e';
        _isLoading = false;
        notifyListeners();
      });
    }
  }

  /// Load liked videos for a user
  Future<void> loadUserLikes(String userId) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoading = true;
        _error = null;
        notifyListeners();
      });

      final QuerySnapshot likesSnapshot = await _firestore
          .collection(FirestorePaths.likes)
          .where('userId', isEqualTo: userId)
          .get();

      final likes = likesSnapshot.docs
          .map((doc) => doc.get('videoId') as String)
          .toSet();

      // Schedule state update after async complete
      Future.microtask(() {
        _userLikes[userId] = likes;
        _isLoading = false;
        notifyListeners();
      });

    } catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _error = 'Failed to load likes: $e';
        _isLoading = false;
        notifyListeners();
      });
    }
  }

  /// Get all liked video IDs for a user
  Set<String> getLikedVideoIds(String userId) {
    return _userLikes[userId] ?? {};
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
} 