import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloudinary_service.dart';
import '../types/firestore_types.dart';
import '../mixins/likeable_provider_mixin.dart';
import 'package:provider/provider.dart';
import '../providers/chain_provider.dart';
import 'package:flutter/material.dart';
import '../global.dart';
import 'package:cloud_functions/cloud_functions.dart';

class VideoProvider with ChangeNotifier, LikeableProviderMixin<VideoDocument> {
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

  // Implement LikeableProviderMixin requirements
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

  /// Upload a new video
  Future<String?> uploadVideo({
    required String userId,
    required String videoUrl,
    required String thumbnailUrl,
    required String description,
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

      // Create video document
      final videoDoc = VideoDocument(
        id: '', // Will be set by Firestore
        userId: userId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        description: description,
        likes: 0,
        createdAt: Timestamp.now(),
      );

      // Add to Firestore
      final docRef = await _firestore
          .collection(FirestorePaths.videos)
          .add(videoDoc.toMap());

      // Create the complete video document with the ID
      final newVideo = VideoDocument(
        id: docRef.id,
        userId: userId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        description: description,
        likes: 0,
        createdAt: Timestamp.now(),
      );

      // Update local caches
      Future.microtask(() {
        _videos.insert(0, newVideo);
        _userVideos[userId] = [newVideo, ...(_userVideos[userId] ?? [])];
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

  /// Update a video in the cache
  void updateVideoInCache(VideoDocument video) {
    updateItemInCache(video);
  }

  /// Delete a video and all associated data
  Future<void> deleteVideo(String videoId) async {
    try {
      print('VideoProvider: Starting video deletion process for $videoId');

      // Get the video document
      final videoDoc = await _firestore
          .collection(FirestorePaths.videos)
          .doc(videoId)
          .get();

      if (!videoDoc.exists) {
        throw Exception('Video document not found');
      }

      final video = VideoDocument.fromMap({...videoDoc.data()!, 'id': videoDoc.id});

      // Delete from Cloudinary first (if this fails, we won't proceed with Firestore deletion)
      await _cloudinaryService.deleteVideo(video.videoUrl, video.thumbnailUrl);

      // Start a batch write for Firestore operations
      final batch = _firestore.batch();

      // Delete the video document
      batch.delete(_firestore.collection(FirestorePaths.videos).doc(videoId));

      // Delete all likes for this video
      final likesQuery = await _firestore
          .collection(FirestorePaths.likes)
          .where('videoId', isEqualTo: videoId)
          .get();
      
      for (var doc in likesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Commit Firestore batch
      await batch.commit();

      // Remove video from all chains (this is done after the main deletion succeeds)
      try {
        final chainProvider = Provider.of<ChainProvider>(navigatorKey.currentContext!, listen: false);
        await chainProvider.removeVideoFromAllChains(videoId);
      } catch (e) {
        print('VideoProvider: Error cleaning up chains: $e');
        // Don't rethrow as the main deletion was successful
      }

      // Update local caches
      _videos.removeWhere((v) => v.id == videoId);
      for (var userVideos in _userVideos.values) {
        userVideos.removeWhere((v) => v.id == videoId);
      }

      // Notify listeners of the change
      notifyListeners();

      print('VideoProvider: Successfully deleted video $videoId');
    } catch (e) {
      print('VideoProvider: Error deleting video: $e');
      rethrow;
    }
  }

  /// Get analysis status for a video
  String? getVideoAnalysisStatus(String videoId) {
    final video = getVideoById(videoId);
    return video?.analysis?.status;
  }

  /// Check if a video is being analyzed
  bool isVideoBeingAnalyzed(String videoId) {
    final status = getVideoAnalysisStatus(videoId);
    return status == VideoAnalysis.STATUS_PENDING;
  }

  /// Check if a video analysis has failed
  bool hasVideoAnalysisFailed(String videoId) {
    final status = getVideoAnalysisStatus(videoId);
    return status == VideoAnalysis.STATUS_FAILED;
  }

  /// Get video analysis error if any
  String? getVideoAnalysisError(String videoId) {
    final video = getVideoById(videoId);
    return video?.analysis?.error;
  }

  /// Request reanalysis of a video
  Future<void> reanalyzeVideo(String videoId) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('reanalyzeVideo');
      await callable.call({'videoId': videoId});
    } catch (e) {
      print('VideoProvider: Error requesting video reanalysis: $e');
      rethrow;
    }
  }

  /// Listen for analysis updates on a specific video
  Stream<VideoAnalysis?> videoAnalysisStream(String videoId) {
    return _firestore
        .collection(FirestorePaths.videos)
        .doc(videoId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final data = snapshot.data();
          if (data == null || !data.containsKey('analysis')) return null;
          return VideoAnalysis.fromMap(data['analysis'] as Map<String, dynamic>);
        });
  }
} 