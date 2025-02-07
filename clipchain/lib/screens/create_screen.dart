import 'package:flutter/material.dart';
import 'upload_video_screen.dart';
import 'create_chain_screen.dart';
import '../widgets/authenticated_view.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthenticatedView(
      selectedIndex: 1, // Create tab is index 1
      body: Scaffold(
        appBar: AppBar(
          title: const Text('Create'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.video_library),
                text: 'Upload Video',
              ),
              Tab(
                icon: Icon(Icons.playlist_add),
                text: 'Create Chain',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            UploadVideoTab(),
            CreateChainTab(),
          ],
        ),
      ),
    );
  }
}

/// A wrapper around UploadVideoScreen to handle navigation properly
class UploadVideoTab extends StatelessWidget {
  const UploadVideoTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const UploadVideoScreen();
  }
}

/// The chain creation interface
class CreateChainTab extends StatelessWidget {
  const CreateChainTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateChainScreen();
  }
} 