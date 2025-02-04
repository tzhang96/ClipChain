import 'package:cloud_firestore/cloud_firestore.dart';
import '../types/firestore_types.dart';

class VideoModel {
  final String id;
  final String userId;
  final String videoUrl;
  final String thumbnailUrl;
  final String description;
  final int likes;
  final DateTime createdAt;

  const VideoModel({
    required this.id,
    required this.userId,
    required this.videoUrl,
    required this.thumbnailUrl,
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
    return VideoModel.fromDocument(VideoDocument.fromMap(map));
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