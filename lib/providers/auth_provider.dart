import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/shared_prefs_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;
  bool _hasInitialized = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;
  bool get hasInitialized => _hasInitialized;

  StreamSubscription? _authSub;

  AuthProvider() {
    _init();
  }

  void _init() async {
    await _checkExistingSession();

    _authSub = _authService.authStateChanges.listen((firebaseUser) async {
      if (!_hasInitialized) return;

      if (firebaseUser == null) {
        if (_isAuthenticated || _currentUser != null) {
          _currentUser = null;
          _isAuthenticated = false;
          await SharedPrefsService.clearUserSession();
          notifyListeners();
        }
        return;
      }

      if (_currentUser?.uid == firebaseUser.uid && _isAuthenticated && firebaseUser.emailVerified) {
        return;
      }

      if (firebaseUser.emailVerified) {
        _isLoading = true;
        notifyListeners();
        await _loadUserData(firebaseUser);
        _isLoading = false;
        notifyListeners();
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        await SharedPrefsService.clearUserSession();
        notifyListeners();
      }
    }, onError: (e) {
      _currentUser = null;
      _isAuthenticated = false;
      _isLoading = false;
      _errorMessage = 'Authentication stream error.';
      notifyListeners();
    });
  }

  Future<void> _loadUserData(User firebaseUser) async {
    final profile = await _authService.getUserData(firebaseUser.uid);

    final UserModel userModel;
    if (profile != null) {
      userModel = profile;
    } else {
      userModel = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        phone: firebaseUser.phoneNumber ?? '',
        role: 'passenger',
      );
    }

    _currentUser = userModel;
    _isAuthenticated = true;

    await SharedPrefsService.saveUserSession(
      userId: userModel.uid,
      email: userModel.email,
      name: userModel.name ?? '',
      phone: userModel.phone ?? '',
      role: userModel.role,
    );
  }

  Future<void> _checkExistingSession() async {
    _isLoading = true;
    _hasInitialized = false;

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        await firebaseUser.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;

        if (refreshedUser != null && refreshedUser.emailVerified) {
          await _loadUserData(refreshedUser);
        } else {
          _currentUser = null;
          _isAuthenticated = false;
          await SharedPrefsService.clearUserSession();
        }
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        await SharedPrefsService.clearUserSession();
      }
    } catch (e) {
      _currentUser = null;
      _isAuthenticated = false;
      await SharedPrefsService.clearUserSession();
    } finally {
      _isLoading = false;
      _hasInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> signupUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email.trim(), password: password);

      final user = userCredential.user;
      if (user == null) {
        throw Exception('User creation failed.');
      }

      await user.updateDisplayName(name);
      await user.sendEmailVerification();

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unknown error occurred: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeSignup({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || !firebaseUser.emailVerified) {
      _errorMessage = 'User not found or email not yet verified.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.setUserDataAfterVerification(
        uid: firebaseUser.uid,
        name: name,
        phone: phone,
        role: role,
        email: email,
      );

      await _loadUserData(firebaseUser);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Profile completion failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userModel = await _authService.signInWithEmail(
          email: email.trim(),
          password: password
      );

      if (userModel != null) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          await _loadUserData(firebaseUser);
        } else {
          throw Exception('Firebase user object is null after successful sign-in.');
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to load user profile after sign-in.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-credential':
          _errorMessage = 'Invalid email or password. Please check your credentials.';
          break;
        case 'user-not-found':
          _errorMessage = 'No account found with this email address.';
          break;
        case 'wrong-password':
          _errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'email-not-verified':
          _errorMessage = 'Please verify your email address before signing in.';
          break;
        default:
          _errorMessage = e.message ?? 'Sign in failed. Please try again.';
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateUser({required String name, String? phone}) async {
    if (_currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.updateUserProfile(
        uid: _currentUser!.uid,
        name: name,
        phone: phone,
      );

      _currentUser = _currentUser!.copyWith(
        name: name,
        phone: phone,
      );

      await SharedPrefsService.saveUserSession(
        userId: _currentUser!.uid,
        email: _currentUser!.email,
        name: name,
        phone: phone ?? '',
        role: _currentUser!.role,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update profile: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Password change failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await SharedPrefsService.clearUserSession();

      _currentUser = null;
      _isAuthenticated = false;
      _errorMessage = null;
      _isLoading = false;

      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 100));

      await _authService.signOut();

      notifyListeners();

    } catch (e) {
      _currentUser = null;
      _isAuthenticated = false;
      _isLoading = false;
      _errorMessage = null;

      notifyListeners();

      rethrow;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}