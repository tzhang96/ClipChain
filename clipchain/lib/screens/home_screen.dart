import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'video_feed_screen.dart';
import 'upload_video_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? initialVideoId;

  const HomeScreen({
    super.key,
    this.initialVideoId,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<VideoFeedScreenState> _feedKey = GlobalKey();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // If we have an initial video ID, navigate to it after the first frame
    if (widget.initialVideoId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showVideo(widget.initialVideoId!);
      });
    }
  }

  void showVideo(String videoId) {
    setState(() => _selectedIndex = 0); // Switch to feed tab
    _feedKey.currentState?.navigateToVideo(videoId);
  }

  void _onNavBarTap(int index) async {
    if (index == 1) {
      // Open upload screen when "Create" is tapped
      final videoId = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const UploadVideoScreen(),
        ),
      );

      // If we got back a video ID, navigate to it in the feed
      if (videoId != null) {
        showVideo(videoId);
        // Refresh profile videos
        _profileKey.currentState?.refreshVideos();
      }
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          VideoFeedScreen(
            key: _feedKey,
            title: 'For You',
          ),
          Container(), // Placeholder for Create tab (handled by navigation)
          ProfileScreen(key: _profileKey), // Current user's profile
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavBarTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
} 