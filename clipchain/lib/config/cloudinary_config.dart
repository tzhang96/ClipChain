import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloudinary_sdk/cloudinary_sdk.dart';

class CloudinaryConfig {
  static Cloudinary? _instance;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) {
      print('CloudinaryConfig: Already initialized, skipping...');
      return;
    }

    try {
      // Load .env file from the project root
      await dotenv.load();
      print('CloudinaryConfig: .env file loaded successfully');

      // Verify credentials are present
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final apiKey = dotenv.env['CLOUDINARY_API_KEY'];
      final apiSecret = dotenv.env['CLOUDINARY_API_SECRET'];

      // Only print cloud name as it's not sensitive
      print('CloudinaryConfig: Using cloud name: $cloudName');

      if (cloudName == null || cloudName.isEmpty) {
        throw Exception('CLOUDINARY_CLOUD_NAME is missing or empty in .env file');
      }
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('CLOUDINARY_API_KEY is missing or empty in .env file');
      }
      if (apiSecret == null || apiSecret.isEmpty) {
        throw Exception('CLOUDINARY_API_SECRET is missing or empty in .env file');
      }

      // Create instance immediately during initialization
      _instance = Cloudinary.full(
        apiKey: apiKey,
        apiSecret: apiSecret,
        cloudName: cloudName,
      );

      _isInitialized = true;
      print('CloudinaryConfig: Initialization complete');
    } catch (e) {
      print('CloudinaryConfig: Error initializing: $e');
      _isInitialized = false;
      _instance = null;
      rethrow;
    }
  }

  static Cloudinary get instance {
    if (_instance == null) {
      throw Exception('''
        Cloudinary not initialized. 
        Make sure to call CloudinaryConfig.initialize() before using it.
        Also verify that your .env file exists and contains the required credentials.
      ''');
    }
    return _instance!;
  }

  /// Force reinitialization (useful for testing or after hot reload)
  static Future<void> reinitialize() async {
    _isInitialized = false;
    _instance = null;
    await initialize();
  }
} 