import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/home_media_item.dart';

class HomeFeedService {
  // Replace these with your real keys.
  // You can also move them to your existing service files later.
  static const String _tmdbApiKey = 'YOUR_TMDB_API_KEY';
  static const String _rawgApiKey = 'YOUR_RAWG_API_KEY';
  static const String _googleBooksApiKey = '';

  Future<HomeFeedBundle> buildFeed({
    required List<String> topGenres,
    required List<String> favoriteDomains,
  }) async {
    final effectiveGenres = topGenres.isEmpty
        ? ['Drama', 'Thriller', 'Science Fiction']
        : topGenres;

    final effectiveDomains = favoriteDomains.isEmpty
        ? ['movies', 'shows', 'books', 'games']
        : favoriteDomains;

    final popular = await getPopularHeroItems();

    final discover = await getDiscoverItems(
      genres: effectiveGenres,
      favoriteDomains: effectiveDomains,
    );

    final likedGenre = effectiveGenres.first;
    final becauseYouLiked = await getBecauseYouLikedItems(
      genre: likedGenre,
      favoriteDomains: effectiveDomains,
    );

    final newFromFriends = getFriendPlaceholders();

    return HomeFeedBundle(
      popular: popular,
      discover: discover,
      becauseYouLikedTitle: 'Because you liked $likedGenre',
      becauseYouLiked: becauseYouLiked,
      newFromFriends: newFromFriends,
    );
  }

  Future<List<HomeMediaItem>> getPopularHeroItems() async {
    final uri = Uri.https(
      'api.themoviedb.org',
      '/3/movie/popular',
      {
        'api_key': _tmdbApiKey,
        'page': '1',
      },
    );

    final data = await _getJson(uri);
    final results = (data['results'] as List? ?? []).take(6).toList();

    return results.map((item) {
      final posterPath = item['backdrop_path'] ?? item['poster_path'] ?? '';
      return HomeMediaItem(
        id: 'movie_${item['id']}',
        title: item['title']?.toString() ?? 'Untitled',
        subtitle:
            '${item['release_date']?.toString().split('-').first ?? '—'} • Movie',
        description: item['overview']?.toString() ?? '',
        imageUrl: posterPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w780$posterPath'
            : '',
        type: 'movie',
        source: 'tmdb',
        score: (item['vote_average'] is num)
            ? (item['vote_average'] as num).toDouble()
            : 0,
      );
    }).toList();
  }

  Future<List<HomeMediaItem>> getDiscoverItems({
    required List<String> genres,
    required List<String> favoriteDomains,
  }) async {
    final items = <HomeMediaItem>[];

    if (favoriteDomains.contains('movies')) {
      items.addAll(await _fetchMoviesByGenre(genres.first));
    }

    if (favoriteDomains.contains('shows')) {
      items.addAll(await _fetchShowsByGenre(
        genres.length > 1 ? genres[1] : genres.first,
      ));
    }

    if (favoriteDomains.contains('books')) {
      items.addAll(await _fetchBooksByGenre(genres.first));
    }

    if (favoriteDomains.contains('games')) {
      items.addAll(await _fetchGamesByGenre(
        genres.length > 2 ? genres[2] : genres.first,
      ));
    }

    return items.take(12).toList();
  }

  Future<List<HomeMediaItem>> getBecauseYouLikedItems({
    required String genre,
    required List<String> favoriteDomains,
  }) async {
    final items = <HomeMediaItem>[];

    if (favoriteDomains.contains('movies')) {
      items.addAll(await _fetchMoviesByGenre(genre));
    }

    if (favoriteDomains.contains('shows')) {
      items.addAll(await _fetchShowsByGenre(genre));
    }

    if (favoriteDomains.contains('books')) {
      items.addAll(await _fetchBooksByGenre(genre));
    }

    if (favoriteDomains.contains('games')) {
      items.addAll(await _fetchGamesByGenre(genre));
    }

    return items.take(10).toList();
  }

  List<HomeMediaItem> getFriendPlaceholders() {
    return const [
      HomeMediaItem(
        id: 'friend_1',
        title: 'Friends activity soon',
        subtitle: 'Placeholder',
        description: 'This section will show what your friends recently added.',
        imageUrl: '',
        type: 'friends',
        source: 'local',
        score: 0,
        isPlaceholder: true,
      ),
      HomeMediaItem(
        id: 'friend_2',
        title: 'Shared shelves later',
        subtitle: 'Placeholder',
        description: 'Once friend functionality is added, this will feel alive.',
        imageUrl: '',
        type: 'friends',
        source: 'local',
        score: 0,
        isPlaceholder: true,
      ),
      HomeMediaItem(
        id: 'friend_3',
        title: 'Recent entries',
        subtitle: 'Placeholder',
        description: 'You can replace this with real activity cards later.',
        imageUrl: '',
        type: 'friends',
        source: 'local',
        score: 0,
        isPlaceholder: true,
      ),
    ];
  }

