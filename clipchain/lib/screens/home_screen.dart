import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'video_feed_screen.dart';
import 'upload_video_screen.dart';
import 'profile_screen.dart';
import 'main_feed_screen.dart';

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
  final MainFeedKey _feedKey = const MainFeedKey();
  String? _profileUserId;  // Add this to track which user's profile to show

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

  void showProfile(String userId) {
    setState(() {
      _selectedIndex = 2; // Switch to profile tab
      _profileUserId = userId;
    });
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
      }
    } else {
      setState(() {
        _selectedIndex = index;
        if (index == 2) {
          _profileUserId = null; // Reset to current user's profile when manually navigating
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MainFeedScreen(
            feedKey: _feedKey,
          ),
          Container(), // Placeholder for Create tab (handled by navigation)
          ProfileScreen(
            userId: _profileUserId,
          ),
        ],
      ),
    );
  }
} 