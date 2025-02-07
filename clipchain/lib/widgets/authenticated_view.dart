import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/profile_screen.dart';
import '../screens/video_feed_screen.dart';
import 'app_scaffold.dart';

class AuthenticatedView extends StatelessWidget {
  final Widget body;
  final int selectedIndex;

  const AuthenticatedView({
    super.key,
    required this.body,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: body,
      selectedIndex: selectedIndex,
      onFeedTap: (_) {
        // If not already in feed, navigate to it
        if (selectedIndex != 0) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const VideoFeedScreen(),
            ),
            (route) => false,
          );
        }
      },
      onVideoUploaded: (videoId) {
        if (videoId != null) {
          // Navigate to feed and show the new video
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => VideoFeedScreen(initialVideoId: videoId),
            ),
            (route) => false,
          );
        }
      },
      onProfileTap: (userId) {
        // Always navigate when:
        // 1. We're not on a profile screen (selectedIndex != 2), OR
        // 2. We're on a profile screen but viewing a different profile
        //    (userId is null means we want to view our own profile)
        final currentRoute = ModalRoute.of(context);
        if (currentRoute?.settings.name != '/profile' || 
            (currentRoute?.settings.arguments as String?) != userId) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: userId),
              settings: RouteSettings(
                name: '/profile',
                arguments: userId,
              ),
            ),
            (route) => false,
          );
        }
      },
    );
  }
} 