  Future<List<HomeMediaItem>> _fetchMoviesByGenre(String genreName) async {
    final genreId = await _resolveTmdbGenreId(genreName, isTv: false);
    if (genreId == null) return [];

    final uri = Uri.https(
      'api.themoviedb.org',
      '/3/discover/movie',
      {
        'api_key': _tmdbApiKey,
        'with_genres': genreId,
        'sort_by': 'popularity.desc',
        'page': '1',
      },
    );

    final data = await _getJson(uri);
    final results = (data['results'] as List? ?? []).take(5).toList();

    return results.map((item) {
      final posterPath = item['poster_path'] ?? '';
      return HomeMediaItem(
        id: 'movie_${item['id']}',
        title: item['title']?.toString() ?? 'Untitled',
        subtitle:
            '${item['release_date']?.toString().split('-').first ?? '—'} • Movie',
        description: item['overview']?.toString() ?? '',
        imageUrl: posterPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w500$posterPath'
            : '',
        type: 'movie',
        source: 'tmdb',
        score: (item['vote_average'] is num)
            ? (item['vote_average'] as num).toDouble()
            : 0,
      );
    }).toList();
  }

  Future<List<HomeMediaItem>> _fetchShowsByGenre(String genreName) async {
    final genreId = await _resolveTmdbGenreId(genreName, isTv: true);
    if (genreId == null) return [];

    final uri = Uri.https(
      'api.themoviedb.org',
      '/3/discover/tv',
      {
        'api_key': _tmdbApiKey,
        'with_genres': genreId,
        'sort_by': 'popularity.desc',
        'page': '1',
      },
    );

    final data = await _getJson(uri);
    final results = (data['results'] as List? ?? []).take(5).toList();

    return results.map((item) {
      final posterPath = item['poster_path'] ?? '';
      return HomeMediaItem(
        id: 'show_${item['id']}',
        title: item['name']?.toString() ?? 'Untitled',
        subtitle:
            '${item['first_air_date']?.toString().split('-').first ?? '—'} • Show',
        description: item['overview']?.toString() ?? '',
        imageUrl: posterPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w500$posterPath'
            : '',
        type: 'show',
        source: 'tmdb',
        score: (item['vote_average'] is num)
            ? (item['vote_average'] as num).toDouble()
            : 0,
      );
    }).toList();
  }

  Future<List<HomeMediaItem>> _fetchBooksByGenre(String genreName) async {
    final query = 'subject:$genreName';
    final params = {
      'q': query,
      'maxResults': '8',
      if (_googleBooksApiKey.isNotEmpty) 'key': _googleBooksApiKey,
      'orderBy': 'relevance',
      'printType': 'books',
    };

    final uri = Uri.https('www.googleapis.com', '/books/v1/volumes', params);
    final data = await _getJson(uri);
    final items = (data['items'] as List? ?? []).take(4).toList();

    return items.map((item) {
      final volumeInfo = item['volumeInfo'] ?? {};
      final imageLinks = volumeInfo['imageLinks'] ?? {};
      final thumbnail = (imageLinks['thumbnail'] ?? '').toString()
          .replaceFirst('http://', 'https://');

      final authors = (volumeInfo['authors'] as List?)
              ?.map((e) => e.toString())
              .join(', ') ??
          'Book';

      return HomeMediaItem(
        id: 'book_${item['id']}',
        title: volumeInfo['title']?.toString() ?? 'Untitled',
        subtitle: authors,
        description: volumeInfo['description']?.toString() ?? '',
        imageUrl: thumbnail,
        type: 'book',
        source: 'google_books',
        score: 0,
      );
    }).toList();
  }

  Future<List<HomeMediaItem>> _fetchGamesByGenre(String genreName) async {
    if (_rawgApiKey.isEmpty) return [];

    final slug = _slugifyGenre(genreName);
    final uri = Uri.https(
      'api.rawg.io',
      '/api/games',
      {
        'key': _rawgApiKey,
        'genres': slug,
        'ordering': '-rating',
        'page_size': '6',
      },
    );

    final data = await _getJson(uri);
    final results = (data['results'] as List? ?? []).take(4).toList();

    return results.map((item) {
      return HomeMediaItem(
        id: 'game_${item['id']}',
        title: item['name']?.toString() ?? 'Untitled',
        subtitle:
            '${item['released']?.toString().split('-').first ?? '—'} • Game',
        description: '',
        imageUrl: item['background_image']?.toString() ?? '',
        type: 'game',
        source: 'rawg',
        score: (item['rating'] is num)
            ? (item['rating'] as num).toDouble()
            : 0,
      );
    }).toList();
  }

  Future<String?> _resolveTmdbGenreId(
    String genreName, {
    required bool isTv,
  }) async {
    final uri = Uri.https(
      'api.themoviedb.org',
      isTv ? '/3/genre/tv/list' : '/3/genre/movie/list',
      {'api_key': _tmdbApiKey},
    );

    final data = await _getJson(uri);
    final genres = (data['genres'] as List? ?? []);

    for (final genre in genres) {
      final name = genre['name']?.toString().toLowerCase().trim() ?? '';
      if (name == genreName.toLowerCase().trim()) {
        return genre['id']?.toString();
      }

      if (name.contains(genreName.toLowerCase()) ||
          genreName.toLowerCase().contains(name)) {
        return genre['id']?.toString();
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Request failed: ${response.statusCode} ${uri.path}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _slugifyGenre(String genre) {
    return genre
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(' ', '-')
        .replaceAll('/', '-');
  }
}