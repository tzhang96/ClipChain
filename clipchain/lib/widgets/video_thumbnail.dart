import 'package:flutter/material.dart';
import '../models/video_model.dart';

class VideoThumbnail extends StatelessWidget {
  final VideoModel video;

  const VideoThumbnail({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Thumbnail
        if (video.thumbnailUrl != null)
          Image.network(
            video.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.error_outline),
              );
            },
          )
        else
          const ColoredBox(
            color: Colors.black12,
            child: Icon(Icons.play_circle_outline),
          ),

        // Video Info Overlay
        Positioned(
          bottom: 4,
          left: 4,
          right: 4,
          child: Row(
            children: [
              const Icon(
                Icons.favorite,
                color: Colors.white,
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
          ),
        ),
      ],
    );
  }
} 