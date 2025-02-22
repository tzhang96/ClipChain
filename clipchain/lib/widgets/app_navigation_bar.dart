import 'package:flutter/material.dart';
import '../screens/create_screen.dart';

class AppNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onFeedTap;
  final Function(String?) onVideoUploaded;
  final Function(String?) onProfileTap;

  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onFeedTap,
    required this.onVideoUploaded,
    required this.onProfileTap,
  });

  void _onNavBarTap(BuildContext context, int index) async {
    if (index == 1) {
      // Open create screen when "Create" is tapped
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const CreateScreen(),
        ),
      );

      // If we got back a video or chain ID, pass it to the appropriate handler
      if (result != null) {
        onVideoUploaded(result);
      }
    } else if (index == 0) {
      onFeedTap(index);
    } else if (index == 2) {
      onProfileTap(null); // null means show current user's profile
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: (index) => _onNavBarTap(context, index),
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
    );
  }
} 