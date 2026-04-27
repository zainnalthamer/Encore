import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/onboarding_media_item.dart';

class TmdbService {
  final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBase = 'https://image.tmdb.org/t/p/w500';

  Future<Map<int, String>> _getMovieGenres() async {
    final uri = Uri.parse('$_baseUrl/genre/movie/list?api_key=$_apiKey');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('TMDB movie genre fetch failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final genres = (data['genres'] as List<dynamic>? ?? []);

    return {
      for (final genre in genres)
        (genre as Map<String, dynamic>)['id'] as int:
            genre['name'].toString(),
    };
  }

  Future<Map<int, String>> _getTvGenres() async {
    final uri = Uri.parse('$_baseUrl/genre/tv/list?api_key=$_apiKey');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('TMDB TV genre fetch failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final genres = (data['genres'] as List<dynamic>? ?? []);

    return {
      for (final genre in genres)
        (genre as Map<String, dynamic>)['id'] as int:
            genre['name'].toString(),
    };
  }

  Future<List<OnboardingMediaItem>> getPopularMovies({int page = 1}) async {
    final genreMap = await _getMovieGenres();

    final uri = Uri.parse(
      '$_baseUrl/movie/popular?api_key=$_apiKey&page=$page',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB popular movies failed');
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
            ? '$_imageBase${map['poster_path']}'
            : '',
        source: 'tmdb',
        apiRating: ((map['vote_average'] ?? 0) as num).toDouble() / 2,
      );
    }).where((item) => item.title.isNotEmpty).toList();
  }

  Future<List<OnboardingMediaItem>> getPopularShows({int page = 1}) async {
    final genreMap = await _getTvGenres();

    final uri = Uri.parse(
      '$_baseUrl/tv/popular?api_key=$_apiKey&page=$page',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB popular TV failed');
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
            ? '$_imageBase${map['poster_path']}'
            : '',
        source: 'tmdb',
        apiRating: ((map['vote_average'] ?? 0) as num).toDouble() / 2,
      );
    }).where((item) => item.title.isNotEmpty).toList();
  }
}