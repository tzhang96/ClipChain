import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../types/firestore_types.dart';
import '../providers/chain_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/video_provider.dart';

class ChainGrid extends StatelessWidget {
  final List<ChainDocument> chains;
  final bool isLoading;
  final String? errorMessage;
  final void Function(String chainId)? onChainTap;

  const ChainGrid({
    super.key,
    required this.chains,
    this.isLoading = false,
    this.errorMessage,
    this.onChainTap,
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

    if (chains.isEmpty) {
      return const Center(child: Text('No chains available'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: chains.length,
      itemBuilder: (context, index) {
        final chain = chains[index];
        return GestureDetector(
          onTap: () => onChainTap?.call(chain.id),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Chain Preview (first video thumbnail)
                Consumer<VideoProvider>(
                  builder: (context, videoProvider, child) {
                    // Get the first video in the chain
                    final firstVideoId = chain.videoIds.isNotEmpty ? chain.videoIds.first : null;
                    final firstVideo = firstVideoId != null ? videoProvider.getVideoById(firstVideoId) : null;

                    if (firstVideo?.thumbnailUrl != null) {
                      return Image.network(
                        firstVideo!.thumbnailUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    }

                    // Fallback if no thumbnail available
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                      ),
                      child: const Center(
                        child: Icon(Icons.video_library, size: 48),
                      ),
                    );
                  },
                ),
                
                // Chain Info Overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chain.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${chain.videoIds.length} videos',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Consumer2<AuthProvider, ChainProvider>(
                              builder: (context, authProvider, chainProvider, _) {
                                final userId = authProvider.user?.uid;
                                final isLiked = userId != null && 
                                    chainProvider.isChainLiked(userId, chain.id);

                                return Row(
                                  children: [
                                    Icon(
                                      Icons.favorite,
                                      color: isLiked ? Colors.red : Colors.white70,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${chain.likes}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 