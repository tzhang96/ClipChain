import 'package:flutter/material.dart';
import '../models/video_model.dart';
import 'video_thumbnail.dart';

class VideoGrid extends StatelessWidget {
  final List<VideoModel> videos;
  final bool isLoading;
  final String? errorMessage;
  final void Function(String videoId)? onVideoTap;

  const VideoGrid({
    super.key,
    required this.videos,
    this.isLoading = false,
    this.errorMessage,
    this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage!),
          ],
        ),
      );
    }

    if (videos.isEmpty) {
      return const Center(child: Text('No videos available'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 9 / 16, // Video aspect ratio
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () => onVideoTap?.call(video.id),
          child: VideoThumbnail(video: video),
        );
      },
    );
  }
} 