import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../types/firestore_types.dart';

/// Script to add chain-related collections to Firestore
Future<void> main() async {
  print('Starting chain collections setup...');

  try {
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');

    final firestore = FirebaseFirestore.instance;

    // Create chains collection with an example document to ensure it exists
    final chainRef = firestore.collection(FirestorePaths.chains).doc('example');
    await chainRef.set({
      'id': 'example',
      'userId': 'system',
      'title': 'Example Chain',
      'description': 'This is an example chain document to initialize the collection',
      'likes': 0,
      'videoIds': [],
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    print('Created chains collection with example document');

    // Create chainLikes collection with an example document
    final chainLikeRef = firestore.collection(FirestorePaths.chainLikes).doc('example');
    await chainLikeRef.set({
      'userId': 'system',
      'chainId': 'example',
      'createdAt': Timestamp.now(),
    });
    print('Created chainLikes collection with example document');

    // Clean up example documents
    await chainRef.delete();
    await chainLikeRef.delete();
    print('Cleaned up example documents');

    print('Chain collections setup complete!');
  } catch (e) {
    print('Error setting up chain collections: $e');
    rethrow;
  }
} 