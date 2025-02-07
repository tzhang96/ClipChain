import 'package:flutter/material.dart';
import '../types/firestore_types.dart';
import 'video_thumbnail.dart';

class VideoGrid extends StatelessWidget {
  final List<VideoDocument> videos;
  final bool isLoading;
  final String? errorMessage;
  final void Function(String videoId)? onVideoTap;
  final Set<String>? selectedVideoIds;  // Optional set of selected video IDs

  const VideoGrid({
    super.key,
    required this.videos,
    this.isLoading = false,
    this.errorMessage,
    this.onVideoTap,
    this.selectedVideoIds,
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
        final isSelected = selectedVideoIds?.contains(video.id) ?? false;

        return GestureDetector(
          onTap: () => onVideoTap?.call(video.id),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoThumbnail(video: video),
              if (selectedVideoIds != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              if (selectedVideoIds != null && isSelected)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
} 