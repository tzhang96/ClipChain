import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ReplicateService {
  final FirebaseFunctions _functions;
  
  static Future<ReplicateService> create() async {
    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: '.env');
      }
      
      // Use the singleton instance configured in main.dart
      final functions = FirebaseFunctions.instance;
      print('ReplicateService: Using Firebase Functions instance');
      
      return ReplicateService._(functions);
    } catch (e) {
      print('ReplicateService: Error during initialization: $e');
      rethrow;
    }
  }
  
  ReplicateService._(this._functions);

  Future<String> generateVideo({
    required String prompt,
    String aspectRatio = '9:16',
  }) async {
    try {
      print('ReplicateService: Starting video generation...');
      print('ReplicateService: Parameters - prompt: $prompt, aspectRatio: $aspectRatio');
      
      // Call the Cloud Function
      final HttpsCallable callable = _functions.httpsCallable(
        'generateVideo',
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 5), // Increase timeout for video generation
        ),
      );
      
      print('ReplicateService: Calling Cloud Function...');
      
      final result = await callable.call({
        'prompt': prompt,
        'aspectRatio': aspectRatio,
      });
      
      print('ReplicateService: Cloud Function response received');
      print('ReplicateService: Raw response: ${result.data}');
      
      final videoUrl = result.data['videoUrl'] as String?;
      if (videoUrl == null) {
        throw Exception('No video URL in response');
      }

      print('ReplicateService: Generation successful, output URL: $videoUrl');
      return videoUrl;
    } catch (e, stackTrace) {
      print('ReplicateService: Error during video generation: $e');
      print('ReplicateService: Stack trace: $stackTrace');
      rethrow;
    }
  }
} 