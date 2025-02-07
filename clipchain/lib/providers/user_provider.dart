import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../types/firestore_types.dart';

class UserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, UserDocument> _users = {};
  Map<String, bool> _loadingStates = {};
  Map<String, String?> _errors = {};

  bool isLoading(String userId) => _loadingStates[userId] ?? false;
  String? getError(String userId) => _errors[userId];
  UserDocument? getUser(String userId) => _users[userId];

  Future<void> fetchUser(String userId) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _loadingStates[userId] = true;
        _errors[userId] = null;
        notifyListeners();
      });

      final userDoc = await _firestore
          .collection(FirestorePaths.users)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      userData['id'] = userId;

      // Schedule state update after async complete
      Future.microtask(() {
        _users[userId] = UserDocument.fromMap(userData);
        _loadingStates[userId] = false;
        notifyListeners();
      });

    } catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _errors[userId] = 'Failed to fetch user: $e';
        _loadingStates[userId] = false;
        notifyListeners();
      });
    }
  }

  Future<void> updateUser(UserDocument user) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _loadingStates[user.id] = true;
        _errors[user.id] = null;
        notifyListeners();
      });

      await _firestore
          .collection(FirestorePaths.users)
          .doc(user.id)
          .update(user.toMap());

      // Schedule state update after async complete
      Future.microtask(() {
        _users[user.id] = user;
        _loadingStates[user.id] = false;
        notifyListeners();
      });

    } catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _errors[user.id] = 'Failed to update user: $e';
        _loadingStates[user.id] = false;
        notifyListeners();
      });
    }
  }
} 