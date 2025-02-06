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

  /// Fetch all videos (for feed)
  Future<void> fetchVideos() async {
    if (_isLoadingFeed) {
      print('VideoProvider: Already fetching videos');
      return;
    }

    _isLoadingFeed = true;
    _feedError = null;
    notifyListeners();

    try {
      print('VideoProvider: Starting to fetch videos');
      final QuerySnapshot videoSnapshot = await _firestore
          .collection(FirestorePaths.videos)
          .orderBy('createdAt', descending: true)
          .get();

      _videos = videoSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return VideoDocument.fromMap(data);
          })
          .toList();

      print('VideoProvider: Successfully fetched ${_videos.length} videos');
    } catch (e) {
      print('VideoProvider: Error fetching videos: $e');
      _feedError = 'Failed to fetch videos: $e';
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  /// Fetch videos for a specific user
  Future<void> fetchUserVideos(String userId) async {
    if (_isLoadingUserVideos) {
      print('VideoProvider: Already fetching user videos');
      return;
    }

    _isLoadingUserVideos = true;
    _userVideosError = null;
    notifyListeners();

    try {
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

      _userVideos[userId] = userVideos;
      print('VideoProvider: Successfully fetched ${userVideos.length} videos for user $userId');

    } catch (e) {
      _userVideosError = 'Failed to fetch user videos: $e';
      print(_userVideosError);
    } finally {
      _isLoadingUserVideos = false;
      notifyListeners();
    }
  }

  Future<String?> uploadVideo({
    required String filePath,
    required String description,
    required String userId,
  }) async {
    try {
      _isLoadingFeed = true;
      _isLoadingUserVideos = true;
      _feedError = null;
      _userVideosError = null;
      notifyListeners();

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

      return docRef.id;

    } catch (e) {
      _feedError = 'Failed to upload video: $e';
      _userVideosError = _feedError;
      print(_feedError);
      return null;
    } finally {
      _isLoadingFeed = false;
      _isLoadingUserVideos = false;
      notifyListeners();
    }
  }
} 