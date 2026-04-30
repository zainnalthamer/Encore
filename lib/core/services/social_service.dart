import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchUsers(
    String query,
  ) async {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) return [];

    final snapshot = await _db
        .collection('users')
        .orderBy('usernameLower')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs;
  }

  Future<void> toggleFollow({
    required String targetUid,
    required bool isFollowing,
  }) async {
    final me = currentUid;
    if (me == null || me == targetUid) return;

    final myRef = _db.collection('users').doc(me);
    final targetRef = _db.collection('users').doc(targetUid);

    final batch = _db.batch();

    if (isFollowing) {
      batch.update(myRef, {
        'following': FieldValue.arrayRemove([targetUid]),
      });

      batch.update(targetRef, {
        'followers': FieldValue.arrayRemove([me]),
      });
    } else {
      batch.update(myRef, {
        'following': FieldValue.arrayUnion([targetUid]),
      });

      batch.update(targetRef, {
        'followers': FieldValue.arrayUnion([me]),
      });
    }

    await batch.commit();
  }
}