import 'dart:io';
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

  /// Generates a thumbnail URL from a video URL using Cloudinary transformations
  String generateThumbnailUrl(String videoUrl) {
    try {
      // Extract the base URL and video path
      final urlParts = videoUrl.split('/upload/');
      if (urlParts.length != 2) return videoUrl;

      // Apply transformations for thumbnail
      final transformations = [
        'w_480',           // Width: 480px
        'h_854',           // Height: 854px (16:9 aspect ratio)
        'c_fill',          // Fill mode
        'q_auto:low',     // Low quality for thumbnails for performance
        'f_jpg',           // Output format
        'so_0',            // Take thumbnail from start of video
        'e_preview:duration_2', // 2-second preview image
      ].join(',');
      
      return '${urlParts[0]}/upload/$transformations/${urlParts[1]}';
    } catch (e) {
      print('CloudinaryService: Error generating thumbnail URL: $e');
      return videoUrl;
    }
  }

  /// Generates an optimized video URL with Cloudinary transformations
  String getOptimizedVideoUrl(String videoUrl) {
    try {
      // Extract the base URL and video path
      final urlParts = videoUrl.split('/upload/');
      if (urlParts.length != 2) return videoUrl;

      // If the URL already contains any transformations, return the original URL
      if (urlParts[1].startsWith('f_') || urlParts[1].contains('/f_')) {
        print('CloudinaryService: URL already has transformations, returning as is');
        return videoUrl;
      }

      // Apply transformations optimized for emulator performance
      final transformations = [
        'f_mp4',           // Force MP4 format
        'vs_20',           // Very low video sampling (reduces quality but improves performance)
        'w_360',           // Width: 360px (lower resolution)
        'h_640',           // Height: 640px (16:9 aspect ratio)
        'c_limit',         // Limit mode to prevent upscaling
        'q_auto:low',      // Lowest quality
        'ac_none',         // Remove audio if not needed
        'br_500k',         // Limit bitrate to 500k
      ].join(',');
      
      final optimizedUrl = '${urlParts[0]}/upload/$transformations/${urlParts[1]}';
      print('CloudinaryService: Generated optimized URL: $optimizedUrl');
      return optimizedUrl;
    } catch (e) {
      print('CloudinaryService: Error generating optimized URL: $e');
      return videoUrl;  // Return original URL if transformation fails
    }
  }

  /// Checks if a URL is a Cloudinary URL
  bool isCloudinaryUrl(String url) {
    return url.contains('cloudinary.com');
  }
} 