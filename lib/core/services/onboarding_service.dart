import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/onboarding_media_item.dart';

class OnboardingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveInitialPreferences({
    required String uid,
    required List<OnboardingMediaItem> selectedItems,
  }) async {
    final movies = <String>[];
    final shows = <String>[];
    final books = <String>[];
    final games = <String>[];

    final genreCounts = <String, int>{};
    final tagCounts = <String, int>{};
    final domainCounts = <String, int>{};

    for (final item in selectedItems) {
      switch (item.domain) {
        case 'movies':
          movies.add(item.id);
          break;
        case 'shows':
          shows.add(item.id);
          break;
        case 'books':
          books.add(item.id);
          break;
        case 'games':
          games.add(item.id);
          break;
      }

      domainCounts[item.domain] = (domainCounts[item.domain] ?? 0) + 1;

      for (final genre in item.genres) {
        if (genre.trim().isEmpty) continue;
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }

      for (final tag in item.tags) {
        if (tag.trim().isEmpty) continue;
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    final favoriteDomains = domainCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topGenres = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    await _firestore.collection('users').doc(uid).update({
      'favoriteItemIds': {
        'movies': movies,
        'shows': shows,
        'books': books,
        'games': games,
      },
      'derivedPreferences': {
        'favoriteDomains': favoriteDomains.map((e) => e.key).toList(),
        'topGenres': topGenres.take(10).map((e) => e.key).toList(),
        'topTags': topTags.take(10).map((e) => e.key).toList(),
      },
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}