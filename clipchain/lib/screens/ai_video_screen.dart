import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../providers/auth_provider.dart';
import '../services/replicate_service.dart';
import '../services/cloudinary_service.dart';

class AIVideoScreen extends StatefulWidget {
  const AIVideoScreen({super.key});

  @override
  State<AIVideoScreen> createState() => _AIVideoScreenState();
}

class _AIVideoScreenState extends State<AIVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  late Future<ReplicateService> _replicateServiceFuture;
  final _cloudinaryService = CloudinaryService();
  
  final _promptController = TextEditingController();
  bool _isGenerating = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _replicateServiceFuture = ReplicateService.create();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateAndUploadVideo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
      _uploadProgress = 0.0;
    });

    try {
      // Get current user
      final user = context.read<AuthProvider>().user;
      if (user == null) throw Exception('User not authenticated');

      // Show generating message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating video... This may take a few minutes.')),
        );
      }

      // Get the initialized service
      final replicateService = await _replicateServiceFuture;

      // Generate video using Replicate
      final videoUrl = await replicateService.generateVideo(
        prompt: _promptController.text,
        aspectRatio: '9:16', // Hardcoded to mobile ratio
      );

      if (!mounted) return;

      // Show uploading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video generated! Uploading to Cloudinary...')),
      );

      // Upload to Cloudinary
      final urls = await _cloudinaryService.uploadVideoFromUrl(
        videoUrl,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      if (!mounted) return;

      // Upload video metadata
      final videoId = await context.read<VideoProvider>().uploadVideo(
        userId: user.uid,
        videoUrl: urls.videoUrl,
        thumbnailUrl: urls.thumbnailUrl,
        description: _promptController.text,
      );

      if (!mounted) return;

      if (videoId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );
        Navigator.pop(context, videoId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate AI Video'),
      ),
      body: FutureBuilder<ReplicateService>(
        future: _replicateServiceFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error initializing AI service: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                      labelText: 'Video Description',
                      helperText: 'Describe what you want in the video',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a description' : null,
                    enabled: !_isGenerating,
                  ),
                  const SizedBox(height: 24),
                  if (_isGenerating) ...[
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                      _uploadProgress > 0
                          ? 'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%'
                          : 'Generating video...',
                      textAlign: TextAlign.center,
                    ),
                  ] else
                    ElevatedButton.icon(
                      onPressed: _generateAndUploadVideo,
                      icon: const Icon(Icons.movie_creation),
                      label: const Text('Generate Video'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 