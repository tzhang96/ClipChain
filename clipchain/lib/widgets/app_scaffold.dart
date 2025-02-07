import 'package:flutter/material.dart';
import 'app_navigation_bar.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final int selectedIndex;
  final Function(int) onFeedTap;
  final Function(String?) onVideoUploaded;
  final Function(String?) onProfileTap;

  const AppScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onFeedTap,
    required this.onVideoUploaded,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: selectedIndex,
        onFeedTap: onFeedTap,
        onVideoUploaded: onVideoUploaded,
        onProfileTap: onProfileTap,
      ),
    );
  }
} 