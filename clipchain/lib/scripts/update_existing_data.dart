import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../firebase_options.dart';
import '../types/firestore_types.dart';
import '../services/cloudinary_service.dart';
import '../config/cloudinary_config.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Cloudinary
  await CloudinaryConfig.initialize();

  final firestore = FirebaseFirestore.instance;
  final cloudinaryService = CloudinaryService();

  // 1. Create user documents for existing users
  print('\nProcessing users...');
  try {
    // Get all videos to find unique user IDs
    final videoSnapshot = await firestore.collection(FirestorePaths.videos).get();
    final userIds = videoSnapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['userId'] as String)
        .toSet(); // Using Set to get unique user IDs

    print('Found ${userIds.length} unique users');

    // For each user ID, check if they have a document and create if missing
    for (final userId in userIds) {
      final userDoc = await firestore.collection(FirestorePaths.users).doc(userId).get();
      
      if (!userDoc.exists) {
        print('Creating document for user $userId');
        
        // Create user document with placeholder data
        final newUserDoc = UserDocument(
          id: userId,
          email: 'user_$userId@example.com', // Placeholder email
          username: 'user_$userId', // Placeholder username
          photoUrl: null,
          bio: null,
          followers: [],
          following: [],
          createdAt: Timestamp.now(),
        );

        await firestore
            .collection(FirestorePaths.users)
            .doc(userId)
            .set(newUserDoc.toMap());
        
        print('Created user document for $userId');
      } else {
        print('User $userId already has a document');
      }
    }
  } catch (e) {
    print('Error processing users: $e');
  }

  // 2. Add thumbnails to videos without them
  print('\nProcessing videos...');
  try {
    final videoSnapshot = await firestore.collection(FirestorePaths.videos).get();
    final videosWithoutThumbnail = videoSnapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['thumbnailUrl'] == null);

    print('Found ${videosWithoutThumbnail.length} videos without thumbnails');

    for (final videoDoc in videosWithoutThumbnail) {
      final data = videoDoc.data() as Map<String, dynamic>;
      final videoUrl = data['videoUrl'] as String;
      
      try {
        print('Generating thumbnail for video ${videoDoc.id}');
        
        // Generate thumbnail URL using Cloudinary's video thumbnail feature
        final thumbnailUrl = cloudinaryService.generateThumbnailUrl(videoUrl);
        
        // Update the video document
        await firestore
            .collection(FirestorePaths.videos)
            .doc(videoDoc.id)
            .update({'thumbnailUrl': thumbnailUrl});
        
        print('Added thumbnail for video ${videoDoc.id}');
      } catch (e) {
        print('Error processing video ${videoDoc.id}: $e');
      }
    }
  } catch (e) {
    print('Error processing videos: $e');
  }

  print('\nScript completed!');
} 