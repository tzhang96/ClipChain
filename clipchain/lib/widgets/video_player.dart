import 'package:cloudinary_sdk/cloudinary_sdk.dart';
import 'package:cloudinary_flutter/video/cld_video_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

class CloudinaryVideoPlayer extends StatefulWidget {
  final String publicId;
  
  const CloudinaryVideoPlayer({super.key, required this.publicId});

  @override
  State<CloudinaryVideoPlayer> createState() => _CloudinaryVideoPlayerState();
}

class _CloudinaryVideoPlayerState extends State<CloudinaryVideoPlayer> {
  late CldVideoController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    // Initialize with your cloud name if not using environment variables
    final cloudinary = Cloudinary.fromCloudName(cloudName: dotenv.env['CLOUDINARY_CLOUD_NAME']!);
    
    _controller = CldVideoController(
      cloudinary: cloudinary,
      publicId: widget.publicId,
      transformations: [
        Transformation()
          .quality('auto')
          .format('mp4')
          .streamingProfile('auto') // Required for adaptive streaming
      ],
    )..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : const Center(child: CircularProgressIndicator());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
} 