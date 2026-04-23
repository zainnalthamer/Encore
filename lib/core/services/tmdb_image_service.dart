import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TmdbImageService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/original';

  String get _apiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  Future<List<String>> getHeaderBackdrops() async {
    if (_apiKey.isEmpty) {
      throw Exception('TMDB_API_KEY is missing in .env');
    }

    final endpoints = [
      '$_baseUrl/trending/movie/week?api_key=$_apiKey',
      '$_baseUrl/trending/tv/week?api_key=$_apiKey',
      '$_baseUrl/movie/popular?api_key=$_apiKey&page=1',
      '$_baseUrl/tv/popular?api_key=$_apiKey&page=1',
      '$_baseUrl/discover/movie?api_key=$_apiKey&sort_by=popularity.desc&page=1',
      '$_baseUrl/discover/tv?api_key=$_apiKey&sort_by=popularity.desc&page=1',
    ];

    final backdrops = <String>{};

    for (final endpoint in endpoints) {
      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode != 200) {
        continue;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (json['results'] as List?) ?? [];

      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;

        final backdropPath = (item['backdrop_path'] ?? '').toString().trim();
        final voteCount = item['vote_count'] is num ? item['vote_count'] as num : 0;
        final popularity =
            item['popularity'] is num ? item['popularity'] as num : 0;

        if (backdropPath.isEmpty) continue;
        if (voteCount < 20 && popularity < 30) continue;

        backdrops.add('$_imageBaseUrl$backdropPath');
      }
    }

    return backdrops.take(24).toList();
  }
}