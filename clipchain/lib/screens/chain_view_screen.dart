import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../types/firestore_types.dart';
import '../providers/video_provider.dart';
import '../providers/user_provider.dart';
import '../providers/chain_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/video_grid.dart';
import '../models/feed_source.dart';
import '../widgets/video_thumbnail.dart';
import 'profile_screen.dart';
import 'video_feed_screen.dart';
import '../widgets/authenticated_view.dart';

class ChainViewScreen extends StatefulWidget {
  final ChainDocument chain;

  const ChainViewScreen({
    super.key,
    required this.chain,
  });

  @override
  State<ChainViewScreen> createState() => _ChainViewScreenState();
}

class _ChainViewScreenState extends State<ChainViewScreen> {
  List<VideoDocument>? _recommendations;
  bool _loadingRecommendations = false;

  @override
  void initState() {
    super.initState();
    print('ChainViewScreen: Initializing for chain ${widget.chain.id}');
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    if (_loadingRecommendations) {
      print('ChainViewScreen: Already loading recommendations, skipping');
      return;
    }
    
    print('ChainViewScreen: Starting to load recommendations');
    setState(() {
      _loadingRecommendations = true;
    });

    try {
      print('ChainViewScreen: Calling getRecommendations');
      final recommendations = await context.read<ChainProvider>()
        .getRecommendations(widget.chain);
      
      print('ChainViewScreen: Received ${recommendations.length} recommendations');
      
      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _loadingRecommendations = false;
        });
        print('ChainViewScreen: Updated state with recommendations');
      } else {
        print('ChainViewScreen: Widget no longer mounted, skipping state update');
      }
    } catch (e, stackTrace) {
      print('ChainViewScreen: Error loading recommendations: $e');
      print('ChainViewScreen: Stack trace:\n$stackTrace');
      if (mounted) {
        setState(() {
          _loadingRecommendations = false;
        });
        print('ChainViewScreen: Updated state to reflect error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('ChainViewScreen: Building UI');
    print('ChainViewScreen: Recommendations state - loading: $_loadingRecommendations, count: ${_recommendations?.length ?? 0}');
    
    final videoProvider = context.watch<VideoProvider>();
    final userProvider = context.watch<UserProvider>();
    final chainProvider = context.watch<ChainProvider>();
    final user = userProvider.getUser(widget.chain.userId);
    
    // Fetch user data if not available
    if (user == null && !userProvider.isLoading(widget.chain.userId)) {
      userProvider.fetchUser(widget.chain.userId);
    }

    // Get all videos in the chain
    final videos = widget.chain.videoIds
        .map((id) => videoProvider.getVideoById(id))
        .where((video) => video != null)
        .map((video) => video!)
        .toList();
    
    print('ChainViewScreen: Chain videos count: ${videos.length}');

    final content = CustomScrollView(
      slivers: [
        // App Bar with chain info
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        widget.chain.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.chain.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.chain.description!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Creator info row
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(userId: widget.chain.userId),
                            ),
                            (route) => false,
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[300],
                              child: Text(
                                user?.username.substring(0, 1).toUpperCase() ?? '?',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              user?.username ?? 'Loading...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            // Like button
                            Consumer2<AuthProvider, ChainProvider>(
                              builder: (context, authProvider, chainProvider, _) {
                                final userId = authProvider.user?.uid;
                                final isLiked = userId != null && 
                                    chainProvider.isItemLiked(userId, widget.chain.id);
                                final liveChain = chainProvider.getChainById(widget.chain.id) ?? widget.chain;

                                return Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (userId != null) {
                                          chainProvider.toggleLike(userId, widget.chain.id);
                                        }
                                      },
                                      child: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: isLiked ? Colors.red : Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${liveChain.likes}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Videos grid
        SliverPadding(
          padding: const EdgeInsets.all(8.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 9 / 16,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final video = videos[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => VideoFeedScreen(
                          customVideos: videos,
                          initialIndex: index,
                          title: widget.chain.title,
                          onHeaderTap: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    );
                  },
                  child: VideoThumbnail(video: video),
                );
              },
              childCount: videos.length,
            ),
          ),
        ),

        // Recommendations Section
        if (_recommendations != null && _recommendations!.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Recommended Videos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(8.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 9 / 16,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final video = _recommendations![index];
                  print('ChainViewScreen: Building recommendation tile for video ${video.id}');
                  return GestureDetector(
                    onTap: () async {
                      print('ChainViewScreen: Tapped recommendation ${video.id}');
                      // Add to chain
                      try {
                        print('ChainViewScreen: Adding video ${video.id} to chain ${widget.chain.id}');
                        await chainProvider.addVideoToChain(
                          widget.chain.id,
                          video.id,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Video added to chain!'),
                            ),
                          );
                          print('ChainViewScreen: Successfully added video, refreshing recommendations');
                          // Refresh recommendations
                          _loadRecommendations();
                        }
                      } catch (e) {
                        print('ChainViewScreen: Error adding video to chain: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding video: $e'),
                            ),
                          );
                        }
                      }
                    },
                    child: Stack(
                      children: [
                        VideoThumbnail(
                          video: video,
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: _recommendations!.length,
              ),
            ),
          ),
        ] else if (_loadingRecommendations) ...[
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ],
    );

    return AuthenticatedView(
      selectedIndex: 0,
      body: content,
    );
  }
} 