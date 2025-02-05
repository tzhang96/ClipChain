import 'package:cloud_firestore/cloud_firestore.dart';
import '../types/firestore_types.dart';

class VideoModel {
  final String id;
  final String userId;
  final String videoUrl;
  final String? thumbnailUrl;
  final String description;
  final int likes;
  final DateTime createdAt;

  const VideoModel({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.description,
    required this.likes,
    required this.createdAt,
  });

  factory VideoModel.fromDocument(VideoDocument doc) {
    return VideoModel(
      id: doc.id,
      userId: doc.userId,
      videoUrl: doc.videoUrl,
      thumbnailUrl: doc.thumbnailUrl,
      description: doc.description,
      likes: doc.likes,
      createdAt: doc.createdAt.toDate(),
    );
  }

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    try {
      final timestamp = map['createdAt'] as Timestamp? ?? Timestamp.now();
      
      return VideoModel(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        videoUrl: map['videoUrl'] as String? ?? '',
        thumbnailUrl: map['thumbnailUrl'] as String?,
        description: map['description'] as String? ?? '',
        likes: map['likes'] as int? ?? 0,
        createdAt: timestamp.toDate(),
      );
    } catch (e) {
      print('Error creating VideoModel from map: $e');
      rethrow;
    }
  }

  VideoDocument toDocument() {
    return VideoDocument(
      id: id,
      userId: userId,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      description: description,
      likes: likes,
      createdAt: Timestamp.fromDate(createdAt),
    );
  }

  Map<String, dynamic> toMap() => toDocument().toMap();
} 