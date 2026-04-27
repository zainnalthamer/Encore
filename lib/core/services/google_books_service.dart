import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/onboarding_media_item.dart';

class GoogleBooksService {
  static const List<String> _subjects = [
    'fantasy',
    'romance',
    'mystery',
    'science fiction',
    'thriller',
    'young adult',
    'fiction',
    'historical fiction',
  ];

  Future<List<OnboardingMediaItem>> getPopularishBooks() async {
    final subject = _subjects[Random().nextInt(_subjects.length)];

    final uri = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=subject:${Uri.encodeComponent(subject)}&maxResults=20&orderBy=relevance',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Google Books fetch failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? []);

    return items.map((item) {
      final map = item as Map<String, dynamic>;
      final volumeInfo = map['volumeInfo'] as Map<String, dynamic>? ?? {};
      final imageLinks =
          volumeInfo['imageLinks'] as Map<String, dynamic>? ?? {};
      final categories = (volumeInfo['categories'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      return OnboardingMediaItem(
        id: 'gbooks_${map['id']}',
        title: (volumeInfo['title'] ?? '').toString(),
        domain: 'books',
        genres: categories,
        tags: categories,
        imageUrl: (imageLinks['thumbnail'] ?? imageLinks['smallThumbnail'] ?? '')
            .toString()
            .replaceFirst('http://', 'https://'),
        source: 'google_books',
        apiRating: ((volumeInfo['averageRating'] ?? 0) as num).toDouble(),
      );
    }).where((item) => item.title.isNotEmpty).toList();
  }
}