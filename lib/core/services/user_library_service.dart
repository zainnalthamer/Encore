import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/onboarding_media_item.dart';

class UserLibraryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get uid {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _library {
    return _firestore.collection('users').doc(uid).collection('libraryItems');
  }

  CollectionReference<Map<String, dynamic>> get _activity {
    return _firestore.collection('users').doc(uid).collection('activity');
  }

  DocumentReference<Map<String, dynamic>> _libraryDoc(String itemId) {
    return _library.doc(itemId);
  }

  DocumentReference<Map<String, dynamic>> _itemStatsDoc(String itemId) {
    return _firestore.collection('items').doc(itemId);
  }

  CollectionReference<Map<String, dynamic>> _reviews(String itemId) {
    return _firestore.collection('items').doc(itemId).collection('reviews');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchItem(String itemId) {
    return _libraryDoc(itemId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchItemStats(String itemId) {
    return _itemStatsDoc(itemId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReviewsForItem(
    String itemId,
  ) {
    return _reviews(itemId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSaved() {
    return _library.where('isSaved', isEqualTo: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFavorites() {
    return _library.where('isFavorite', isEqualTo: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchActivity() {
    return _activity.limit(80).snapshots();
  }

  Future<void> toggleSaved({
    required OnboardingMediaItem item,
    required bool saved,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final libraryRef = _libraryDoc(item.id);
    final statsRef = _itemStatsDoc(item.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(libraryRef);
      final oldSaved = snapshot.data()?['isSaved'] == true;

      transaction.set(libraryRef, {
        ..._itemData(item),
        'isSaved': saved,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(userRef, {
        'savedItemIds.${item.domain}': saved
            ? FieldValue.arrayUnion([item.id])
            : FieldValue.arrayRemove([item.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (oldSaved != saved) {
        transaction.set(statsRef, {
          ..._itemData(item),
          'saveCount': FieldValue.increment(saved ? 1 : -1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });

    await _safeLogActivity(
      item: item,
      type: saved ? 'saved' : 'removed saved',
      text: saved ? 'Saved this item' : 'Removed from saved',
    );
  }

  Future<void> toggleFavorite({
    required OnboardingMediaItem item,
    required bool favorite,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final libraryRef = _libraryDoc(item.id);
    final statsRef = _itemStatsDoc(item.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(libraryRef);
      final oldFavorite = snapshot.data()?['isFavorite'] == true;
      final oldSaved = snapshot.data()?['isSaved'] == true;

      transaction.set(libraryRef, {
        ..._itemData(item),
        'isSaved': true,
        'isFavorite': favorite,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(userRef, {
        'savedItemIds.${item.domain}': FieldValue.arrayUnion([item.id]),
        'favoriteItemIds.${item.domain}': favorite
            ? FieldValue.arrayUnion([item.id])
            : FieldValue.arrayRemove([item.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final statsUpdate = <String, dynamic>{
        ..._itemData(item),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (oldFavorite != favorite) {
        statsUpdate['favoriteCount'] =
            FieldValue.increment(favorite ? 1 : -1);
      }

      if (!oldSaved) {
        statsUpdate['saveCount'] = FieldValue.increment(1);
      }

      transaction.set(statsRef, statsUpdate, SetOptions(merge: true));
    });

    await _safeLogActivity(
      item: item,
      type: favorite ? 'favorited' : 'unfavorited',
      text: favorite ? 'Added to favorites' : 'Removed from favorites',
    );
  }

  Future<void> updateStatus({
    required OnboardingMediaItem item,
    required String status,
  }) async {
    await _libraryDoc(item.id).set({
      ..._itemData(item),
      'isSaved': true,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _safeLogActivity(
      item: item,
      type: 'status',
      text: status,
    );
  }

  Future<void> updateRating({
    required OnboardingMediaItem item,
    required double rating,
  }) async {
    await _libraryDoc(item.id).set({
      ..._itemData(item),
      'isSaved': true,
      'userRating': rating,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _safeStatsUpdate(item, {
      'ratingSum': FieldValue.increment(rating),
      'ratingCount': FieldValue.increment(1),
      'saveCount': FieldValue.increment(1),
    });

    await _safeLogActivity(
      item: item,
      type: 'rated',
      text: 'Rated ${rating.toStringAsFixed(1)} / 5',
      rating: rating,
    );
  }

  Future<void> addReview({
    required OnboardingMediaItem item,
    required double rating,
    required String review,
    required String displayName,
    required String username,
    required String photoUrl,
  }) async {
    final cleanReview = review.trim();
    if (cleanReview.isEmpty) return;

    final reviewRef = _reviews(item.id).doc();

    await reviewRef.set({
      ..._itemData(item),
      'reviewId': reviewRef.id,
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
      'rating': rating,
      'review': cleanReview,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _libraryDoc(item.id).set({
      ..._itemData(item),
      'isSaved': true,
      'userRating': rating,
      'lastReview': cleanReview,
      'review': cleanReview,
      'reviewCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _safeStatsUpdate(item, {
      'reviewCount': FieldValue.increment(1),
    });

    await _safeLogActivity(
      item: item,
      type: 'reviewed',
      text: cleanReview,
      rating: rating,
      reviewId: reviewRef.id,
    );
  }

  Future<void> deleteReview({
    required OnboardingMediaItem item,
    required String reviewId,
  }) async {
    await _reviews(item.id).doc(reviewId).delete();

    await _libraryDoc(item.id).set({
      'reviewCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _safeStatsUpdate(item, {
      'reviewCount': FieldValue.increment(-1),
    });

    await _safeLogActivity(
      item: item,
      type: 'deleted review',
      text: 'Deleted a review',
    );
  }

  Future<void> _safeStatsUpdate(
    OnboardingMediaItem item,
    Map<String, dynamic> data,
  ) async {
    try {
      await _itemStatsDoc(item.id).set({
        ..._itemData(item),
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Stats update failed: $e');
    }
  }

  Future<void> _safeLogActivity({
    required OnboardingMediaItem item,
    required String type,
    required String text,
    double? rating,
    String? reviewId,
  }) async {
    try {
      await _activity.add({
        ..._itemData(item),
        'type': type,
        'activityType': type,
        'text': text,
        'review': text,
        'rating': rating,
        'userRating': rating,
        'reviewId': reviewId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Activity log failed: $e');
    }
  }

  Map<String, dynamic> _itemData(OnboardingMediaItem item) {
    return {
      'itemId': item.id,
      'title': item.title,
      'domain': item.domain,
      'imageUrl': item.imageUrl,
      'genres': item.genres,
      'tags': item.tags,
      'description': item.description,
      'source': item.source,
    };
  }
}