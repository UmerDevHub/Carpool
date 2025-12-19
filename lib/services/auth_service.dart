import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- New Method: Set Initial User Data (Called AFTER Email Verification) ---
  Future<void> setUserDataAfterVerification({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      final newUser = UserModel(
        uid: uid,
        email: email,
        phone: phone,
        name: name,
        role: role,
      );

      await _firestore.collection('users').doc(uid).set(newUser.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password and return full UserModel
  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Attempt to sign in with Firebase Auth
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'sign-in-failed',
          message: 'Sign in failed. Please try again.',
        );
      }

      // Check if email is verified
      if (!user.emailVerified) {
        // Sign out the user since they're not verified
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email address before signing in.',
        );
      }

      // Try to load Firestore profile
      final existing = await getUserData(user.uid);
      if (existing != null) return existing;

      // If no document exists, create a default profile
      final defaultModel = UserModel(
        uid: user.uid,
        email: user.email ?? email,
        name: user.displayName ?? '',
        phone: user.phoneNumber ?? '',
        role: 'passenger',
      );

      await _firestore.collection('users').doc(user.uid).set(defaultModel.toMap());
      return defaultModel;

    } on FirebaseAuthException catch (e) {
      // Let Firebase Auth exceptions bubble up with their original error codes
      print('AuthService FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      // Catch any other errors and wrap them
      print('AuthService error: $e');
      throw Exception('An error occurred during sign in: ${e.toString()}');
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data is Map<String, dynamic>) {
        // Assuming UserModel.fromMap handles the map data structure correctly
        // and needs the UID passed separately if it's not in the map.
        return UserModel.fromMap(data, uid);
      }
      return null;
    } catch (e) {
      print('AuthService.getUserData error: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (updates.isEmpty) return;
    await _firestore.collection('users').doc(uid).update(updates);
  }

  // Change Password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    if (user.email == null) {
      throw Exception('Password cannot be changed for a user without an email.');
    }

    try {
      // Re-authenticate the user
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(cred);

      // Update the password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}