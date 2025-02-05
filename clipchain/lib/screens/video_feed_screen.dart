import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  bool _isVideoInitializing = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      print('Starting to load videos...');
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      print('Firestore query complete. Found ${snapshot.docs.length} videos');
      
      setState(() {
        _videos = snapshot.docs
            .map((doc) => VideoModel.fromMap(
                {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
            .toList();
        _isLoading = false;
      });

      print('Videos loaded: ${_videos.length}');

      if (_videos.isNotEmpty) {
        print('Initializing first video...');
        _initializeVideo(0);
      } else {
        print('No videos found to initialize');
      }
    } catch (e) {
      print('Error loading videos: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading videos: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _cleanupCurrentController() async {
    if (_currentController != null) {
      await _currentController!.pause();
      await _currentController!.dispose();
      _currentController = null;
    }
  }

  Future<void> _initializeVideo(int index) async {
    if (_isVideoInitializing || index < 0 || index >= _videos.length) return;

    setState(() => _isVideoInitializing = true);

    try {
      await _cleanupCurrentController();

      String videoUrl = _videos[index].videoUrl;
      if (videoUrl.startsWith('gs://')) {
        String path = videoUrl.substring(5);
        String objectPath = path.substring(path.indexOf('/') + 1);
        final ref = FirebaseStorage.instance.ref(objectPath);
        videoUrl = await ref.getDownloadURL();
        print('Converted video URL: $videoUrl');
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      controller.setLooping(true);
      
      if (mounted) {
        setState(() {
          _currentController = controller;
          _isVideoInitializing = false;
        });
        
        // Only play if this is still the current page
        if (_currentPageIndex == index) {
          _currentController?.play();
        }
      }
    } catch (e) {
      print('Error initializing video: $e');
      setState(() => _isVideoInitializing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cleanupCurrentController();
    super.dispose();
  }

  void _onPageChanged(int index) async {
    setState(() => _currentPageIndex = index);
    await _initializeVideo(index);
  }

  @override
  Widget build(BuildContext context) {
    print('VideoFeedScreen build called. Loading: $_isLoading, Videos: ${_videos.length}');
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return const Center(child: Text('No videos available'));
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        
        return GestureDetector(
          onTap: () {
            // Toggle play/pause on tap
            if (_currentController?.value.isPlaying ?? false) {
              _currentController?.pause();
            } else {
              _currentController?.play();
            }
          },
          child: Stack(
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
          ),
        );
      },
    );
  }
} 