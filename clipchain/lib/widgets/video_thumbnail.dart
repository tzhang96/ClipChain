import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/likes_provider.dart';
import '../types/firestore_types.dart';

class VideoThumbnail extends StatelessWidget {
  final VideoDocument video;
  final double? width;

  const VideoThumbnail({
    super.key,
    required this.video,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: width,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: video.thumbnailUrl != null
            ? Image.network(
                video.thumbnailUrl!,
                fit: BoxFit.cover,
                width: width,
                height: double.infinity,
              )
            : Container(
                color: Colors.black.withOpacity(0.1),
                child: const Center(
                  child: Icon(Icons.video_library, size: 48),
                ),
              ),
        ),
        // Likes overlay
        Positioned(
          bottom: 8,
          left: 8,
          child: Consumer2<AuthProvider, LikesProvider>(
            builder: (context, authProvider, likesProvider, _) {
              final userId = authProvider.user?.uid;
              final isLiked = userId != null && 
                  likesProvider.isVideoLiked(userId, video.id);

              return Row(
                children: [
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${video.likes}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
} 