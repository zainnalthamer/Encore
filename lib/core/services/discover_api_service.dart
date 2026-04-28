import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/onboarding_media_item.dart';

class DiscoverApiService {
  final String _tmdbApiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  final String _rawgApiKey = dotenv.env['RAWG_API_KEY'] ?? '';

  static const String _tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String _tmdbPosterBase = 'https://image.tmdb.org/t/p/w780';
  static const String _tmdbBackdropBase = 'https://image.tmdb.org/t/p/original';

  Future<DiscoverData> loadDiscover() async {
    final results = await Future.wait([
      getPopularMovies(),
      getTrendingShows(),
      getHighestRatedMovies(),
      getPopularGames(),
      getPopularBooks(),
      getByMoodGenre(),
    ]);

    return DiscoverData(
      popular: results[0],
      trending: results[1],
      highestRated: results[2],
      games: results[3],
      books: results[4],
      genrePicks: results[5],
    );
  }

  Future<List<OnboardingMediaItem>> searchAll(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final results = await Future.wait([
      _searchGames(clean),
      _searchBooks(clean),
      _searchTmdb(clean, 'movie'),
      _searchTmdb(clean, 'tv'),
    ]);

    final combined = _unique([
      ...results[0],
      ...results[1],
      ...results[2],
      ...results[3],
    ]);

    combined.sort((a, b) {
      int score(OnboardingMediaItem item) {
        final title = item.title.toLowerCase();
        final q = clean.toLowerCase();

        int s = 0;

        if (title == q) s += 100;
        if (title.contains(q)) s += 60;
        if (item.domain == 'games') s += 25;
        if (item.imageUrl.isNotEmpty) s += 10;
        if (item.apiRating > 0) s += item.apiRating.round();

        return s;
      }

      return score(b).compareTo(score(a));
    });

    return combined.take(40).toList();
  }

