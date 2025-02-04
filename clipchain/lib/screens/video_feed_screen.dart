import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final PageController _pageController = PageController();
  List<VideoModel> _videos = [];
  int _currentPageIndex = 0;
  VideoPlayerController? _currentController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      setState(() {
        _videos = snapshot.docs
            .map((doc) => VideoModel.fromMap(
                {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
            .toList();
        _isLoading = false;
      });

      if (_videos.isNotEmpty) {
        _initializeVideo(0);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading videos: ${e.toString()}')),
      );
    }
  }

  Future<void> _initializeVideo(int index) async {
    if (index >= 0 && index < _videos.length) {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(_videos[index].videoUrl));

      await controller.initialize();
      controller.setLooping(true);
      
      if (mounted) {
        setState(() {
          if (_currentController != null) {
            _currentController!.pause();
            _currentController!.dispose();
          }
          _currentController = controller;
          _currentController!.play();
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return const Center(child: Text('No videos available'));
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      onPageChanged: (index) {
        setState(() => _currentPageIndex = index);
        _initializeVideo(index);
      },
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_currentController != null &&
                _currentPageIndex == index &&
                _currentController!.value.isInitialized)
              VideoPlayer(_currentController!)
            else
              const Center(child: CircularProgressIndicator()),
            
            // Video Info Overlay
            Positioned(
              bottom: 80,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${video.likes}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
} 