import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
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
      
      await _authService.signUpWithEmailAndPassword(email, password);
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