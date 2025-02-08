import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloudinary_service.dart';
import '../types/firestore_types.dart';

class VideoProvider with ChangeNotifier {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<VideoDocument> _videos = [];
  Map<String, List<VideoDocument>> _userVideos = {}; // Cache of user-specific videos
  
  bool _isLoadingFeed = false;
  bool _isLoadingUserVideos = false;
  String? _feedError;
  String? _userVideosError;

  List<VideoDocument> get videos => _videos;
  bool get isLoadingFeed => _isLoadingFeed;
  bool get isLoadingUserVideos => _isLoadingUserVideos;
  String? get feedError => _feedError;
  String? get userVideosError => _userVideosError;

  /// Get videos for a specific user
  List<VideoDocument> getVideosByUserId(String userId) {
    return _userVideos[userId] ?? [];
  }

  /// Get a single video by ID
  VideoDocument? getVideoById(String videoId) {
    return _videos.cast<VideoDocument?>().firstWhere(
      (v) => v?.id == videoId,
      orElse: () => null,
    );
  }

  /// Update a video in the cache
  void updateVideoInCache(VideoDocument video) {
    final index = _videos.indexWhere((v) => v.id == video.id);
    if (index != -1) {
      _videos[index] = video;
      
      // Also update in user videos if present
      final userVideos = _userVideos[video.userId];
      if (userVideos != null) {
        final userIndex = userVideos.indexWhere((v) => v.id == video.id);
        if (userIndex != -1) {
          userVideos[userIndex] = video;
        }
      }
      
      notifyListeners();
    }
  }

  /// Fetch all videos (for feed)
  Future<void> fetchVideos() async {
    try {
      // Defer state update to next event loop iteration
      Future.microtask(() {
        _isLoadingFeed = true;
        _feedError = null;
        notifyListeners();
      });

      final QuerySnapshot videoSnapshot = await _firestore
          .collection(FirestorePaths.videos)
          .orderBy('createdAt', descending: true)
          .get();

      final newVideos = videoSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return VideoDocument.fromMap(data);
          })
          .toList();

      // Schedule state update after async complete
      Future.microtask(() {
        _videos = newVideos;
        _isLoadingFeed = false;
        notifyListeners();
      });

    } catch (e) {
      Future.microtask(() {
        _feedError = 'Failed to fetch videos: $e';
        _isLoadingFeed = false;
        notifyListeners();
      });
    }
  }

  /// Fetch videos for a specific user
  Future<void> fetchUserVideos(String userId) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoadingUserVideos = true;
        _userVideosError = null;
        notifyListeners();
      });

      final QuerySnapshot videoSnapshot = await _firestore
          .collection(FirestorePaths.videos)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final userVideos = videoSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return VideoDocument.fromMap(data);
          })
          .toList();

      // Schedule state update after async complete
      Future.microtask(() {
        _userVideos[userId] = userVideos;
        _isLoadingUserVideos = false;
        notifyListeners();
      });

    } catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _userVideosError = 'Failed to fetch user videos: $e';
        _isLoadingUserVideos = false;
        notifyListeners();
      });
    }
  }

  Future<String?> uploadVideo({
    required String filePath,
    required String description,
    required String userId,
  }) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoadingFeed = true;
        _isLoadingUserVideos = true;
        _feedError = null;
        _userVideosError = null;
        notifyListeners();
      });

      // Upload to Cloudinary
      final urls = await _cloudinaryService.uploadVideo(File(filePath));
      
      // Create video document
      final videoDoc = VideoDocument(
        id: '', // Will be set by Firestore
        userId: userId,
        videoUrl: urls.videoUrl,
        thumbnailUrl: urls.thumbnailUrl,
        description: description,
        likes: 0,
        createdAt: Timestamp.now(),
      );

      // Add to Firestore
      final docRef = await _firestore
          .collection(FirestorePaths.videos)
          .add(videoDoc.toMap());

      // Refresh both global and user-specific videos
      await Future.wait([
        fetchVideos(),
        fetchUserVideos(userId),
      ]);

      // Schedule success state update
      Future.microtask(() {
        _isLoadingFeed = false;
        _isLoadingUserVideos = false;
        notifyListeners();
      });

      return docRef.id;

    } catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _feedError = 'Failed to upload video: $e';
        _userVideosError = _feedError;
        _isLoadingFeed = false;
        _isLoadingUserVideos = false;
        notifyListeners();
      });
      return null;
    }
  }

  /// Clear all cached data
  void clear() {
    _videos.clear();
    _userVideos.clear();
    _isLoadingFeed = false;
    _isLoadingUserVideos = false;
    _feedError = null;
    _userVideosError = null;
    notifyListeners();
  }
} 