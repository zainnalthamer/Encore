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
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanUsername = username.trim();
    final cleanPhotoUrl = photoUrl.trim();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('User creation failed');
    }

    await user.updateDisplayName(cleanName);

    if (cleanPhotoUrl.isNotEmpty) {
      await user.updatePhotoURL(cleanPhotoUrl);
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': cleanEmail,
      'name': cleanName,
      'username': cleanUsername,
      'usernameLower': cleanUsername.toLowerCase(),
      'displayName': cleanName,
      'bio': bio.trim(),
      'photoUrl': cleanPhotoUrl,
      'avatarUrl': cleanPhotoUrl,
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
      email: email.trim().toLowerCase(),
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

    final displayName = (user.displayName ?? username ?? 'User').trim();
    final generatedUsername = _generateUsername(
      username ?? user.displayName ?? user.email ?? 'user',
    );

    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': (user.email ?? '').trim().toLowerCase(),
        'name': displayName,
        'username': generatedUsername,
        'usernameLower': generatedUsername.toLowerCase(),
        'displayName': displayName,
        'bio': '',
        'photoUrl': user.photoURL ?? '',
        'avatarUrl': user.photoURL ?? '',
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
      final data = snapshot.data() ?? {};

      final existingUsername = (data['username'] ?? generatedUsername)
          .toString()
          .trim();

      await userDoc.update({
        'email': (user.email ?? data['email'] ?? '').toString().trim().toLowerCase(),
        'name': user.displayName ?? data['name'] ?? displayName,
        'displayName': user.displayName ?? data['displayName'] ?? displayName,
        'username': existingUsername,
        'usernameLower': existingUsername.toLowerCase(),
        'photoUrl': user.photoURL ?? data['photoUrl'] ?? '',
        'avatarUrl': user.photoURL ?? data['avatarUrl'] ?? data['photoUrl'] ?? '',
        'headerImageUrl': data['headerImageUrl'] ?? '',
        'followers': data['followers'] ?? <String>[],
        'following': data['following'] ?? <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    required String bio,
    required String photoUrl,
    required String headerImageUrl,
  }) async {
    final currentUser = _auth.currentUser;
    final cleanName = name.trim();
    final cleanPhotoUrl = photoUrl.trim();

    await _firestore.collection('users').doc(uid).update({
      'name': cleanName,
      'displayName': cleanName,
      'bio': bio.trim(),
      'photoUrl': cleanPhotoUrl,
      'avatarUrl': cleanPhotoUrl,
      'headerImageUrl': headerImageUrl.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (currentUser != null && currentUser.uid == uid) {
      await currentUser.updateDisplayName(cleanName);

      if (cleanPhotoUrl.isNotEmpty) {
        await currentUser.updatePhotoURL(cleanPhotoUrl);
      }
    }
  }

  String _generateUsername(String value) {
    final base = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'@.*$'), '')
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (base.isEmpty) {
      return 'user_${DateTime.now().millisecondsSinceEpoch}';
    }

    return base;
  }

  Future<void> logout() async {
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }

    await _auth.signOut();
  }
}