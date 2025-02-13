import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../providers/auth_provider.dart';
import '../services/cloudinary_service.dart';
import 'ai_video_screen.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final TextEditingController _descriptionController = TextEditingController();
  dynamic _videoFile;
  String? _videoFileName;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video != null) {
      if (kIsWeb) {
        // For web, read the file as bytes
        final bytes = await video.readAsBytes();
        if (mounted) {
          setState(() {
            _videoFile = bytes;
            _videoFileName = video.name;
          });
        }
      } else {
        // For mobile, use File
        setState(() {
          _videoFile = File(video.path);
          _videoFileName = video.name;
        });
      }
    }
  }

  Future<void> _generateAIVideo() async {
    final videoId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const AIVideoScreen(),
      ),
    );

    if (videoId != null && mounted) {
      Navigator.pop(context, videoId);
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video first')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Upload to Cloudinary
      final urls = await _cloudinaryService.uploadVideo(
        _videoFile,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      // Get the current user
      final user = context.read<AuthProvider>().user;
      if (user == null) throw Exception('User not authenticated');

      // Use VideoProvider to handle the upload
      final videoId = await context.read<VideoProvider>().uploadVideo(
        userId: user.uid,
        videoUrl: urls.videoUrl,
        thumbnailUrl: urls.thumbnailUrl,
        description: _descriptionController.text,
      );

      if (mounted && videoId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );
        // Return the new video ID to the previous screen
        Navigator.pop(context, videoId);
      }
    } catch (e) {
      print('Error uploading video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading video: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickVideo,
                    icon: const Icon(Icons.video_library),
                    label: const Text('Select Video'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _generateAIVideo,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate AI Video'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_videoFileName != null)
              Text(
                'Selected video: $_videoFileName',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !_isUploading,
            ),
            const SizedBox(height: 16),
            if (_isUploading)
              Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%'),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _videoFile != null ? _uploadVideo : null,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload Video'),
              ),
          ],
        ),
      ),
    );
  }
} 