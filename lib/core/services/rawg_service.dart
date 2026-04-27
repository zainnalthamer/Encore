import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/onboarding_media_item.dart';

class RawgService {
  final String _apiKey = dotenv.env['RAWG_API_KEY'] ?? '';

  Future<List<OnboardingMediaItem>> getPopularGames({int page = 1}) async {
    final uri = Uri.parse(
      'https://api.rawg.io/api/games?key=$_apiKey&page=$page&page_size=20&ordering=-added',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('RAWG popular games failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>? ?? []);

    return results.map((item) {
      final map = item as Map<String, dynamic>;

      final genres = (map['genres'] as List<dynamic>? ?? [])
          .map((g) => (g as Map<String, dynamic>)['name'].toString())
          .toList();

      final tags = (map['tags'] as List<dynamic>? ?? [])
          .take(8)
          .map((t) => (t as Map<String, dynamic>)['name'].toString())
          .toList();

      return OnboardingMediaItem(
        id: 'rawg_${map['id']}',
        title: (map['name'] ?? '').toString(),
        domain: 'games',
        genres: genres,
        tags: tags,
        imageUrl: (map['background_image'] ?? '').toString(),
        source: 'rawg',
        apiRating: ((map['rating'] ?? 0) as num).toDouble(),
      );
    }).where((item) => item.title.isNotEmpty).toList();
  }
}