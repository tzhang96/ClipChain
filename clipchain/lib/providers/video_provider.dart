import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloudinary_service.dart';
import '../types/firestore_types.dart';

class VideoProvider with ChangeNotifier {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<VideoDocument> _videos = [];
  bool _isLoading = false;
  String? _error;

  List<VideoDocument> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchVideos() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final QuerySnapshot videoSnapshot = await _firestore
          .collection(FirestorePaths.videos)
          .orderBy('createdAt', descending: true)
          .get();

      _videos = videoSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // Ensure the document ID is included
            return VideoDocument.fromMap(data);
          })
          .toList();

    } catch (e) {
      _error = 'Failed to fetch videos: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadVideo({
    required String filePath,
    required String description,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
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
      await _firestore.collection(FirestorePaths.videos).add(videoDoc.toMap());

      // Refresh videos list
      await fetchVideos();

    } catch (e) {
      _error = 'Failed to upload video: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 