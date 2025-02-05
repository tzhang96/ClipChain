import 'package:flutter/material.dart';
import '../models/video_model.dart';
import 'video_thumbnail.dart';

class VideoGrid extends StatelessWidget {
  final List<VideoModel> videos;
  final void Function(String videoId)? onVideoTap;
  final bool isLoading;
  final String? errorMessage;

  const VideoGrid({
    super.key,
    required this.videos,
    this.onVideoTap,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }

    if (videos.isEmpty) {
      return const Center(child: Text('No videos'));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9/16,  // Video aspect ratio
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