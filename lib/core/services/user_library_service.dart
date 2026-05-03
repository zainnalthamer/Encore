import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/onboarding_media_item.dart';

class UserLibraryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  String _safeDocId(String value) {
    final cleaned = value
        .trim()
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('#', '_')
        .replaceAll('?', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('.', '_');

    if (cleaned.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }

    return cleaned;
  }

  DocumentReference<Map<String, dynamic>> _libraryItemRef(String itemId) {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('libraryItems')
        .doc(_safeDocId(itemId));
  }

  CollectionReference<Map<String, dynamic>> _activityRef() {
    return _db.collection('users').doc(_uid).collection('activity');
  }

  DocumentReference<Map<String, dynamic>> _itemRef(String itemId) {
    return _db.collection('items').doc(_safeDocId(itemId));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchItem(String itemId) {
    return _libraryItemRef(itemId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFavorites() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('libraryItems')
        .where('isFavorite', isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSaved() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('libraryItems')
        .where('isSaved', isEqualTo: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchActivity() {
    return _activityRef().orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchReviewsForItem(
    String itemId,
  ) {
    return _itemRef(itemId)
        .collection('reviews')
        .snapshots();
  }

  Future<void> toggleSaved({
  required OnboardingMediaItem item,
  required bool saved,
}) async {
  await _libraryItemRef(item.id).set(
    {
      ..._baseItemData(item),
      'isSaved': saved,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  try {
    await _activityRef().doc().set({
      ..._activityData(item),
      'type': saved ? 'saved' : 'unsaved',
      'activityType': saved ? 'saved' : 'unsaved',
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

Future<void> toggleFavorite({
  required OnboardingMediaItem item,
  required bool favorite,
}) async {
  await _libraryItemRef(item.id).set(
    {
      ..._baseItemData(item),
      'isFavorite': favorite,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  try {
    await _activityRef().doc().set({
      ..._activityData(item),
      'type': favorite ? 'favorited' : 'unfavorited',
      'activityType': favorite ? 'favorited' : 'unfavorited',
      'createdAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

  Future<void> updateStatus({
    required OnboardingMediaItem item,
    required String status,
  }) async {
    final batch = _db.batch();

    batch.set(
      _libraryItemRef(item.id),
      {
        ..._baseItemData(item),
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(_activityRef().doc(), {
      ..._activityData(item),
      'type': 'status',
      'activityType': 'status',
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> updateRating({
  required OnboardingMediaItem item,
  required double rating,
}) async {
  final batch = _db.batch();

  batch.set(
    _libraryItemRef(item.id),
    {
      ..._baseItemData(item),
      'userRating': rating,
      'rating': rating,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  batch.set(_activityRef().doc(), {
    ..._activityData(item),
    'type': 'rated',
    'activityType': 'rated',
    'userRating': rating,
    'rating': rating,
    'createdAt': FieldValue.serverTimestamp(),
  });

  await batch.commit();
}

  Future<void> addReview({
  required OnboardingMediaItem item,
  required double rating,
  required String review,
  required String displayName,
  required String username,
  required String photoUrl,
}) async {
  final user = _auth.currentUser;
  if (user == null) {
    throw Exception('User not logged in');
  }

  final itemRef = _itemRef(item.id);
  final reviewRef = itemRef.collection('reviews').doc();

  await itemRef.set(
    _publicItemData(item),
    SetOptions(merge: true),
  );

  await _libraryItemRef(item.id).set(
    {
      ..._baseItemData(item),
      'userRating': rating,
      'rating': rating,
      'lastReview': review,
      'review': review,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  await reviewRef.set({
    'uid': user.uid,
    'itemId': item.id,
    'safeItemId': _safeDocId(item.id),
    'title': item.title,
    'domain': item.domain,
    'imageUrl': item.imageUrl,
    'source': item.source,
    'rating': rating,
    'userRating': rating,
    'review': review,
    'text': review,
    'displayName': displayName,
    'username': username,
    'photoUrl': photoUrl,
    'createdAt': FieldValue.serverTimestamp(),
  });

  await _activityRef().doc().set({
    ..._activityData(item),
    'type': 'reviewed',
    'activityType': 'reviewed',
    'userRating': rating,
    'rating': rating,
    'review': review,
    'text': review,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

  Future<void> deleteReview({
    required String itemId,
    required String reviewId,
  }) async {
    await _itemRef(itemId).collection('reviews').doc(reviewId).delete();
  }

  Map<String, dynamic> _baseItemData(OnboardingMediaItem item) {
    return {
      'itemId': item.id,
      'safeItemId': _safeDocId(item.id),
      'title': item.title,
      'domain': item.domain,
      'genres': item.genres,
      'tags': item.tags,
      'imageUrl': item.imageUrl,
      'source': item.source,
      'description': item.description,
      'apiRating': item.apiRating,
      'discoverySource': item.discoverySource,
      'discoveryContext': item.discoveryContext,
    };
  }

  Map<String, dynamic> _publicItemData(OnboardingMediaItem item) {
    return {
      'itemId': item.id,
      'safeItemId': _safeDocId(item.id),
      'title': item.title,
      'domain': item.domain,
      'genres': item.genres,
      'tags': item.tags,
      'imageUrl': item.imageUrl,
      'source': item.source,
      'description': item.description,
      'apiRating': item.apiRating,
      'discoverySource': item.discoverySource,
      'discoveryContext': item.discoveryContext,
    };
  }

  Map<String, dynamic> _activityData(OnboardingMediaItem item) {
    return {
      'itemId': item.id,
      'safeItemId': _safeDocId(item.id),
      'title': item.title,
      'domain': item.domain,
      'imageUrl': item.imageUrl,
      'source': item.source,
      'discoverySource': item.discoverySource,
      'discoveryContext': item.discoveryContext,
    };
  }
}