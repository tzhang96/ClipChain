import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class TestVideoScreen extends StatefulWidget {
  const TestVideoScreen({super.key});

  @override
  State<TestVideoScreen> createState() => _TestVideoScreenState();
}

class _TestVideoScreenState extends State<TestVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();
  
  String _userId = '';
  String _videoUrl = '';
  String _thumbnailUrl = '';
  String _description = '';
  bool _isLoading = false;

  Future<void> _createTestVideo() async {
    if (!_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();
    
    setState(() => _isLoading = true);
    
    try {
      final videoId = await _storageService.createVideoDocument(
        userId: _userId,
        videoUrl: _videoUrl,
        thumbnailUrl: _thumbnailUrl,
        description: _description,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video document created with ID: $videoId')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Test Video'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  helperText: 'The ID of the user who owns this video',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a user ID' : null,
                onSaved: (value) => _userId = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Video URL',
                  helperText: 'The Storage download URL of the video',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter the video URL' : null,
                onSaved: (value) => _videoUrl = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Thumbnail URL',
                  helperText: 'The Storage download URL of the thumbnail',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter the thumbnail URL' : null,
                onSaved: (value) => _thumbnailUrl = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  helperText: 'A description of the video',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a description' : null,
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createTestVideo,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Video Document'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 