import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('User creation failed');
    }

    await _createUserDocIfNeeded(
      user: user,
      username: username,
    );

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
    final googleUser = await GoogleSignIn.instance.authenticate();

    final googleAuth = googleUser.authentication;

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

  Future<void> _createUserDocIfNeeded({
    required User user,
    String? username,
  }) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'email': user.email ?? '',
        'username': username ?? user.displayName ?? '',
        'displayName': user.displayName ?? username ?? '',
        'photoUrl': user.photoURL ?? '',
        'favoriteItemIds': {
          'movies': [],
          'shows': [],
          'books': [],
          'games': [],
        },
        'derivedPreferences': {
          'favoriteDomains': [],
          'topGenres': [],
          'topTags': [],
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
        'displayName': user.displayName ?? '',
        'photoUrl': user.photoURL ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> logout() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}