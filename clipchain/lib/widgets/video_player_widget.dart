import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_player_provider.dart';
import '../services/video_player_service.dart';

class VideoPlayerWidget extends StatelessWidget {
  const VideoPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoPlayerProvider>(
      builder: (context, provider, child) {
        final player = provider.currentPlayer;
        
        if (provider.isInitializing) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(provider.error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          );
        }
        
        if (player == null || !player.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return GestureDetector(
          onTap: () => provider.togglePlayPause(),
          child: player.buildPlayer(),
        );
      },
    );
  }
} 