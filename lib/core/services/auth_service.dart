import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
    required String username,
    required String photoUrl,
    String bio = '',
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('User creation failed');
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'name': name,
      'username': username,
      'displayName': name,
      'bio': bio.trim(),
      'photoUrl': photoUrl,
      'headerImageUrl': '',
      'followers': <String>[],
      'following': <String>[],
      'favoriteItemIds': {
        'movies': <String>[],
        'shows': <String>[],
        'books': <String>[],
        'games': <String>[],
      },
      'derivedPreferences': {
        'favoriteDomains': <String>[],
        'topGenres': <String>[],
        'topTags': <String>[],
      },
      'onboardingCompleted': false,
      'authProvider': 'password',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');

      final userCredential = await _auth.signInWithPopup(googleProvider);
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Google sign-in failed');
      }

      await _createUserDocIfNeeded(user: user);
      return userCredential;
    } else {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Google sign-in failed');
      }

      await _createUserDocIfNeeded(user: user);
      return userCredential;
    }
  }

  Future<void> _createUserDocIfNeeded({
    required User user,
    String? username,
  }) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? username ?? '',
        'username': username ?? user.displayName ?? '',
        'displayName': user.displayName ?? username ?? '',
        'bio': '',
        'photoUrl': user.photoURL ?? '',
        'headerImageUrl': '',
        'followers': <String>[],
        'following': <String>[],
        'favoriteItemIds': {
          'movies': <String>[],
          'shows': <String>[],
          'books': <String>[],
          'games': <String>[],
        },
        'derivedPreferences': {
          'favoriteDomains': <String>[],
          'topGenres': <String>[],
          'topTags': <String>[],
        },
        'onboardingCompleted': false,
        'authProvider': user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : 'unknown',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userDoc.update({
        'email': user.email ?? '',
        'name': user.displayName ?? snapshot.data()?['name'] ?? '',
        'displayName': user.displayName ?? snapshot.data()?['displayName'] ?? '',
        'photoUrl': user.photoURL ?? snapshot.data()?['photoUrl'] ?? '',
        'headerImageUrl': snapshot.data()?['headerImageUrl'] ?? '',
        'followers': snapshot.data()?['followers'] ?? <String>[],
        'following': snapshot.data()?['following'] ?? <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> logout() async {
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }
}