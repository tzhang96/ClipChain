import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../types/firestore_types.dart';
import '../providers/video_provider.dart';
import '../providers/likes_provider.dart';
import '../providers/chain_provider.dart';
import 'package:provider/provider.dart';

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
      Future.microtask(() {
        _user = user;
        notifyListeners();
      });
    });
  }

  Future<void> signUp(String email, String password) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoading = true;
        _error = null;
        notifyListeners();
      });

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

      // Auth state listener will handle the state update
    } on FirebaseAuthException catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _error = e.message ?? 'An error occurred during sign up';
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _error = 'An unexpected error occurred';
        _isLoading = false;
        notifyListeners();
      });
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoading = true;
        _error = null;
        notifyListeners();
      });

      await _authService.signInWithEmailAndPassword(email, password);

      // Auth state listener will handle the state update
    } on FirebaseAuthException catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _error = e.message ?? 'An error occurred during sign in';
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _error = 'An unexpected error occurred';
        _isLoading = false;
        notifyListeners();
      });
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      // Defer initial state update
      Future.microtask(() {
        _isLoading = true;
        _error = null;
        notifyListeners();
      });

      await _authService.signOut();

      // Clear all provider states
      Future.microtask(() {
        _user = null;
        _isLoading = false;
        // Clear any cached data that might cause conflicts
        context.read<VideoProvider>().clear();
        context.read<LikesProvider>().clear();
        context.read<ChainProvider>().clear();
        notifyListeners();
      });
    } catch (e) {
      // Schedule error state update
      Future.microtask(() {
        _error = 'Failed to sign out';
        _isLoading = false;
        notifyListeners();
      });
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 