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
    return Container(
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
    );
  }
} 