import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../types/firestore_types.dart';
import '../screens/feed_screen.dart';
import '../screens/main_grid_screen.dart';

/// Represents where a video feed came from and how to navigate back to it
abstract class FeedSource {
  String get title;
  Widget buildReturnScreen();
}

/// A feed of videos from a user's profile
class ProfileFeedSource extends FeedSource {
  final String userId;
  final String username;

  ProfileFeedSource({
    required this.userId,
    required this.username,
  });

  @override
  String get title => username;

  @override
  Widget buildReturnScreen() => ProfileScreen(userId: userId);
}

/// A feed of videos from a chain
class ChainFeedSource extends FeedSource {
  final ChainDocument chain;
  final String username;  // Chain creator's username

  ChainFeedSource({
    required this.chain,
    required this.username,
  });

  @override
  String get title => chain.title;

  @override
  Widget buildReturnScreen() {
    return ProfileScreen(userId: chain.userId);
  }
}

/// A feed of videos from search results
class SearchFeedSource extends FeedSource {
  final String searchQuery;
  final List<VideoDocument> results;

  SearchFeedSource({
    required this.searchQuery,
    required this.results,
  });

  @override
  String get title => 'Search: $searchQuery';

  @override
  Widget buildReturnScreen() {
    // TODO: Return to search screen with results
    throw UnimplementedError();
  }
}

/// The main feed of videos
class MainFeedSource extends FeedSource {
  @override
  String get title => 'For You';

  @override
  Widget buildReturnScreen() {
    print('MainFeedSource: Building return screen (MainGridScreen)');
    print('MainFeedSource: Creating new MainGridScreen instance');
    final screen = const MainGridScreen();
    print('MainFeedSource: MainGridScreen instance created');
    return screen;
  }
} 