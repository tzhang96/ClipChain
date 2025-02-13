import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloudinary_sdk/cloudinary_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/cloudinary_config.dart';
import 'package:crypto/crypto.dart';

class CloudinaryService {
  final Cloudinary _cloudinary;
  final String _cloudName;
  final String _apiKey;
  final String _apiSecret;
  
  CloudinaryService() : 
    _cloudinary = CloudinaryConfig.instance,
    _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '',
    _apiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '',
    _apiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  /// Uploads a video file to Cloudinary and returns both video and thumbnail URLs
  Future<({String videoUrl, String thumbnailUrl})> uploadVideo(dynamic videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      print('CloudinaryService: Starting video upload...');
      
      // Create upload resource with explicit authentication
      final resource = CloudinaryUploadResource(
        filePath: kIsWeb ? null : (videoFile as File).path,
        fileBytes: kIsWeb ? videoFile as Uint8List : null,
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

  /// Upload a video from a URL to Cloudinary
  Future<({String videoUrl, String thumbnailUrl})> uploadVideoFromUrl(
    String sourceUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      print('CloudinaryService: Starting video upload from URL...');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Convert to seconds
      final publicId = 'video_$timestamp';
      
      // Since this is a URL upload, we'll simulate progress in three stages
      if (onProgress != null) {
        onProgress(0.1); // Started
      }

      // Construct the upload URL
      final uploadUrl = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/upload'
      );

      if (onProgress != null) {
        onProgress(0.3); // Request sent
      }

      print('CloudinaryService: Creating signed upload request...');

      // Create signature for signed upload - only include the parameters that need to be signed
      final paramsToSign = {
        'timestamp': timestamp.toString(),
        'folder': 'videos',
        'public_id': publicId,
      };
      
      final signature = generateSignature(paramsToSign);
      print('CloudinaryService: Signature generated successfully');

      // Make the upload request with signed parameters
      final response = await http.post(
        uploadUrl,
        body: {
          'file': sourceUrl,
          'api_key': _apiKey,
          'timestamp': timestamp.toString(),
          'signature': signature,
          'public_id': publicId,
          'folder': 'videos',
          'resource_type': 'video',
        },
      );

      if (onProgress != null) {
        onProgress(0.7); // Response received
      }

      print('CloudinaryService: Upload response status: ${response.statusCode}');
      print('CloudinaryService: Upload response body: ${response.body}');

      if (response.statusCode != 200) {
        print('CloudinaryService: Upload failed with status ${response.statusCode}');
        throw Exception('Failed to upload video: ${response.body}');
      }

      // Parse the JSON response
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final videoUrl = responseData['secure_url'] as String?;
      
      if (videoUrl == null) {
        throw Exception('No secure URL in Cloudinary response');
      }

      // Generate thumbnail URL
      final thumbnailUrl = generateThumbnailUrl(videoUrl);

      if (onProgress != null) {
        onProgress(1.0); // Complete
      }

      print('CloudinaryService: Upload successful. Video URL: $videoUrl');
      print('CloudinaryService: Generated thumbnail URL: $thumbnailUrl');
      
      return (videoUrl: videoUrl, thumbnailUrl: thumbnailUrl);
    } catch (e, stackTrace) {
      print('CloudinaryService: Error uploading video from URL: $e');
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

  /// Extracts the public ID from a Cloudinary URL
  String extractPublicId(String url) {
    // Extract public ID from the URL
    final regex = RegExp(r'v\d+/(.+?)\.');
    final match = regex.firstMatch(url);
    if (match == null) throw Exception('Invalid Cloudinary URL format');
    final publicId = match.group(1);
    if (publicId == null) throw Exception('Could not extract public ID from URL');
    return publicId;
  }

  /// Deletes a video and its thumbnail from Cloudinary
  Future<void> deleteVideo(String videoUrl, String? thumbnailUrl) async {
    try {
      print('CloudinaryService: Starting video deletion...');

      if (!isCloudinaryUrl(videoUrl)) {
        throw Exception('Invalid Cloudinary video URL');
      }

      // Extract public IDs (keep the folder prefix)
      final videoPublicId = extractPublicId(videoUrl);
      String? thumbnailPublicId;
      if (thumbnailUrl != null && isCloudinaryUrl(thumbnailUrl)) {
        thumbnailPublicId = extractPublicId(thumbnailUrl);
      }

      print('CloudinaryService: Deleting video with public ID: $videoPublicId');

      // Generate timestamp and signature for authentication
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Convert to seconds
      final toSign = {
        'public_id': videoPublicId, // Don't add videos/ prefix here, it's already in the extracted ID
        'timestamp': timestamp.toString(),
      };
      
      final signature = generateSignature(toSign);

      // Delete video using HTTP POST request
      final deleteUrl = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/destroy'
      );

      final response = await http.post(
        deleteUrl,
        body: {
          'public_id': videoPublicId, // Use the ID as extracted from URL
          'api_key': _apiKey,
          'timestamp': timestamp.toString(),
          'signature': signature,
          'resource_type': 'video',
        },
      );

      print('CloudinaryService: Video deletion response: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to delete video: ${response.body}');
      }

      // If there's a thumbnail, delete it too
      if (thumbnailPublicId != null) {
        final thumbnailTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final thumbnailToSign = {
          'public_id': thumbnailPublicId,
          'timestamp': thumbnailTimestamp.toString(),
        };
        
        final thumbnailSignature = generateSignature(thumbnailToSign);

        final thumbnailDeleteUrl = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/destroy'
        );

        final thumbnailResponse = await http.post(
          thumbnailDeleteUrl,
          body: {
            'public_id': thumbnailPublicId,
            'api_key': _apiKey,
            'timestamp': thumbnailTimestamp.toString(),
            'signature': thumbnailSignature,
            'resource_type': 'image',
          },
        );

        print('CloudinaryService: Thumbnail deletion response: ${thumbnailResponse.body}');

        if (thumbnailResponse.statusCode != 200) {
          print('CloudinaryService: Warning - Failed to delete thumbnail: ${thumbnailResponse.body}');
        }
      }

      print('CloudinaryService: Video deletion successful');
    } catch (e, stackTrace) {
      print('CloudinaryService: Error deleting video: $e');
      print('CloudinaryService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Generates a signature for Cloudinary API authentication
  String generateSignature(Map<String, String> paramsToSign) {
    final params = Map<String, String>.from(paramsToSign);
    final sortedKeys = params.keys.toList()..sort();
    // Build string to sign exactly as Cloudinary expects
    final stringToSign = sortedKeys
        .map((key) => '$key=${params[key]}')
        .join('&') + _apiSecret;
    
    print('CloudinaryService: String to sign - $stringToSign');
    
    final bytes = utf8.encode(stringToSign);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }
} 