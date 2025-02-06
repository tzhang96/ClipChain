import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../types/firestore_types.dart';
import 'video_provider.dart';

class LikesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final VideoProvider _videoProvider;
  
  // Cache of liked video IDs for each user
  final Map<String, Set<String>> _userLikes = {};
  
  // Loading states
  final Map<String, bool> _loadingStates = {};
  String? _error;

  bool get isLoading => _loadingStates.values.any((loading) => loading);
  String? get error => _error;

  void initialize(VideoProvider videoProvider) {
    _videoProvider = videoProvider;
  }

  /// Check if a video is liked by a user
  bool isVideoLiked(String userId, String videoId) {
    return _userLikes[userId]?.contains(videoId) ?? false;
  }

  /// Toggle like status for a video
  Future<void> toggleLike(String userId, String videoId) async {
    try {
      _loadingStates[videoId] = true;
      _error = null;
      notifyListeners();

      final likeRef = _firestore
          .collection(FirestorePaths.likes)
          .doc('${userId}_${videoId}');
      
      final videoRef = _firestore
          .collection(FirestorePaths.videos)
          .doc(videoId);

      final likeDoc = await likeRef.get();
      final videoDoc = await videoRef.get();
      
      if (!videoDoc.exists) throw Exception('Video not found');
      final currentLikes = (videoDoc.data()?['likes'] as int?) ?? 0;
      final newLikeCount = likeDoc.exists ? currentLikes - 1 : currentLikes + 1;

      if (likeDoc.exists) {
        // Unlike: Delete like document and decrement count
        await likeRef.delete();
        await videoRef.update({'likes': newLikeCount});
        
        // Update local cache
        _userLikes[userId]?.remove(videoId);
      } else {
        // Like: Create like document and increment count
        final like = LikeDocument(
          id: likeRef.id,
          videoId: videoId,
          userId: userId,
          createdAt: Timestamp.now(),
        );
        
        await likeRef.set(like.toMap());
        await videoRef.update({'likes': newLikeCount});
        
        // Update local cache
        _userLikes[userId] ??= {};
        _userLikes[userId]!.add(videoId);
      }

      // Update the video in VideoProvider's cache
      final updatedDoc = await videoRef.get();
      final updatedData = updatedDoc.data() as Map<String, dynamic>;
      updatedData['id'] = videoId;
      
      final updatedVideo = VideoDocument.fromMap(updatedData);
      _videoProvider.updateVideoInCache(updatedVideo);

      // Notify listeners after the update
      notifyListeners();

    } catch (e) {
      _error = 'Failed to toggle like: $e';
      print(_error);
    } finally {
      _loadingStates[videoId] = false;
      notifyListeners();
    }
  }

  /// Load liked videos for a user
  Future<void> loadUserLikes(String userId) async {
    try {
      _loadingStates[userId] = true;
      _error = null;
      notifyListeners();

      final likesSnapshot = await _firestore
          .collection(FirestorePaths.likes)
          .where('userId', isEqualTo: userId)
          .get();

      _userLikes[userId] = likesSnapshot.docs
          .map((doc) => doc.data()['videoId'] as String)
          .toSet();

    } catch (e) {
      _error = 'Failed to load likes: $e';
      print(_error);
    } finally {
      _loadingStates[userId] = false;
      notifyListeners();
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