  Future<List<OnboardingMediaItem>> getPopularMovies() async {
    final uri = Uri.parse(
      '$_tmdbBaseUrl/movie/popular?api_key=$_tmdbApiKey&page=1',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _mapTmdbItems(data['results'] ?? [], 'movie');
  }

  Future<List<OnboardingMediaItem>> getTrendingShows() async {
    final uri = Uri.parse(
      '$_tmdbBaseUrl/trending/tv/week?api_key=$_tmdbApiKey',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _mapTmdbItems(data['results'] ?? [], 'tv');
  }

  Future<List<OnboardingMediaItem>> getHighestRatedMovies() async {
    final uri = Uri.parse(
      '$_tmdbBaseUrl/movie/top_rated?api_key=$_tmdbApiKey&page=1',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _mapTmdbItems(data['results'] ?? [], 'movie');
  }

  Future<List<OnboardingMediaItem>> getPopularGames() async {
    final uri = Uri.parse(
      'https://api.rawg.io/api/games?key=$_rawgApiKey&ordering=-added&page_size=18',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _mapRawgItems(data['results'] ?? []);
  }

  Future<List<OnboardingMediaItem>> getPopularBooks() async {
    final subjects = [
      'fantasy',
      'romance',
      'thriller',
      'science fiction',
      'young adult',
      'mystery',
    ];

    final subject = subjects[Random().nextInt(subjects.length)];

    final uri = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=subject:${Uri.encodeComponent(subject)}&orderBy=relevance&maxResults=18',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _mapGoogleBooks(data['items'] ?? []);
  }

  Future<List<OnboardingMediaItem>> getByMoodGenre() async {
    final genres = [
      {'id': 878, 'name': 'Sci-Fi'},
      {'id': 53, 'name': 'Thriller'},
      {'id': 10749, 'name': 'Romance'},
      {'id': 14, 'name': 'Fantasy'},
      {'id': 27, 'name': 'Horror'},
    ];

    final selected = genres[Random().nextInt(genres.length)];

    final uri = Uri.parse(
      '$_tmdbBaseUrl/discover/movie?api_key=$_tmdbApiKey&with_genres=${selected['id']}&sort_by=popularity.desc&vote_count.gte=300&page=1',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _mapTmdbItems(data['results'] ?? [], 'movie');
  }

  Future<List<OnboardingMediaItem>> _searchTmdb(
    String query,
    String type,
  ) async {
    final uri = Uri.parse(
      '$_tmdbBaseUrl/search/$type?api_key=$_tmdbApiKey&query=${Uri.encodeComponent(query)}&include_adult=false&page=1',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _mapTmdbItems(data['results'] ?? [], type);
  }

  Future<List<OnboardingMediaItem>> _searchBooks(String query) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(query)}&maxResults=12',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _mapGoogleBooks(data['items'] ?? []);
  }

  Future<List<OnboardingMediaItem>> _searchGames(String query) async {
    final uri = Uri.parse(
      'https://api.rawg.io/api/games?key=$_rawgApiKey&search=${Uri.encodeComponent(query)}&page_size=12',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    return _mapRawgItems(data['results'] ?? []);
  }

  List<OnboardingMediaItem> _mapTmdbItems(List items, String type) {
    return items.map((json) {
      final poster = (json['poster_path'] ?? '').toString();
      final backdrop = (json['backdrop_path'] ?? '').toString();

      return OnboardingMediaItem(
        id: type == 'movie'
            ? 'tmdb_movie_${json['id']}'
            : 'tmdb_tv_${json['id']}',
        title: type == 'movie'
            ? (json['title'] ?? 'Untitled').toString()
            : (json['name'] ?? 'Untitled').toString(),
        domain: type == 'movie' ? 'movies' : 'shows',
        genres: const [],
        tags: const [],
        imageUrl: poster.isNotEmpty
            ? '$_tmdbPosterBase$poster'
            : backdrop.isNotEmpty
                ? '$_tmdbBackdropBase$backdrop'
                : '',
        source: 'tmdb',
        description: (json['overview'] ?? '').toString(),
        apiRating: ((json['vote_average'] ?? 0) as num).toDouble() / 2,
      );
    }).where((item) {
      return item.title.trim().isNotEmpty && item.imageUrl.trim().isNotEmpty;
    }).toList();
  }

  List<OnboardingMediaItem> _mapRawgItems(List items) {
    return items.map((json) {
      final genres = ((json['genres'] as List?) ?? [])
          .map((g) => (g['name'] ?? '').toString())
          .where((g) => g.isNotEmpty)
          .toList();

      return OnboardingMediaItem(
        id: 'rawg_${json['id']}',
        title: (json['name'] ?? 'Untitled').toString(),
        domain: 'games',
        genres: genres,
        tags: genres,
        imageUrl: (json['background_image'] ?? '').toString(),
        source: 'rawg',
        description: genres.isEmpty ? '' : 'A game connected to ${genres.take(3).join(', ')}.',
        apiRating: ((json['rating'] ?? 0) as num).toDouble(),
      );
    }).where((item) {
      return item.title.trim().isNotEmpty && item.imageUrl.trim().isNotEmpty;
    }).toList();
  }

  List<OnboardingMediaItem> _mapGoogleBooks(List items) {
    return items.map((json) {
      final info = json['volumeInfo'] ?? {};
      final imageLinks = info['imageLinks'] ?? {};
      final imageUrl = (imageLinks['thumbnail'] ??
              imageLinks['smallThumbnail'] ??
              '')
          .toString()
          .replaceAll('http://', 'https://');

      final categories = ((info['categories'] as List?) ?? [])
          .map((e) => e.toString())
          .toList();

      return OnboardingMediaItem(
        id: 'google_books_${json['id']}',
        title: (info['title'] ?? 'Untitled').toString(),
        domain: 'books',
        genres: categories,
        tags: categories,
        imageUrl: imageUrl,
        source: 'google_books',
        description: (info['description'] ?? '').toString(),
        apiRating: ((info['averageRating'] ?? 0) as num).toDouble(),
      );
    }).where((item) {
      return item.title.trim().isNotEmpty && item.imageUrl.trim().isNotEmpty;
    }).toList();
  }

  List<OnboardingMediaItem> _unique(List<OnboardingMediaItem> items) {
    final seen = <String>{};
    final unique = <OnboardingMediaItem>[];

    for (final item in items) {
      final key = '${item.domain}_${item.title.toLowerCase()}';

      if (seen.contains(key)) continue;

      seen.add(key);
      unique.add(item);
    }

    return unique;
  }
}

class DiscoverData {
  final List<OnboardingMediaItem> popular;
  final List<OnboardingMediaItem> trending;
  final List<OnboardingMediaItem> highestRated;
  final List<OnboardingMediaItem> games;
  final List<OnboardingMediaItem> books;
  final List<OnboardingMediaItem> genrePicks;

  const DiscoverData({
    required this.popular,
    required this.trending,
    required this.highestRated,
    required this.games,
    required this.books,
    required this.genrePicks,
  });
}