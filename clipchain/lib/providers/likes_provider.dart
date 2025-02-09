import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../types/firestore_types.dart';
import '../mixins/likeable_provider_mixin.dart';
import 'video_provider.dart';

class LikesProvider with ChangeNotifier, LikeableProviderMixin<VideoDocument> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  VideoProvider? _videoProvider;

  void initialize(VideoProvider videoProvider) {
    if (_videoProvider != null) return; // Prevent re-initialization
    _videoProvider = videoProvider;
  }

  @override
  String get likesCollectionPath => FirestorePaths.likes;

  @override
  String get documentsCollectionPath => FirestorePaths.videos;

  @override
  VideoDocument Function(Map<String, dynamic> data) get fromMap => VideoDocument.fromMap;

  @override
  String get likeableIdField => 'videoId';

  @override
  void updateItemInCache(VideoDocument video) {
    _videoProvider?.updateVideoInCache(video);
  }

  /// Clear all cached data
  @override
  void clear() {
    clearLikes();
    notifyListeners();
  }

  /// Get all liked video IDs for a user (alias for getLikedItemIds for backward compatibility)
  Set<String> getLikedVideoIds(String userId) {
    return getLikedItemIds(userId);
  }

  /// Check if a video is liked by a user (alias for isItemLiked for backward compatibility)
  bool isVideoLiked(String userId, String videoId) {
    return isItemLiked(userId, videoId);
  }
} 