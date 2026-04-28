import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/onboarding_media_item.dart';

class MediaLookupService {
  final String _tmdbApiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  final String _rawgApiKey = dotenv.env['RAWG_API_KEY'] ?? '';

  static const String _tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String _tmdbImageBase = 'https://image.tmdb.org/t/p/original';

  Future<OnboardingMediaItem> searchMovieByTitle(String title) async {
    final uri = Uri.parse(
      '$_tmdbBaseUrl/search/movie?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(title)}&include_adult=false',
    );

    final response = await http.get(uri);
    final data = jsonDecode(response.body);
    final results = data['results'] as List? ?? [];

    if (results.isEmpty) throw Exception('Movie not found');

    final item = results.first;
    final imagePath = item['backdrop_path'] ?? item['poster_path'] ?? '';

    return OnboardingMediaItem(
      id: 'tmdb_movie_${item['id']}',
      title: item['title'] ?? title,
      domain: 'movies',
      genres: const [],
      tags: const [],
      imageUrl: imagePath.toString().isEmpty ? '' : '$_tmdbImageBase$imagePath',
      source: 'tmdb',
      description: item['overview'] ?? '',
      apiRating: ((item['vote_average'] ?? 0) as num).toDouble() / 2,
    );
  }

  Future<OnboardingMediaItem> searchShowByTitle(String title) async {
    final uri = Uri.parse(
      '$_tmdbBaseUrl/search/tv?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(title)}&include_adult=false',
    );

    final response = await http.get(uri);
    final data = jsonDecode(response.body);
    final results = data['results'] as List? ?? [];

    if (results.isEmpty) throw Exception('Show not found');

    final item = results.first;
    final imagePath = item['backdrop_path'] ?? item['poster_path'] ?? '';

    return OnboardingMediaItem(
      id: 'tmdb_tv_${item['id']}',
      title: item['name'] ?? title,
      domain: 'shows',
      genres: const [],
      tags: const [],
      imageUrl: imagePath.toString().isEmpty ? '' : '$_tmdbImageBase$imagePath',
      source: 'tmdb',
      description: item['overview'] ?? '',
      apiRating: ((item['vote_average'] ?? 0) as num).toDouble() / 2,
    );
  }

  Future<OnboardingMediaItem> searchBookByTitle(String title) async {
    final uri = Uri.parse(
      'https://openlibrary.org/search.json?title=${Uri.encodeComponent(title)}&limit=1&fields=key,title,cover_i,subject,first_sentence',
    );

    final response = await http.get(uri);
    final data = jsonDecode(response.body);
    final docs = data['docs'] as List? ?? [];

    if (docs.isEmpty) throw Exception('Book not found');

    final item = docs.first;
    final coverId = item['cover_i'];

    return OnboardingMediaItem(
      id: 'openlib_${item['key']}',
      title: item['title'] ?? title,
      domain: 'books',
      genres: ((item['subject'] as List?) ?? []).take(5).map((e) => e.toString()).toList(),
      tags: ((item['subject'] as List?) ?? []).take(5).map((e) => e.toString()).toList(),
      imageUrl: coverId == null
          ? ''
          : 'https://covers.openlibrary.org/b/id/$coverId-L.jpg',
      source: 'open_library',
      description: '',
    );
  }

  Future<OnboardingMediaItem> searchGameByTitle(String title) async {
    final uri = Uri.parse(
      'https://api.rawg.io/api/games?key=$_rawgApiKey&search=${Uri.encodeComponent(title)}&page_size=1',
    );

    final response = await http.get(uri);
    final data = jsonDecode(response.body);
    final results = data['results'] as List? ?? [];

    if (results.isEmpty) throw Exception('Game not found');

    final item = results.first;

    final genres = ((item['genres'] as List?) ?? [])
        .map((g) => g['name'].toString())
        .toList();

    return OnboardingMediaItem(
      id: 'rawg_${item['id']}',
      title: item['name'] ?? title,
      domain: 'games',
      genres: genres,
      tags: genres,
      imageUrl: item['background_image'] ?? '',
      source: 'rawg',
      description: '',
      apiRating: ((item['rating'] ?? 0) as num).toDouble(),
    );
  }
}