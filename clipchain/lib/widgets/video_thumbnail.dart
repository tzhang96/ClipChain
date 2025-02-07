import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/likes_provider.dart';
import '../types/firestore_types.dart';

class VideoThumbnail extends StatelessWidget {
  final VideoDocument video;

  const VideoThumbnail({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail Image
        if (video.thumbnailUrl != null)
          Image.network(
            video.thumbnailUrl!,
            fit: BoxFit.cover,
          )
        else
          Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.video_library, color: Colors.white),
            ),
          ),

        // Like Count Overlay
        Positioned(
          bottom: 4,
          left: 4,
          child: Consumer2<AuthProvider, LikesProvider>(
            builder: (context, authProvider, likesProvider, _) {
              final userId = authProvider.user?.uid;
              final isLiked = userId != null && 
                  likesProvider.isVideoLiked(userId, video.id);

              return Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${video.likes}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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