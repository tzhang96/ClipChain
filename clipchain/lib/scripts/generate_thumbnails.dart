import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import '../services/cloudinary_service.dart';
import '../types/firestore_types.dart';
import '../config/cloudinary_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Cloudinary
  await CloudinaryConfig.initialize();
  
  await generateThumbnails();
}

Future<void> generateThumbnails() async {
  print('Starting thumbnail generation...');
  
  final cloudinary = CloudinaryService();
  final firestore = FirebaseFirestore.instance;
  
  try {
    // Get all videos without thumbnails
    final snapshot = await firestore
        .collection(FirestorePaths.videos)
        .where('thumbnailUrl', isNull: true)
        .get();
    
    print('Found ${snapshot.docs.length} videos without thumbnails');
    
    for (var doc in snapshot.docs) {
      try {
        final video = VideoDocument.fromMap({...doc.data(), 'id': doc.id});
        print('Processing video ${video.id}...');
        
        // Generate thumbnail URL
        final thumbnailUrl = cloudinary.generateThumbnailUrl(video.videoUrl);
        print('Generated thumbnail URL: $thumbnailUrl');
        
        // Update Firestore document
        await doc.reference.update({
          'thumbnailUrl': thumbnailUrl,
        });
        
        print('Updated video ${video.id} with thumbnail');
      } catch (e) {
        print('Error processing video ${doc.id}: $e');
        continue; // Continue with next video even if one fails
      }
    }
    
    print('Thumbnail generation complete!');
  } catch (e) {
    print('Error during thumbnail generation: $e');
  }
} 