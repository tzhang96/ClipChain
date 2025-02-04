import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../types/firestore_types.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Uploads a video file and its metadata
  Future<String> uploadVideo({
    required String userId,
    required File videoFile,
    required File thumbnailFile,
    required String description,
  }) async {
    try {
      // Generate a unique video ID
      final videoId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create storage references
      final videoRef = _storage.ref().child('videos/$userId/$videoId.mp4');
      final thumbRef = _storage.ref().child('videos/$userId/${videoId}_thumb.jpg');

      // Upload files
      await videoRef.putFile(videoFile);
      await thumbRef.putFile(thumbnailFile);

      // Get download URLs
      final videoUrl = await videoRef.getDownloadURL();
      final thumbnailUrl = await thumbRef.getDownloadURL();

      // Create video document
      final videoDoc = VideoDocument(
        id: videoId,
        userId: userId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        description: description,
        likes: 0,
        createdAt: Timestamp.now(),
      );

      // Save to Firestore
      await _firestore
          .collection(FirestorePaths.videos)
          .doc(videoId)
          .set(videoDoc.toMap());

      return videoId;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  /// Creates a video document in Firestore for an already uploaded video
  Future<String> createVideoDocument({
    required String userId,
    required String videoUrl,
    required String thumbnailUrl,
    required String description,
  }) async {
    try {
      // Generate a unique video ID
      final videoId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create video document
      final videoDoc = VideoDocument(
        id: videoId,
        userId: userId,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        description: description,
        likes: 0,
        createdAt: Timestamp.now(),
      );

      // Save to Firestore
      await _firestore
          .collection(FirestorePaths.videos)
          .doc(videoId)
          .set(videoDoc.toMap());

      return videoId;
    } catch (e) {
      throw Exception('Failed to create video document: $e');
    }
  }

  /// Helper method to get storage path for a video
  String getVideoPath(String userId, String videoId) => 'videos/$userId/$videoId.mp4';
  
  /// Helper method to get storage path for a thumbnail
  String getThumbnailPath(String userId, String videoId) => 'videos/$userId/${videoId}_thumb.jpg';

  /// Delete a video and its associated data
  Future<void> deleteVideo(String userId, String videoId) async {
    try {
      // Delete from Storage
      await _storage.ref().child(getVideoPath(userId, videoId)).delete();
      await _storage.ref().child(getThumbnailPath(userId, videoId)).delete();

      // Delete from Firestore
      await _firestore
          .collection(FirestorePaths.videos)
          .doc(videoId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete video: $e');
    }
  }
} 