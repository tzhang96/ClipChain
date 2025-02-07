import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/video_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/likes_provider.dart';
import 'providers/chain_provider.dart';

/// Handles all data initialization for the app
class AppDataInitializer extends StatefulWidget {
  final Widget child;
  
  const AppDataInitializer({
    super.key,
    required this.child,
  });

  @override
  State<AppDataInitializer> createState() => _AppDataInitializerState();
}

class _AppDataInitializerState extends State<AppDataInitializer> {
  bool _isLoading = false;
  String? _error;
  bool? _lastAuthState;

  @override
  void initState() {
    super.initState();
    // Schedule the first check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Schedule auth state check for next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();
    });
  }

  void _checkAuthState() {
    if (!mounted) return;
    
    final isAuthenticated = context.read<AuthProvider>().isAuthenticated;
    
    // Only trigger initialization if auth state changed to authenticated
    if (isAuthenticated && _lastAuthState != true) {
      _initializeData();
    }
    
    _lastAuthState = isAuthenticated;
  }

  Future<void> _initializeData() async {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final videoProvider = context.read<VideoProvider>();
    final authProvider = context.read<AuthProvider>();
    final likesProvider = context.read<LikesProvider>();
    final chainProvider = context.read<ChainProvider>();

    try {
      print('AppDataInitializer: Starting data initialization');
      
      if (!authProvider.isAuthenticated) {
        print('AppDataInitializer: Not authenticated, skipping initialization');
        setState(() => _isLoading = false);
        return;
      }

      print('AppDataInitializer: Loading data for authenticated user');
      
      // Load data sequentially to avoid state update conflicts
      await videoProvider.fetchVideos();
      print('AppDataInitializer: Videos loaded, count: ${videoProvider.videos.length}');
      
      if (mounted && authProvider.isAuthenticated) {
        final userId = authProvider.user!.uid;
        await Future.wait([
          likesProvider.loadUserLikes(userId),
          chainProvider.fetchUserChains(userId),
          chainProvider.loadUserLikedChains(userId),
        ]);
        print('AppDataInitializer: User data loaded');
      }

      print('AppDataInitializer: Data initialization complete');
    } catch (e) {
      print('AppDataInitializer: Error initializing app data: $e');
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;
    
    // Show login screen immediately if not authenticated
    if (!isAuthenticated) {
      return widget.child;
    }

    // Show error state if initialization failed
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show loading state while initializing
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    // Show the app once initialized
    return widget.child;
  }
} 