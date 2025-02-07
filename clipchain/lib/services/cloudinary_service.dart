import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloudinary_sdk/cloudinary_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/cloudinary_config.dart';

class CloudinaryService {
  final Cloudinary _cloudinary;
  
  CloudinaryService() : _cloudinary = CloudinaryConfig.instance;

  /// Uploads a video file to Cloudinary and returns both video and thumbnail URLs
  Future<({String videoUrl, String thumbnailUrl})> uploadVideo(File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      print('CloudinaryService: Starting video upload...');
      print('CloudinaryService: File path: ${videoFile.path}');
      
      // Create upload resource with explicit authentication
      final resource = CloudinaryUploadResource(
        filePath: videoFile.path,
        resourceType: CloudinaryResourceType.video,
        folder: 'videos',
        fileName: 'video_${DateTime.now().millisecondsSinceEpoch}',
        progressCallback: (count, total) {
          if (onProgress != null) {
            final progress = count / total;
            onProgress(progress);
          }
        },
        // Add upload preset for unsigned uploads
        uploadPreset: dotenv.env['CLOUDINARY_UPLOAD_PRESET'],
        publicId: 'video_${DateTime.now().millisecondsSinceEpoch}',
      );

      print('CloudinaryService: Uploading with cloud name: ${_cloudinary.cloudName}');
      final response = await _cloudinary.uploadResource(resource);

      if (!response.isSuccessful) {
        print('CloudinaryService: Upload failed with error: ${response.error}');
        throw Exception('Failed to upload video: ${response.error}');
      }

      if (response.secureUrl == null) {
        print('CloudinaryService: Upload succeeded but no secure URL returned');
        throw Exception('No URL returned from Cloudinary');
      }

      final videoUrl = response.secureUrl!;
      // Generate thumbnail URL by transforming the video URL
      final thumbnailUrl = generateThumbnailUrl(videoUrl);

      print('CloudinaryService: Upload successful. Video URL: $videoUrl');
      print('CloudinaryService: Generated thumbnail URL: $thumbnailUrl');
      
      return (videoUrl: videoUrl, thumbnailUrl: thumbnailUrl);
    } catch (e, stackTrace) {
      print('CloudinaryService: Error uploading video: $e');
      print('CloudinaryService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Generate a thumbnail URL for a video
  String generateThumbnailUrl(String videoUrl) {
    // Extract public ID from the video URL
    final regex = RegExp(r'v\d+/(.+?)\.');
    final match = regex.firstMatch(videoUrl);
    if (match == null) throw Exception('Invalid video URL format');
    final publicId = match.group(1);
    if (publicId == null) throw Exception('Could not extract public ID from URL');

    // Generate thumbnail URL with minimal transformations for performance
    return videoUrl
        .replaceAll('/video/upload/', '/video/upload/w_360,h_640,c_limit,q_auto:low/')
        .replaceAll('.mp4', '.jpg');
  }

  /// Generates an optimized video URL with Cloudinary transformations
  String getOptimizedVideoUrl(String videoUrl) {
    try {
      print('CloudinaryService: Original URL: $videoUrl');
      
      if (!videoUrl.contains('/upload/')) {
        print('CloudinaryService: Invalid URL format - missing /upload/');
        return videoUrl;
      }

      // Split URL at /upload/ to preserve the base URL structure
      final parts = videoUrl.split('/upload/');
      if (parts.length != 2) {
        print('CloudinaryService: Invalid URL structure');
        return videoUrl;
      }

      // Build transformation string with proper syntax
      final transformations = [
        'c_scale',         // Scale mode
        'w_320',           // Width
        'h_240',           // Height
        'q_auto:low',      // Auto quality, low setting
        'vc_h264',         // Force H.264 codec
        'f_mp4'            // Force MP4 format
      ].join(',');

      // Construct the final URL
      final transformedUrl = '${parts[0]}/upload/$transformations/${parts[1]}';

      print('CloudinaryService: Transformation parameters: $transformations');
      print('CloudinaryService: Generated URL: $transformedUrl');

      return transformedUrl;

    } catch (e, stackTrace) {
      print('CloudinaryService: Error generating optimized URL: $e');
      print('CloudinaryService: Stack trace: $stackTrace');
      return videoUrl;
    }
  }

  /// Checks if a URL is a Cloudinary URL
  bool isCloudinaryUrl(String url) {
    return url.contains('cloudinary.com');
  }
} 