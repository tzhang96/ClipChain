import 'package:cloud_firestore/cloud_firestore.dart';
import '../mixins/likeable_provider_mixin.dart';

/// Represents the structure of a document in the 'videos' collection
class VideoDocument implements LikeableDocument {
  final String id;
  final String userId;
  final String videoUrl;
  final String? thumbnailUrl;
  final String description;
  final int likes;
  final Timestamp createdAt;
  final VideoAnalysis? analysis;

  const VideoDocument({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.description,
    required this.likes,
    required this.createdAt,
    this.analysis,
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
      analysis: map['analysis'] != null 
        ? VideoAnalysis.fromMap(map['analysis'] as Map<String, dynamic>)
        : null,
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
    'analysis': analysis?.toMap(),
  };

  VideoDocument copyWith({
    String? id,
    String? userId,
    String? videoUrl,
    String? thumbnailUrl,
    String? description,
    int? likes,
    Timestamp? createdAt,
    VideoAnalysis? analysis,
  }) => VideoDocument(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    videoUrl: videoUrl ?? this.videoUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    description: description ?? this.description,
    likes: likes ?? this.likes,
    createdAt: createdAt ?? this.createdAt,
    analysis: analysis ?? this.analysis,
  );
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
class ChainDocument implements LikeableDocument {
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

class VideoAnalysis {
  final String summary;
  final List<String> themes;
  final Map<String, List<String>> visuals;
  final String style;
  final String mood;
  final Timestamp analyzedAt;
  final String? error;
  final String status;
  final int version;
  final String? rawResponse;

  static const String STATUS_PENDING = 'pending';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_FAILED = 'failed';

  const VideoAnalysis({
    required this.summary,
    required this.themes,
    required this.visuals,
    required this.style,
    required this.mood,
    required this.analyzedAt,
    this.error,
    required this.status,
    required this.version,
    this.rawResponse,
  });

  Map<String, dynamic> toMap() => {
    'summary': summary,
    'themes': themes,
    'visuals': visuals,
    'style': style,
    'mood': mood,
    'analyzedAt': analyzedAt,
    'error': error,
    'status': status,
    'version': version,
    'rawResponse': rawResponse,
  };

  factory VideoAnalysis.fromMap(Map<String, dynamic> map) {
    Map<String, List<String>> parseVisuals(Map<String, dynamic>? visualsMap) {
      if (visualsMap == null) return {'colors': [], 'elements': []};
      return {
        'colors': List<String>.from(visualsMap['colors'] as List? ?? []),
        'elements': List<String>.from(visualsMap['elements'] as List? ?? []),
      };
    }

    return VideoAnalysis(
      summary: map['summary'] as String? ?? '',
      themes: List<String>.from(map['themes'] as List? ?? []),
      visuals: parseVisuals(map['visuals'] as Map<String, dynamic>?),
      style: map['style'] as String? ?? '',
      mood: map['mood'] as String? ?? '',
      analyzedAt: map['analyzedAt'] as Timestamp? ?? Timestamp.now(),
      error: map['error'] as String?,
      status: map['status'] as String? ?? STATUS_PENDING,
      version: map['version'] as int? ?? 1,
      rawResponse: map['rawResponse'] as String?,
    );
  }

  VideoAnalysis copyWith({
    String? summary,
    List<String>? themes,
    Map<String, List<String>>? visuals,
    String? style,
    String? mood,
    Timestamp? analyzedAt,
    String? error,
    String? status,
    int? version,
    String? rawResponse,
  }) => VideoAnalysis(
    summary: summary ?? this.summary,
    themes: themes ?? this.themes,
    visuals: visuals ?? this.visuals,
    style: style ?? this.style,
    mood: mood ?? this.mood,
    analyzedAt: analyzedAt ?? this.analyzedAt,
    error: error ?? this.error,
    status: status ?? this.status,
    version: version ?? this.version,
    rawResponse: rawResponse ?? this.rawResponse,
  );
} 