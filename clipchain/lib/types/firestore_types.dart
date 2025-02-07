import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the structure of a document in the 'videos' collection
class VideoDocument {
  final String id;
  final String userId;
  final String videoUrl;
  final String? thumbnailUrl;
  final String description;
  final int likes;
  final Timestamp createdAt;

  const VideoDocument({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.description,
    required this.likes,
    required this.createdAt,
  });

  factory VideoDocument.fromMap(Map<String, dynamic> map) {
    return VideoDocument(
      id: map['id'] as String,
      userId: map['userId'] as String,
      videoUrl: map['videoUrl'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      description: map['description'] as String,
      likes: map['likes'] as int,
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'videoUrl': videoUrl,
    'thumbnailUrl': thumbnailUrl,
    'description': description,
    'likes': likes,
    'createdAt': createdAt,
  };
}

/// Represents the structure of a document in the 'users' collection
class UserDocument {
  final String id;
  final String email;
  final String username;
  final String? photoUrl;
  final String? bio;
  final List<String> followers;
  final List<String> following;
  final Timestamp createdAt;

  const UserDocument({
    required this.id,
    required this.email,
    required this.username,
    this.photoUrl,
    this.bio,
    required this.followers,
    required this.following,
    required this.createdAt,
  });

  factory UserDocument.fromMap(Map<String, dynamic> map) {
    return UserDocument(
      id: map['id'] as String,
      email: map['email'] as String,
      username: map['username'] as String,
      photoUrl: map['photoUrl'] as String?,
      bio: map['bio'] as String?,
      followers: List<String>.from(map['followers'] as List),
      following: List<String>.from(map['following'] as List),
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'username': username,
    'photoUrl': photoUrl,
    'bio': bio,
    'followers': followers,
    'following': following,
    'createdAt': createdAt,
  };
}

/// Represents the structure of a document in the 'comments' collection
class CommentDocument {
  final String id;
  final String videoId;
  final String userId;
  final String text;
  final Timestamp createdAt;

  const CommentDocument({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory CommentDocument.fromMap(Map<String, dynamic> map) {
    return CommentDocument(
      id: map['id'] as String,
      videoId: map['videoId'] as String,
      userId: map['userId'] as String,
      text: map['text'] as String,
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'videoId': videoId,
    'userId': userId,
    'text': text,
    'createdAt': createdAt,
  };
}

/// Represents the structure of a document in the 'likes' collection
class LikeDocument {
  final String id;
  final String videoId;
  final String userId;
  final Timestamp createdAt;

  const LikeDocument({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.createdAt,
  });

  factory LikeDocument.fromMap(Map<String, dynamic> map) {
    return LikeDocument(
      id: map['id'] as String,
      videoId: map['videoId'] as String,
      userId: map['userId'] as String,
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'videoId': videoId,
    'userId': userId,
    'createdAt': createdAt,
  };
}

/// Represents the structure of a document in the 'chains' collection
class ChainDocument {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final int likes;
  final List<String> videoIds;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const ChainDocument({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.likes,
    required this.videoIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChainDocument.fromMap(Map<String, dynamic> map) {
    return ChainDocument(
      id: map['id'] as String,
      userId: map['userId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      likes: map['likes'] as int,
      videoIds: List<String>.from(map['videoIds'] as List),
      createdAt: map['createdAt'] as Timestamp,
      updatedAt: map['updatedAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'likes': likes,
    'videoIds': videoIds,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// Collection path constants to avoid typos
class FirestorePaths {
  static const String videos = 'videos';
  static const String users = 'users';
  static const String comments = 'comments';
  static const String likes = 'likes';
  static const String chains = 'chains';
  static const String chainLikes = 'chainLikes';
  
  // Private constructor to prevent instantiation
  FirestorePaths._();
  
  /// Helper method to get a user's likes subcollection path
  static String userLikes(String userId) => 'users/$userId/likes';
  
  /// Helper method to get a video's comments subcollection path
  static String videoComments(String videoId) => 'videos/$videoId/comments';
  
  /// Helper method to get a user's chains subcollection path
  static String userChains(String userId) => 'users/$userId/chains';
} 