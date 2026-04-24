import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/onboarding_media_item.dart';

class AvailabilityResult {
  final String title;
  final String subtitle;
  final List<String> providers;
  final String? link;

  const AvailabilityResult({
    required this.title,
    required this.subtitle,
    required this.providers,
    this.link,
  });
}

class ItemAvailabilityService {
  static const String tmdbApiKey = '6d3efe0405e6a40975b6004b143364a2';
  static const String rawgApiKey = 'ea0358fe57dd47caba4f06c40ee8f56e';

  Future<AvailabilityResult> getAvailability(OnboardingMediaItem item) async {
    switch (item.domain) {
      case 'movies':
        return _getMovieAvailability(item);
      case 'shows':
        return _getShowAvailability(item);
      case 'books':
        return _getBookAvailability(item);
      case 'games':
        return _getGameAvailability(item);
      default:
        return const AvailabilityResult(
          title: 'Availability',
          subtitle: 'No availability source found.',
          providers: [],
        );
    }
  }

  Future<AvailabilityResult> _getMovieAvailability(
    OnboardingMediaItem item,
  ) async {
    final searchUrl = Uri.parse(
      'https://api.themoviedb.org/3/search/movie?api_key=$tmdbApiKey&query=${Uri.encodeComponent(item.title)}',
    );

    final searchRes = await http.get(searchUrl);
    final searchData = jsonDecode(searchRes.body);

    final results = searchData['results'] as List? ?? [];

    if (results.isEmpty) {
      return const AvailabilityResult(
        title: 'Where to watch',
        subtitle: 'No streaming providers found.',
        providers: [],
      );
    }

    final id = results.first['id'];

    final watchUrl = Uri.parse(
      'https://api.themoviedb.org/3/movie/$id/watch/providers?api_key=$tmdbApiKey',
    );

    final watchRes = await http.get(watchUrl);
    final watchData = jsonDecode(watchRes.body);

    final regions = watchData['results'] as Map<String, dynamic>? ?? {};
    final region = regions['BH'] ?? regions['US'] ?? regions['GB'];

    if (region == null) {
      return const AvailabilityResult(
        title: 'Where to watch',
        subtitle: 'No regional streaming data found.',
        providers: [],
      );
    }

    final flatrate = region['flatrate'] as List? ?? [];
    final rent = region['rent'] as List? ?? [];
    final buy = region['buy'] as List? ?? [];

    final providers = [
      ...flatrate,
      ...rent,
      ...buy,
    ].map((p) => p['provider_name'].toString()).toSet().toList();

    return AvailabilityResult(
      title: 'Where to watch',
      subtitle: providers.isEmpty
          ? 'No streaming providers found.'
          : 'Available from ${providers.length} provider(s).',
      providers: providers,
      link: region['link'],
    );
  }

  Future<AvailabilityResult> _getShowAvailability(
    OnboardingMediaItem item,
  ) async {
    final searchUrl = Uri.parse(
      'https://api.themoviedb.org/3/search/tv?api_key=$tmdbApiKey&query=${Uri.encodeComponent(item.title)}',
    );

    final searchRes = await http.get(searchUrl);
    final searchData = jsonDecode(searchRes.body);

    final results = searchData['results'] as List? ?? [];

    if (results.isEmpty) {
      return const AvailabilityResult(
        title: 'Where to stream',
        subtitle: 'No streaming providers found.',
        providers: [],
      );
    }

    final id = results.first['id'];

    final watchUrl = Uri.parse(
      'https://api.themoviedb.org/3/tv/$id/watch/providers?api_key=$tmdbApiKey',
    );

    final watchRes = await http.get(watchUrl);
    final watchData = jsonDecode(watchRes.body);

    final regions = watchData['results'] as Map<String, dynamic>? ?? {};
    final region = regions['BH'] ?? regions['US'] ?? regions['GB'];

    if (region == null) {
      return const AvailabilityResult(
        title: 'Where to stream',
        subtitle: 'No regional streaming data found.',
        providers: [],
      );
    }

    final flatrate = region['flatrate'] as List? ?? [];
    final rent = region['rent'] as List? ?? [];
    final buy = region['buy'] as List? ?? [];

    final providers = [
      ...flatrate,
      ...rent,
      ...buy,
    ].map((p) => p['provider_name'].toString()).toSet().toList();

    return AvailabilityResult(
      title: 'Where to stream',
      subtitle: providers.isEmpty
          ? 'No streaming providers found.'
          : 'Available from ${providers.length} provider(s).',
      providers: providers,
      link: region['link'],
    );
  }

  Future<AvailabilityResult> _getBookAvailability(
    OnboardingMediaItem item,
  ) async {
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(item.title)}&maxResults=1',
    );

    final res = await http.get(url);
    final data = jsonDecode(res.body);

    final books = data['items'] as List? ?? [];

    if (books.isEmpty) {
      return const AvailabilityResult(
        title: 'Where to read',
        subtitle: 'No book source found.',
        providers: [],
      );
    }

    final book = books.first;
    final info = book['volumeInfo'] ?? {};
    final sale = book['saleInfo'] ?? {};

    final providers = <String>[
      if (info['previewLink'] != null) 'Google Books Preview',
      if (sale['buyLink'] != null) 'Google Play Books',
    ];

    return AvailabilityResult(
      title: 'Where to read',
      subtitle: providers.isEmpty
          ? 'Book found, but no preview or buying link is available.'
          : 'Reading options found.',
      providers: providers,
      link: sale['buyLink'] ?? info['previewLink'],
    );
  }

  Future<AvailabilityResult> _getGameAvailability(
    OnboardingMediaItem item,
  ) async {
    final searchUrl = Uri.parse(
      'https://api.rawg.io/api/games?key=$rawgApiKey&search=${Uri.encodeComponent(item.title)}&page_size=1',
    );

    final searchRes = await http.get(searchUrl);
    final searchData = jsonDecode(searchRes.body);

    final results = searchData['results'] as List? ?? [];

    if (results.isEmpty) {
      return const AvailabilityResult(
        title: 'Where to play',
        subtitle: 'No store information found.',
        providers: [],
      );
    }

    final gameId = results.first['id'];

    final storesUrl = Uri.parse(
      'https://api.rawg.io/api/games/$gameId/stores?key=$rawgApiKey',
    );

    final storesRes = await http.get(storesUrl);
    final storesData = jsonDecode(storesRes.body);

    final stores = storesData['results'] as List? ?? [];

    final providers = stores
        .map((s) => s['store']?['name']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    return AvailabilityResult(
      title: 'Where to play',
      subtitle: providers.isEmpty
          ? 'No stores found for this game.'
          : 'Available from ${providers.length} store(s).',
      providers: providers,
    );
  }
}