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
    print('ChainViewScreen: Chain ID: ${widget.chain.id}');
    print('ChainViewScreen: Chain title: ${widget.chain.title}');
    print('ChainViewScreen: Chain video count: ${widget.chain.videoIds.length}');
    
    setState(() {
      _loadingRecommendations = true;
    });

    try {
      final chainProvider = context.read<ChainProvider>();
      final liveChain = chainProvider.getChainById(widget.chain.id) ?? widget.chain;
      
      print('ChainViewScreen: Live chain details:');
      print('ChainViewScreen: - ID: ${liveChain.id}');
      print('ChainViewScreen: - Title: ${liveChain.title}');
      print('ChainViewScreen: - Video count: ${liveChain.videoIds.length}');
      print('ChainViewScreen: Calling getRecommendations');
      
      final recommendations = await chainProvider.getRecommendations(liveChain);
      
      print('ChainViewScreen: Received ${recommendations.length} recommendations');
      print('ChainViewScreen: Mounted status: $mounted');
      
      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _loadingRecommendations = false;
        });
        print('ChainViewScreen: Updated state with recommendations');
        print('ChainViewScreen: Final recommendations count: ${_recommendations?.length ?? 0}');
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
    
    // Get the live chain data
    final liveChain = chainProvider.getChainById(widget.chain.id) ?? widget.chain;
    final user = userProvider.getUser(liveChain.userId);
    
    // Fetch user data if not available
    if (user == null && !userProvider.isLoading(liveChain.userId)) {
      userProvider.fetchUser(liveChain.userId);
    }

    // Get all videos in the chain using the live chain data
    final videos = liveChain.videoIds
        .map((id) => videoProvider.getVideoById(id))
        .where((video) => video != null)
        .map((video) => video!)
        .toList();
    
    print('ChainViewScreen: Chain videos count: ${videos.length}');

    final content = CustomScrollView(
      slivers: [
        // App Bar with chain info
        SliverAppBar(
          expandedHeight: liveChain.description != null ? 200 : 160,
          pinned: true,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        liveChain.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (liveChain.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          liveChain.description!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Creator info row
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(
                                userId: liveChain.userId,
                                showNavBar: true,
                              ),
                            ),
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
                                    chainProvider.isItemLiked(userId, liveChain.id);

                                return Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (userId != null) {
                                          chainProvider.toggleLike(userId, liveChain.id);
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
                                    // Add delete button for chain owner
                                    if (userId != null && userId == liveChain.userId)
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.white),
                                        color: Colors.white,
                                        onSelected: (value) async {
                                          if (value == 'delete') {
                                            // Show confirmation dialog
                                            final shouldDelete = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete Chain'),
                                                content: const Text(
                                                  'Are you sure you want to delete this chain?\n\n'
                                                  'This will:\n'
                                                  '• Delete the chain permanently\n'
                                                  '• Remove all likes on this chain\n\n'
                                                  'This action cannot be undone.'
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.red,
                                                    ),
                                                    onPressed: () => Navigator.of(context).pop(true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (shouldDelete == true) {
                                              try {
                                                // Show loading indicator
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (context) => const Center(
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                );

                                                // Delete the chain
                                                await chainProvider.deleteChain(liveChain.id, userId);

                                                // Dismiss loading indicator
                                                Navigator.of(context).pop();

                                                // Show success message and return to profile
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Chain deleted successfully'),
                                                    ),
                                                  );
                                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                                    '/profile',
                                                    (route) => false,
                                                  );
                                                }
                                              } catch (e) {
                                                // Dismiss loading indicator
                                                Navigator.of(context).pop();

                                                // Show error message
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Error deleting chain: $e'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          const PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(color: Colors.red),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
                  child: Stack(
                    children: [
                      VideoThumbnail(
                        video: video,
                      ),
                    ],
                  ),
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
                      // Play recommendations as a feed
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) => VideoFeedScreen(
                            customVideos: _recommendations!,
                            initialIndex: index,
                            title: 'Recommended Videos',
                            onHeaderTap: () {
                              Navigator.of(context).pop();
                            },
                            headerBuilder: (context, onTap) => Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Recommended for "${liveChain.title}"',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.grid_view,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      // If video was added to chain, refresh recommendations
                      if (result == true && mounted) {
                        _loadRecommendations();
                      }
                    },
                    child: Stack(
                      children: [
                        VideoThumbnail(
                          video: video,
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