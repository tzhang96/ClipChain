import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../types/firestore_types.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  String? _error;
  bool _isLoading = false;

  User? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Initialize with current user
    _user = _authService.currentUser;
    
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signUp(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Create Firebase Auth user
      final userCredential = await _authService.signUpWithEmailAndPassword(email, password);
      final user = userCredential.user;
      if (user == null) throw Exception('Failed to create user');

      // Create user document in Firestore
      final username = email.split('@')[0]; // Use part before @ as username
      final userDoc = UserDocument(
        id: user.uid,
        email: email,
        username: username,
        photoUrl: null,
        bio: null,
        followers: [],
        following: [],
        createdAt: Timestamp.now(),
      );

      await _firestore
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .set(userDoc.toMap());

    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'An error occurred during sign up';
      rethrow;
    } catch (e) {
      _error = 'An unexpected error occurred';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _authService.signInWithEmailAndPassword(email, password);
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'An error occurred during sign in';
      rethrow;
    } catch (e) {
      _error = 'An unexpected error occurred';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      await _authService.signOut();
    } catch (e) {
      _error = 'Failed to sign out';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 