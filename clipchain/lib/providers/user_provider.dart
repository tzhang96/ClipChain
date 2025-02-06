import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../types/firestore_types.dart';

class UserProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, UserDocument> _users = {};
  Map<String, bool> _loadingStates = {};
  Map<String, String?> _errors = {};

  UserDocument? getUser(String userId) => _users[userId];
  bool isLoading(String userId) => _loadingStates[userId] ?? false;
  String? getError(String userId) => _errors[userId];

  Future<UserDocument?> fetchUser(String userId) async {
    try {
      _loadingStates[userId] = true;
      _errors[userId] = null;
      notifyListeners();

      final docSnapshot = await _firestore
          .collection(FirestorePaths.users)
          .doc(userId)
          .get();

      if (!docSnapshot.exists) {
        _errors[userId] = 'User not found';
        return null;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      data['id'] = docSnapshot.id;
      
      final user = UserDocument.fromMap(data);
      _users[userId] = user;
      
      return user;
    } catch (e) {
      _errors[userId] = 'Failed to fetch user: $e';
      print(_errors[userId]);
      return null;
    } finally {
      _loadingStates[userId] = false;
      notifyListeners();
    }
  }
} 