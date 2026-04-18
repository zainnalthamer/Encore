import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/onboarding_media_item.dart';

class MediaSeedService {
  final String _tmdbApiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  final String _rawgApiKey = dotenv.env['RAWG_API_KEY'] ?? '';

  static const String _tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String _tmdbImageBase = 'https://image.tmdb.org/t/p/w500';

  Future<List<OnboardingMediaItem>> getMixedPopularFeed({
    int limit = 60,
  }) async {
    final allItems = <OnboardingMediaItem>[];

    try {
      final moviePage = Random().nextInt(3) + 1;
      allItems.addAll(await _getCuratedMovies(page: moviePage));
    } catch (_) {}

    try {
      final showPage = Random().nextInt(3) + 1;
      allItems.addAll(await _getCuratedShows(page: showPage));
    } catch (_) {}

    try {
      allItems.addAll(await _getCuratedBooks());
    } catch (_) {}

    try {
      final gamePage = Random().nextInt(3) + 1;
      allItems.addAll(await _getPopularGames(page: gamePage));
    } catch (_) {}

    if (allItems.isEmpty) {
      throw Exception('Could not load any items from the media APIs.');
    }

    allItems.shuffle();

    final seen = <String>{};
    final uniqueItems = <OnboardingMediaItem>[];

    for (final item in allItems) {
      if (item.title.trim().isEmpty) continue;
      if (item.imageUrl.trim().isEmpty) continue;
      if (seen.contains(item.id)) continue;

      seen.add(item.id);
      uniqueItems.add(item);

      if (uniqueItems.length >= limit) break;
    }

    return uniqueItems;
  }

  Future<Map<int, String>> _getMovieGenres() async {
    final uri = Uri.parse(
      '$_tmdbBaseUrl/genre/movie/list?api_key=$_tmdbApiKey',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load movie genres');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final genres = (data['genres'] as List<dynamic>? ?? []);

    return {
      for (final genre in genres)
        (genre as Map<String, dynamic>)['id'] as int:
            genre['name'].toString(),
    };
  }

  Future<Map<int, String>> _getShowGenres() async {
    final uri = Uri.parse(
      '$_tmdbBaseUrl/genre/tv/list?api_key=$_tmdbApiKey',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load TV genres');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final genres = (data['genres'] as List<dynamic>? ?? []);

    return {
      for (final genre in genres)
        (genre as Map<String, dynamic>)['id'] as int:
            genre['name'].toString(),
    };
  }

  Future<List<OnboardingMediaItem>> _getCuratedMovies({int page = 1}) async {
    final genreMap = await _getMovieGenres();

    final uri = Uri.parse(
      '$_tmdbBaseUrl/discover/movie'
      '?api_key=$_tmdbApiKey'
      '&sort_by=vote_average.desc'
      '&vote_count.gte=300'
      '&vote_average.gte=7.0'
      '&include_adult=false'
      '&page=$page',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load curated movies');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>? ?? []);

    return results.map((item) {
      final map = item as Map<String, dynamic>;
      final genreIds = (map['genre_ids'] as List<dynamic>? ?? [])
          .map((e) => e as int)
          .toList();

      final genres = genreIds
          .map((id) => genreMap[id])
          .whereType<String>()
          .toList();

      return OnboardingMediaItem(
        id: 'tmdb_movie_${map['id']}',
        title: (map['title'] ?? '').toString(),
        domain: 'movies',
        genres: genres,
        tags: genres,
        imageUrl: map['poster_path'] != null
            ? '$_tmdbImageBase${map['poster_path']}'
            : '',
        source: 'tmdb',
      );
    }).where((item) => item.title.isNotEmpty).toList();
  }

  Future<List<OnboardingMediaItem>> _getCuratedShows({int page = 1}) async {
    final genreMap = await _getShowGenres();

    final uri = Uri.parse(
      '$_tmdbBaseUrl/discover/tv'
      '?api_key=$_tmdbApiKey'
      '&sort_by=vote_average.desc'
      '&vote_count.gte=150'
      '&vote_average.gte=7.0'
      '&include_adult=false'
      '&page=$page',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load curated TV shows');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>? ?? []);

    return results.map((item) {
      final map = item as Map<String, dynamic>;
      final genreIds = (map['genre_ids'] as List<dynamic>? ?? [])
          .map((e) => e as int)
          .toList();

      final genres = genreIds
          .map((id) => genreMap[id])
          .whereType<String>()
          .toList();

      return OnboardingMediaItem(
        id: 'tmdb_tv_${map['id']}',
        title: (map['name'] ?? '').toString(),
        domain: 'shows',
        genres: genres,
        tags: genres,
        imageUrl: map['poster_path'] != null
            ? '$_tmdbImageBase${map['poster_path']}'
            : '',
        source: 'tmdb',
      );
    }).where((item) => item.title.isNotEmpty).toList();
  }

  Future<List<OnboardingMediaItem>> _getCuratedBooks() async {
    const subjects = [
      'fantasy',
      'fiction',
      'romance',
      'thriller',
      'mystery',
      'science_fiction',
      'young_adult',
      'historical_fiction',
    ];

    final subject = subjects[Random().nextInt(subjects.length)];

    final uri = Uri.parse(
      'https://openlibrary.org/search.json'
      '?q=subject:${Uri.encodeComponent(subject)}'
      '&limit=24'
      '&fields=key,title,cover_i,subject,ratings_average,ratings_count',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load books');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = (data['docs'] as List<dynamic>? ?? []);

    final filtered = docs.where((doc) {
      final map = doc as Map<String, dynamic>;
      return map['title'] != null && map['cover_i'] != null;
    }).toList();

    return filtered.map((doc) {
      final map = doc as Map<String, dynamic>;
      final subjects = (map['subject'] as List<dynamic>? ?? [])
          .take(8)
          .map((e) => e.toString())
          .toList();

      final coverId = map['cover_i'].toString();

      return OnboardingMediaItem(
        id: 'openlib_${map['key']}',
        title: map['title'].toString(),
        domain: 'books',
        genres: subjects,
        tags: subjects,
        imageUrl: 'https://covers.openlibrary.org/b/id/$coverId-L.jpg',
        source: 'open_library',
      );
    }).toList();
  }

  Future<List<OnboardingMediaItem>> _getPopularGames({int page = 1}) async {
    final uri = Uri.parse(
      'https://api.rawg.io/api/games'
      '?key=$_rawgApiKey'
      '&page=$page'
      '&page_size=20'
      '&ordering=-rating',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load games');
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
      );
    }).where((item) => item.title.isNotEmpty && item.imageUrl.isNotEmpty).toList();
  }
}