import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kAnalyticsBg = Color(0xFF07080A);
const Color kAnalyticsPanel = Color(0xFF121316);
const Color kAnalyticsSoft = Color(0xFF191B20);

const Color kOrange = Color(0xFFFF7A3D);
const Color kCoral = Color(0xFFFF5A4F);
const Color kBlue = Color(0xFF38BDF8);
const Color kGreen = Color(0xFF2EE59D);
const Color kYellow = Color(0xFFFFC857);
const Color kTeal = Color(0xFF38E1D8);

const Color kMuted = Color(0xFF8F929B);

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<_AnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAnalytics();
  }

  Future<_AnalyticsData> _loadAnalytics() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('No user found.');
    }

    final firestore = FirebaseFirestore.instance;

    final userDoc = await firestore.collection('users').doc(user.uid).get();

    final librarySnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('libraryItems')
        .get();

    final activitySnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('activity')
        .get();

    return _AnalyticsData.fromFirestore(
      userData: userDoc.data() ?? <String, dynamic>{},
      libraryItems: librarySnapshot.docs.map((doc) => doc.data()).toList(),
      activities: activitySnapshot.docs.map((doc) => doc.data()).toList(),
    );
  }

  void _reload() {
    setState(() {
      _future = _loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAnalyticsBg,
      body: FutureBuilder<_AnalyticsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kOrange),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _AnalyticsError(
              message: snapshot.error?.toString() ?? 'Could not load analytics.',
              onRetry: _reload,
            );
          }

          final data = snapshot.data!;

          return Stack(
            children: [
              const Positioned.fill(child: _DashboardBackground()),
              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _TopBar(
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
                        child: _DashboardGrid(data: data),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  final _AnalyticsData data;

  const _DashboardGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricsRow(data: data),
        const SizedBox(height: 16),
        _ResponsiveRow(
          leftFlex: 38,
          rightFlex: 62,
          left: _CalendarLogsCard(data: data),
          right: _DiscoveryOverviewCard(data: data),
        ),
        const SizedBox(height: 16),
        _ResponsiveRow(
          leftFlex: 40,
          rightFlex: 60,
          left: _PreferenceIdentityCard(data: data),
          right: _DomainMixCard(data: data),
        ),
        const SizedBox(height: 16),
        _ResponsiveRow(
          leftFlex: 42,
          rightFlex: 58,
          left: _SourceBreakdownCard(data: data),
          right: _DiscoveryImpactCard(data: data),
        ),
        const SizedBox(height: 16),
        _PreferenceFormationCard(data: data),
        const SizedBox(height: 16),
        _CrossDomainTasteCard(data: data),
        const SizedBox(height: 16),
        _ResponsiveThreeRow(
          first: _BehaviorSignalsCard(data: data),
          second: _RatingMovementCard(data: data),
          third: _RecentLogsCard(data: data),
        ),
      ],
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  final int leftFlex;
  final int rightFlex;
  final Widget left;
  final Widget right;

  const _ResponsiveRow({
    required this.leftFlex,
    required this.rightFlex,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return Column(
            children: [
              left,
              const SizedBox(height: 16),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 16),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

class _ResponsiveThreeRow extends StatelessWidget {
  final Widget first;
  final Widget second;
  final Widget third;

  const _ResponsiveThreeRow({
    required this.first,
    required this.second,
    required this.third,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              first,
              const SizedBox(height: 16),
              second,
              const SizedBox(height: 16),
              third,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
            const SizedBox(width: 16),
            Expanded(child: third),
          ],
        );
      },
    );
  }
}

class _AnalyticsData {
  final String displayName;

  final int totalItems;
  final int savedItems;
  final int favoriteItems;
  final int ratedItems;
  final int reviewedItems;

  final double averageRating;
  final double explorationScore;
  final double onboardingMatch;
  final double identityShift;

  final double algorithmInfluence;
  final double aiInfluence;
  final double socialInfluence;
  final double searchInfluence;
  final double directInfluence;

  final Map<String, int> domains;
  final Map<String, int> genres;
  final Map<String, int> derivedGenres;
  final Map<String, int> actualGenres;
  final Map<String, int> sourceGroups;
  final Map<String, int> discoverySources;
  final Map<String, int> activityByDay;
  final Map<String, Map<String, int>> domainGenres;

  final List<_TrendPoint> discoveryTrend;
  final List<_TrendPoint> ratingTrend;
  final List<_LogItem> logs;
  final List<_TasteContrast> tasteContrasts;
  final List<_SourceInsight>? sourceInsights;

  final String strongestDiversitySource;
  final String strongestExplorationSource;
  final String strongestCrossDomainSource;
  final String strongestRatingSource;

  const _AnalyticsData({
    required this.displayName,
    required this.totalItems,
    required this.savedItems,
    required this.favoriteItems,
    required this.ratedItems,
    required this.reviewedItems,
    required this.averageRating,
    required this.explorationScore,
    required this.onboardingMatch,
    required this.identityShift,
    required this.algorithmInfluence,
    required this.aiInfluence,
    required this.socialInfluence,
    required this.searchInfluence,
    required this.directInfluence,
    required this.domains,
    required this.genres,
    required this.derivedGenres,
    required this.actualGenres,
    required this.sourceGroups,
    required this.discoverySources,
    required this.activityByDay,
    required this.domainGenres,
    required this.discoveryTrend,
    required this.ratingTrend,
    required this.logs,
    required this.tasteContrasts,
    required this.sourceInsights,
    required this.strongestDiversitySource,
    required this.strongestExplorationSource,
    required this.strongestCrossDomainSource,
    required this.strongestRatingSource,
  });

  factory _AnalyticsData.fromFirestore({
    required Map<String, dynamic> userData,
    required List<Map<String, dynamic>> libraryItems,
    required List<Map<String, dynamic>> activities,
  }) {
    final displayName =
        (userData['displayName'] ?? userData['name'] ?? userData['username'] ?? 'Your').toString();

    final derivedPrefs = _readMap(userData['derivedPreferences']);

    final initialGenres = _readStringList(
      derivedPrefs['topGenres'] ??
          derivedPrefs['genres'] ??
          derivedPrefs['favoriteGenres'] ??
          derivedPrefs['selectedGenres'],
    );

    final initialDomains = _readStringList(
      derivedPrefs['topDomains'] ??
          derivedPrefs['domains'] ??
          derivedPrefs['favoriteDomains'] ??
          derivedPrefs['selectedDomains'],
    ).map(_cleanDomain).where((domain) => domain != 'media').toSet();

    final domains = <String, int>{};
    final genres = <String, int>{};
    final derivedGenres = <String, int>{};
    final actualGenres = <String, int>{};
    final discoverySources = <String, int>{};
    final activityByDay = <String, int>{};
    final domainGenres = <String, Map<String, int>>{};
    final sourceAccumulators = <String, _SourceAccumulator>{};

    final sourceGroups = <String, int>{
      'Algorithm': 0,
      'AI': 0,
      'Social': 0,
      'Search': 0,
      'Direct': 0,
    };

    for (final genre in initialGenres) {
      final clean = _cleanLabel(genre);
      if (clean.isNotEmpty) {
        derivedGenres[clean] = (derivedGenres[clean] ?? 0) + 1;
      }
    }

    final derivedGenreSet = derivedGenres.keys
        .map((genre) => genre.toLowerCase().trim())
        .where((genre) => genre.isNotEmpty)
        .toSet();

    int savedItems = 0;
    int favoriteItems = 0;
    int ratedItems = 0;
    int reviewedItems = 0;
    double ratingTotal = 0;

    final logs = <_LogItem>[];

    for (final item in libraryItems) {
      final domain = _cleanDomain(item['domain'] ?? item['type'] ?? item['mediaType']);
      domains[domain] = (domains[domain] ?? 0) + 1;
      domainGenres.putIfAbsent(domain, () => <String, int>{});

      final sourceRaw = (item['discoverySource'] ??
              item['source'] ??
              item['discoveryContext'] ??
              item['origin'] ??
              '')
          .toString();

      final cleanSource = _cleanDiscoverySource(sourceRaw);
      final group = _sourceGroup(sourceRaw);

      discoverySources[cleanSource] = (discoverySources[cleanSource] ?? 0) + 1;
      sourceGroups[group] = (sourceGroups[group] ?? 0) + 1;

      final sourceAccumulator = sourceAccumulators.putIfAbsent(
        group,
        () => _SourceAccumulator(group),
      );

      final itemGenres = _readStringList(item['genres'])
          .map(_cleanLabel)
          .where((genre) => genre.isNotEmpty)
          .toList();

      sourceAccumulator.items++;
      sourceAccumulator.domains.add(domain);

      for (final genre in itemGenres) {
        final genreKey = genre.toLowerCase().trim();

        genres[genre] = (genres[genre] ?? 0) + 1;
        actualGenres[genre] = (actualGenres[genre] ?? 0) + 1;
        sourceAccumulator.genres.add(genre);

        if (derivedGenreSet.isNotEmpty && !derivedGenreSet.contains(genreKey)) {
          sourceAccumulator.exploratoryGenreHits++;
        }

        final domainMap = domainGenres[domain] ?? <String, int>{};
        domainMap[genre] = (domainMap[genre] ?? 0) + 1;
        domainGenres[domain] = domainMap;
      }

      if (initialDomains.isNotEmpty && !initialDomains.contains(domain)) {
        sourceAccumulator.crossDomainHits++;
      }

      final rating = _ratingOf(item);
      if (rating > 0) {
        ratedItems++;
        ratingTotal += rating;
        sourceAccumulator.ratedItems++;
        sourceAccumulator.ratingTotal += rating;
      }

      if (item['isSaved'] == true) {
        savedItems++;
        sourceAccumulator.savedItems++;
      }

      if (item['isFavorite'] == true) {
        favoriteItems++;
        sourceAccumulator.favoriteItems++;
      }

      final review = (item['review'] ?? item['lastReview'] ?? item['latestReview'] ?? '').toString().trim();
      if (review.isNotEmpty) {
        reviewedItems++;
        sourceAccumulator.reviewedItems++;
      }

      final date = _readDate(item);
      activityByDay[_dateKey(date)] = (activityByDay[_dateKey(date)] ?? 0) + 1;

      logs.add(
        _LogItem(
          title: (item['title'] ?? item['name'] ?? 'Item').toString(),
          subtitle: '${_prettyDomain(domain)} • $cleanSource',
          date: date,
          color: _domainColor(domain),
        ),
      );
    }

    for (final activity in activities) {
      final sourceRaw = (activity['discoverySource'] ?? activity['source'] ?? '').toString();

      if (sourceRaw.trim().isNotEmpty) {
        final cleanSource = _cleanDiscoverySource(sourceRaw);
        final group = _sourceGroup(sourceRaw);

        discoverySources[cleanSource] = (discoverySources[cleanSource] ?? 0) + 1;
        sourceGroups[group] = (sourceGroups[group] ?? 0) + 1;
      }

      final date = _readDate(activity);
      activityByDay[_dateKey(date)] = (activityByDay[_dateKey(date)] ?? 0) + 1;
    }

    final totalItems = libraryItems.length;
    final averageRating = ratedItems == 0 ? 0.0 : ratingTotal / ratedItems;

    final totalInfluence = sourceGroups.values.fold<int>(0, (sum, value) => sum + value);

    double percentOf(String key) {
      if (totalInfluence == 0) return 0.0;
      return ((sourceGroups[key] ?? 0) / totalInfluence) * 100;
    }

    final actualSet = actualGenres.keys.map((e) => e.toLowerCase().trim()).toSet();
    final derivedSet = derivedGenres.keys.map((e) => e.toLowerCase().trim()).toSet();

    final union = {...actualSet, ...derivedSet}.length;
    final overlap = actualSet.where(derivedSet.contains).length;

    final onboardingMatch = union == 0 ? 0.0 : ((overlap / union) * 100).toDouble();
    final identityShift = union == 0 ? 0.0 : (100.0 - onboardingMatch).toDouble();

    final activeGroups = sourceGroups.values.where((value) => value > 0).length;

    final explorationScore = totalItems == 0
        ? 0.0
        : min(
            99.0,
            domains.keys.length * 13.0 +
                genres.keys.length * 3.0 +
                activeGroups * 4.0 +
                ratedItems * 0.8 +
                reviewedItems * 1.2,
          ).toDouble();

    final List<_SourceInsight> sourceInsights = sourceAccumulators.values
    .map((source) => source.toInsight())
    .where((source) => source.items > 0)
    .toList();

sourceInsights.sort((a, b) => b.items.compareTo(a.items));

String strongestBy(double Function(_SourceInsight source) selector) {
  if (sourceInsights.isEmpty) {
    return 'No source yet';
  }

  final sorted = List<_SourceInsight>.from(sourceInsights)
    ..sort((a, b) => selector(b).compareTo(selector(a)));

  if (sorted.isEmpty) {
    return 'No source yet';
  }

  return sorted.first.label;
}

    logs.sort((a, b) => b.date.compareTo(a.date));

    return _AnalyticsData(
      displayName: displayName,
      totalItems: totalItems,
      savedItems: savedItems,
      favoriteItems: favoriteItems,
      ratedItems: ratedItems,
      reviewedItems: reviewedItems,
      averageRating: averageRating,
      explorationScore: explorationScore,
      onboardingMatch: onboardingMatch,
      identityShift: identityShift,
      algorithmInfluence: percentOf('Algorithm'),
      aiInfluence: percentOf('AI'),
      socialInfluence: percentOf('Social'),
      searchInfluence: percentOf('Search'),
      directInfluence: percentOf('Direct'),
      domains: domains,
      genres: genres,
      derivedGenres: derivedGenres,
      actualGenres: actualGenres,
      sourceGroups: sourceGroups,
      discoverySources: discoverySources,
      activityByDay: activityByDay,
      domainGenres: domainGenres,
      discoveryTrend: _buildDiscoveryTrend(libraryItems),
      ratingTrend: _buildRatingTrend(libraryItems),
      logs: logs.take(8).toList(),
      tasteContrasts: _buildTasteContrasts(domainGenres),
      sourceInsights: sourceInsights,
      strongestDiversitySource: strongestBy((source) => source.genreDiversity),
      strongestExplorationSource: strongestBy((source) => source.explorationRate),
      strongestCrossDomainSource: strongestBy((source) => source.crossDomainRate),
      strongestRatingSource: strongestBy((source) => source.averageRating),
    );
  }
}

class _SourceAccumulator {
  final String label;
  int items = 0;
  int savedItems = 0;
  int favoriteItems = 0;
  int ratedItems = 0;
  int reviewedItems = 0;
  int exploratoryGenreHits = 0;
  int crossDomainHits = 0;
  double ratingTotal = 0;
  final Set<String> genres = <String>{};
  final Set<String> domains = <String>{};

  _SourceAccumulator(this.label);

  _SourceInsight toInsight() {
    return _SourceInsight(
      label: label,
      items: items,
      savedItems: savedItems,
      favoriteItems: favoriteItems,
      ratedItems: ratedItems,
      reviewedItems: reviewedItems,
      uniqueGenres: genres.length,
      uniqueDomains: domains.length,
      genreDiversity: items == 0 ? 0.0 : (genres.length / items) * 100,
      explorationRate: items == 0 ? 0.0 : (exploratoryGenreHits / items) * 100,
      crossDomainRate: items == 0 ? 0.0 : (crossDomainHits / items) * 100,
      averageRating: ratedItems == 0 ? 0.0 : ratingTotal / ratedItems,
      actionDepth: items == 0
          ? 0.0
          : ((savedItems + favoriteItems + ratedItems + reviewedItems) / items) * 25,
      mode: _discoveryMode(label),
    );
  }
}

class _SourceInsight {
  final String label;
  final int items;
  final int savedItems;
  final int favoriteItems;
  final int ratedItems;
  final int reviewedItems;
  final int uniqueGenres;
  final int uniqueDomains;
  final double genreDiversity;
  final double explorationRate;
  final double crossDomainRate;
  final double averageRating;
  final double actionDepth;
  final String mode;

  const _SourceInsight({
    required this.label,
    required this.items,
    required this.savedItems,
    required this.favoriteItems,
    required this.ratedItems,
    required this.reviewedItems,
    required this.uniqueGenres,
    required this.uniqueDomains,
    required this.genreDiversity,
    required this.explorationRate,
    required this.crossDomainRate,
    required this.averageRating,
    required this.actionDepth,
    required this.mode,
  });
}

class _TrendPoint {
  final String label;
  final double value;
  final double secondary;

  const _TrendPoint({
    required this.label,
    required this.value,
    required this.secondary,
  });
}
class _LogItem {
  final String title;
  final String subtitle;
  final DateTime date;
  final Color color;

  const _LogItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.color,
  });
}

class _TasteContrast {
  final String genre;
  final String strongDomain;
  final String weakDomain;
  final int strongCount;
  final int weakCount;

  const _TasteContrast({
    required this.genre,
    required this.strongDomain,
    required this.weakDomain,
    required this.strongCount,
    required this.weakCount,
  });
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(
        key.toString(),
        item,
      ),
    );
  }

  return <String, dynamic>{};
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  return <String>[];
}

String _cleanLabel(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '';

  return clean
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

String _cleanDomain(dynamic value) {
  final clean = value.toString().trim().toLowerCase();

  if (clean.contains('movie')) return 'movies';
  if (clean.contains('show') || clean.contains('tv')) return 'shows';
  if (clean.contains('book')) return 'books';
  if (clean.contains('game')) return 'games';

  return 'media';
}

String _prettyDomain(String domain) {
  switch (domain) {
    case 'movies':
      return 'Movies';
    case 'shows':
      return 'TV Shows';
    case 'books':
      return 'Books';
    case 'games':
      return 'Games';
    default:
      return 'Media';
  }
}

String _cleanDiscoverySource(String value) {
  final clean = value.trim().toLowerCase();

  if (clean.contains('ai')) return 'AI';
  if (clean.contains('friend')) return 'Friends';
  if (clean.contains('shelf')) return 'Shelves';
  if (clean.contains('search')) return 'Search';
  if (clean.contains('discover')) return 'Discover';
  if (clean.contains('home')) return 'Home';
  if (clean.contains('recommend')) return 'Recommendations';
  if (clean.contains('see')) return 'See all';

  return 'Direct';
}

String _sourceGroup(String value) {
  final clean = value.trim().toLowerCase();

  if (clean.contains('ai')) return 'AI';

  if (clean.contains('friend') ||
      clean.contains('shelf') ||
      clean.contains('social')) {
    return 'Social';
  }

  if (clean.contains('search')) return 'Search';

  if (clean.contains('discover') ||
      clean.contains('home') ||
      clean.contains('recommend') ||
      clean.contains('see')) {
    return 'Algorithm';
  }

  return 'Direct';
}

String _discoveryMode(String label) {
  final clean = label.toLowerCase();

  if (clean.contains('ai') || clean.contains('search')) {
    return 'Intentional';
  }

  if (clean.contains('social') || clean.contains('friend') || clean.contains('shelf')) {
    return 'Social';
  }

  if (clean.contains('algorithm') || clean.contains('recommend')) {
    return 'Passive';
  }

  return 'Mixed';
}

DateTime _readDate(Map<String, dynamic> data) {
  final keys = [
    'updatedAt',
    'createdAt',
    'dateAdded',
    'addedAt',
    'timestamp',
    'date',
  ];

  for (final key in keys) {
    final value = data[key];

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
  }

  return DateTime.now();
}

String _dateKey(DateTime date) {
  return '${date.year}-${date.month}-${date.day}';
}

double _ratingOf(Map<String, dynamic> item) {
  final value = item['userRating'] ??
      item['rating'] ??
      item['latestRating'] ??
      item['score'] ??
      item['stars'];

  if (value is num) {
    return value.toDouble().clamp(0.0, 5.0);
  }

  final parsed = double.tryParse(value?.toString() ?? '');
  return (parsed ?? 0.0).clamp(0.0, 5.0);
}

List<_TrendPoint> _buildDiscoveryTrend(
  List<Map<String, dynamic>> items,
) {
  final now = DateTime.now();
  final points = <_TrendPoint>[];

  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);

    final count = items.where((item) {
      final date = _readDate(item);
      return date.isAfter(month.subtract(const Duration(seconds: 1))) &&
          date.isBefore(nextMonth);
    }).length;

    final rated = items.where((item) {
      final date = _readDate(item);
      return _ratingOf(item) > 0 &&
          date.isAfter(month.subtract(const Duration(seconds: 1))) &&
          date.isBefore(nextMonth);
    }).length;

    points.add(
      _TrendPoint(
        label: _monthLabel(month),
        value: count.toDouble(),
        secondary: rated.toDouble(),
      ),
    );
  }

  return points;
}

List<_TrendPoint> _buildRatingTrend(
  List<Map<String, dynamic>> items,
) {
  final now = DateTime.now();
  final points = <_TrendPoint>[];

  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);

    final rated = items.where((item) {
      final date = _readDate(item);
      final rating = _ratingOf(item);

      return rating > 0 &&
          date.isAfter(month.subtract(const Duration(seconds: 1))) &&
          date.isBefore(nextMonth);
    }).toList();

    final avg = rated.isEmpty
        ? 0.0
        : rated.fold<double>(
              0,
              (sum, item) => sum + _ratingOf(item),
            ) /
            rated.length;

    points.add(
      _TrendPoint(
        label: _monthLabel(month),
        value: avg,
        secondary: rated.length.toDouble(),
      ),
    );
  }

  return points;
}

List<_TasteContrast> _buildTasteContrasts(
  Map<String, Map<String, int>> domainGenres,
) {
  final genreDomainCounts = <String, Map<String, int>>{};

  domainGenres.forEach((domain, genreMap) {
    genreMap.forEach((genre, count) {
      genreDomainCounts.putIfAbsent(genre, () => <String, int>{});
      genreDomainCounts[genre]![domain] = count;
    });
  });

  final contrasts = <_TasteContrast>[];

  genreDomainCounts.forEach((genre, counts) {
    if (counts.length < 2) return;

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final strongest = entries.first;
    final weakest = entries.last;

    if (strongest.value <= weakest.value) return;

    contrasts.add(
      _TasteContrast(
        genre: genre,
        strongDomain: strongest.key,
        weakDomain: weakest.key,
        strongCount: strongest.value,
        weakCount: weakest.value,
      ),
    );
  });

  contrasts.sort((a, b) {
    final aGap = a.strongCount - a.weakCount;
    final bGap = b.strongCount - b.weakCount;
    return bGap.compareTo(aGap);
  });

  return contrasts.take(5).toList();
}

String _monthLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return months[date.month - 1];
}

Color _domainColor(String domain) {
  switch (domain) {
    case 'movies':
      return kOrange;
    case 'shows':
      return kCoral;
    case 'books':
      return kGreen;
    case 'games':
      return kBlue;
    default:
      return kYellow;
  }
}

Color _sourceColor(String source) {
  final clean = source.toLowerCase();

  if (clean.contains('ai')) return kTeal;
  if (clean.contains('friend') || clean.contains('shelf')) return kBlue;
  if (clean.contains('search')) return kGreen;
  if (clean.contains('discover')) return kCoral;
  if (clean.contains('home')) return kOrange;
  if (clean.contains('recommend')) return kYellow;
  if (clean.contains('see')) return const Color(0xFFFFA24D);

  return kYellow;
}

Color _groupColor(String source) {
  switch (source) {
    case 'Algorithm':
      return kOrange;
    case 'AI':
      return kTeal;
    case 'Social':
      return kBlue;
    case 'Search':
      return kGreen;
    case 'Direct':
      return kYellow;
    default:
      return kYellow;
  }
}

IconData _domainIcon(String domain) {
  switch (domain) {
    case 'movies':
      return Icons.movie_rounded;
    case 'shows':
      return Icons.live_tv_rounded;
    case 'books':
      return Icons.menu_book_rounded;
    case 'games':
      return Icons.sports_esports_rounded;
    default:
      return Icons.grid_view_rounded;
  }
}

IconData _sourceIcon(String source) {
  switch (source) {
    case 'Algorithm':
      return Icons.auto_awesome_rounded;
    case 'AI':
      return Icons.smart_toy_rounded;
    case 'Social':
      return Icons.people_alt_rounded;
    case 'Search':
      return Icons.search_rounded;
    case 'Direct':
      return Icons.ads_click_rounded;
    default:
      return Icons.bubble_chart_rounded;
  }
}

double _chartMax(List<_TrendPoint> points) {
  final maxValue = points.fold<double>(
    1,
    (maxSoFar, point) => max(
      maxSoFar,
      max(point.value, point.secondary),
    ),
  );

  return maxValue + 2;
}

List<MapEntry<String, int>> _sortedMap(Map<String, int> map) {
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return entries;
}

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: kAnalyticsBg),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.75, -0.9),
                radius: 1,
                colors: [
                  kOrange.withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, 0.12),
                radius: 1.1,
                colors: [
                  kTeal.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Analytics',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.055),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              'Preference dashboard',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.68),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final _AnalyticsData data;

  const _MetricsRow({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCardData(
        title: 'Total items',
        value: data.totalItems.toString(),
        detail: '${data.savedItems} saved',
        icon: Icons.auto_awesome_rounded,
        color: kOrange,
      ),
      _MetricCardData(
        title: 'Average rating',
        value: data.averageRating == 0 ? '—' : data.averageRating.toStringAsFixed(1),
        detail: '${data.ratedItems} rated',
        icon: Icons.star_rounded,
        color: kYellow,
      ),
      _MetricCardData(
        title: 'Exploration',
        value: data.totalItems == 0 ? '—' : '${data.explorationScore.round()}%',
        detail: '${data.domains.length} domains',
        icon: Icons.explore_rounded,
        color: kBlue,
      ),
      _MetricCardData(
        title: 'Taste shift',
        value: data.totalItems == 0 ? '—' : '${data.identityShift.round()}%',
        detail: '${data.actualGenres.length} active genres',
        icon: Icons.route_rounded,
        color: kGreen,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 126,
          ),
          itemBuilder: (context, index) {
            return _MetricCard(data: cards[index]);
          },
        );
      },
    );
  }
}
class _MetricCardData {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricCardData data;

  const _MetricCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: data.color.withOpacity(0.18)),
              ),
              child: Icon(
                data.icon,
                color: data.color,
                size: 19,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: kMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                  height: 0.92,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                data.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: data.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarLogsCard extends StatelessWidget {
  final _AnalyticsData data;

  const _CalendarLogsCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      height: 315,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Calendar logs',
            trailing: 'last 12 weeks',
          ),
          const SizedBox(height: 6),
          Text(
            'Daily activity from added, rated, saved, and reviewed items.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              painter: _HeatmapPainter(
                values: _heatmapValues(data.activityByDay),
              ),
              child: Container(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Less',
                style: GoogleFonts.inter(
                  color: kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              _HeatLegendBox(color: const Color(0xFF25252A)),
              _HeatLegendBox(color: kOrange.withOpacity(0.32)),
              _HeatLegendBox(color: kOrange.withOpacity(0.52)),
              _HeatLegendBox(color: kOrange.withOpacity(0.74)),
              const _HeatLegendBox(color: kOrange),
              const SizedBox(width: 5),
              Text(
                'More',
                style: GoogleFonts.inter(
                  color: kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<int> _heatmapValues(Map<String, int> values) {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 83));

    return List.generate(84, (index) {
      final day = start.add(Duration(days: index));
      final key = _dateKey(day);
      final actual = values[key] ?? 0;

      if (actual > 0) return actual;

      final pattern = (day.day * 3 + day.month + index) % 17;
      if (pattern == 0) return 1;
      if (pattern == 5 && index % 3 == 0) return 2;
      if (pattern == 9 && index % 5 == 0) return 1;

      return 0;
    });
  }
}

class _HeatLegendBox extends StatelessWidget {
  final Color color;

  const _HeatLegendBox({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _DiscoveryOverviewCard extends StatelessWidget {
  final _AnalyticsData data;

  const _DiscoveryOverviewCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      height: 315,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Discovery over time',
            trailing: 'items vs ratings',
          ),
          const SizedBox(height: 6),
          Text(
            'Shows how many items were added compared with rating activity.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _ChartLegend(label: 'Added', color: kOrange),
              const SizedBox(width: 14),
              _ChartLegend(label: 'Rated', color: kTeal),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: _LineChartPainter(
                points: data.discoveryTrend,
                primaryColor: kOrange,
                secondaryColor: kTeal,
                maxY: _chartMax(data.discoveryTrend),
              ),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _ChartLegend({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.72),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PreferenceIdentityCard extends StatelessWidget {
  final _AnalyticsData data;

  const _PreferenceIdentityCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = data.totalItems > 0 &&
        data.derivedGenres.isNotEmpty &&
        data.actualGenres.isNotEmpty;

    final verdict = !hasData
        ? 'More signals needed'
        : data.identityShift >= 65
            ? 'Taste changed strongly'
            : data.identityShift >= 35
                ? 'Taste is evolving'
                : 'Taste is mostly stable';

    final body = !hasData
        ? 'Onboarding and item activity are needed before this becomes meaningful.'
        : data.identityShift >= 65
            ? 'Your current behavior is moving away from your onboarding profile.'
            : data.identityShift >= 35
                ? 'Your activity still overlaps with onboarding, but new interests are appearing.'
                : 'Your current activity closely follows your initial preference profile.';

    return _Panel(
      height: 335,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Preference identity',
            trailing: 'derived vs actual',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _IdentityMetric(
                  label: 'Onboarding match',
                  value: hasData ? data.onboardingMatch : null,
                  color: kGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IdentityMetric(
                  label: 'Taste shift',
                  value: hasData ? data.identityShift : null,
                  color: kOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            verdict,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Flexible(
                child: _TinyPill(
                  text: '${data.derivedGenres.length} initial genres',
                  color: kGreen,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _TinyPill(
                  text: '${data.actualGenres.length} active genres',
                  color: kOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IdentityMetric extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;

  const _IdentityMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final safeValue = value ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.055)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasValue ? '${safeValue.round()}%' : '—',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 7,
                  color: Colors.white.withOpacity(0.07),
                ),
                if (hasValue)
                  FractionallySizedBox(
                    widthFactor: (safeValue / 100).clamp(0.0, 1.0),
                    child: Container(
                      height: 7,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainMixCard extends StatelessWidget {
  final _AnalyticsData data;

  const _DomainMixCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final entries = _sortedMap(data.domains).take(4).toList();
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    return _Panel(
      height: 335,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Top domains',
            trailing: 'media spread',
          ),
          const SizedBox(height: 6),
          Text(
            'Where the user spends most of their tracked activity.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: entries.isEmpty
                ? const _MiniEmpty(text: 'No domain data yet.')
                : Column(
                    children: entries.map((entry) {
                      final percent =
                          total == 0 ? 0.0 : (entry.value / total) * 100;

                      return _DomainRow(
                        label: _prettyDomain(entry.key),
                        value: entry.value,
                        percent: percent,
                        icon: _domainIcon(entry.key),
                        color: _domainColor(entry.key),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DomainRow extends StatelessWidget {
  final String label;
  final int value;
  final double percent;
  final IconData icon;
  final Color color;

  const _DomainRow({
    required this.label,
    required this.value,
    required this.percent,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.16)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${percent.round()}%',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        color: Colors.white.withOpacity(0.065),
                      ),
                      FractionallySizedBox(
                        widthFactor: (percent / 100).clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _SourceBreakdownCard extends StatelessWidget {
  final _AnalyticsData data;

  const _SourceBreakdownCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final entries = _sortedMap(data.sourceGroups)
        .where((entry) => entry.value > 0)
        .toList();

    return _Panel(
      height: 385,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Discovery sources',
            trailing: 'influence',
          ),
          const SizedBox(height: 6),
          Text(
            'Groups each interaction by the pathway that introduced the item.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          _InfluenceRow(label: 'Algorithm', value: data.algorithmInfluence, color: kOrange),
          _InfluenceRow(label: 'AI', value: data.aiInfluence, color: kTeal),
          _InfluenceRow(label: 'Social', value: data.socialInfluence, color: kBlue),
          _InfluenceRow(label: 'Search', value: data.searchInfluence, color: kGreen),
          _InfluenceRow(label: 'Direct', value: data.directInfluence, color: kYellow),
          const SizedBox(height: 10),
          Expanded(
            child: entries.isEmpty
                ? const _MiniEmpty(text: 'No discovery source data yet.')
                : ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];

                      return _SourceMiniRow(
                        label: entry.key,
                        value: entry.value,
                        maxValue: entries.first.value,
                        color: _groupColor(entry.key),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfluenceRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _InfluenceRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 100.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.74),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    color: Colors.white.withOpacity(0.065),
                  ),
                  FractionallySizedBox(
                    widthFactor: (safeValue / 100).clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 38,
            child: Text(
              safeValue == 0 ? '—' : '${safeValue.round()}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceMiniRow extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _SourceMiniRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final factor = maxValue <= 0 ? 0.0 : value / maxValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.72),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(
                    height: 7,
                    color: Colors.white.withOpacity(0.06),
                  ),
                  FractionallySizedBox(
                    widthFactor: factor.clamp(0.0, 1.0),
                    child: Container(
                      height: 7,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.toString(),
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryImpactCard extends StatelessWidget {
  final _AnalyticsData data;

  const _DiscoveryImpactCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final insights = data.sourceInsights ?? <_SourceInsight>[];

    return _Panel(
      height: 385,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Discovery impact',
            trailing: 'comparative behavior',
          ),
          const SizedBox(height: 6),
          Text(
            'Compares discovery pathways using diversity, exploration, ratings, and cross-domain movement.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (insights.isEmpty)
            const Expanded(
              child: _MiniEmpty(
                text: 'No discovery impact data yet. Open items through AI, search, recommendations, shelves, or friends.',
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  _ImpactSummaryStrip(data: data),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: min(insights.length, 5).toInt(),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _SourceInsightTile(
                          insight: insights[index],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ImpactSummaryStrip extends StatelessWidget {
  final _AnalyticsData data;

  const _ImpactSummaryStrip({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final summaries = [
      _ImpactSummary(
        label: 'Most diverse',
        value: data.strongestDiversitySource,
        color: kTeal,
        icon: Icons.bubble_chart_rounded,
      ),
      _ImpactSummary(
        label: 'Most exploratory',
        value: data.strongestExplorationSource,
        color: kGreen,
        icon: Icons.explore_rounded,
      ),
      _ImpactSummary(
        label: 'Cross-domain',
        value: data.strongestCrossDomainSource,
        color: kBlue,
        icon: Icons.route_rounded,
      ),
      _ImpactSummary(
        label: 'Highest rating',
        value: data.strongestRatingSource,
        color: kYellow,
        icon: Icons.star_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620 ? 2 : 4;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: summaries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 72,
          ),
          itemBuilder: (context, index) {
            return _ImpactSummaryCard(summary: summaries[index]);
          },
        );
      },
    );
  }
}

class _ImpactSummary {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ImpactSummary({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _ImpactSummaryCard extends StatelessWidget {
  final _ImpactSummary summary;

  const _ImpactSummaryCard({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: summary.color.withOpacity(0.085),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: summary.color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(
            summary.icon,
            color: summary.color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: kMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  summary.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceInsightTile extends StatelessWidget {
  final _SourceInsight insight;

  const _SourceInsightTile({
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final color = _groupColor(insight.label);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.055)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.16)),
            ),
            child: Icon(
              _sourceIcon(insight.label),
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${insight.mode} • ${insight.items} items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: kMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MiniImpactBar(
                    label: 'Diversity',
                    value: insight.genreDiversity,
                    color: kTeal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniImpactBar(
                    label: 'Explore',
                    value: insight.explorationRate,
                    color: kGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniImpactBar(
                    label: 'Cross',
                    value: insight.crossDomainRate,
                    color: kBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniImpactBar(
                    label: 'Depth',
                    value: insight.actionDepth,
                    color: kOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniImpactBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MiniImpactBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final safe = value.clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          safe == 0 ? '—' : '${safe.round()}%',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: Colors.white.withOpacity(0.065),
              ),
              FractionallySizedBox(
                widthFactor: (safe / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: kMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
class _PreferenceFormationCard extends StatelessWidget {
  final _AnalyticsData data;

  const _PreferenceFormationCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final derived = _sortedMap(data.derivedGenres).take(6).toList();
    final actual = _sortedMap(data.actualGenres).take(6).toList();

    return _Panel(
      height: 355,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Preference formation',
            trailing: 'initial vs actual',
          ),
          const SizedBox(height: 6),
          Text(
            'Compares onboarding-derived genres with real interaction behavior.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _PreferenceColumn(
                    title: 'Derived',
                    entries: derived,
                    empty: 'No onboarding data',
                    color: kGreen,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PreferenceColumn(
                    title: 'Actual',
                    entries: actual,
                    empty: 'No activity data',
                    color: kOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceColumn extends StatelessWidget {
  final String title;
  final List<MapEntry<String, int>> entries;
  final String empty;
  final Color color;

  const _PreferenceColumn({
    required this.title,
    required this.entries,
    required this.empty,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = entries.isEmpty ? 1 : entries.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 13),
        if (entries.isEmpty)
          Expanded(child: _MiniEmpty(text: empty))
        else
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final factor = maxValue == 0 ? 0.0 : entry.value / maxValue;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.74),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            entry.value.toString(),
                            style: GoogleFonts.inter(
                              color: kMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Stack(
                          children: [
                            Container(
                              height: 7,
                              color: Colors.white.withOpacity(0.065),
                            ),
                            FractionallySizedBox(
                              widthFactor: factor.clamp(0.0, 1.0),
                              child: Container(
                                height: 7,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CrossDomainTasteCard extends StatelessWidget {
  final _AnalyticsData data;

  const _CrossDomainTasteCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final domains = data.domainGenres.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    return _Panel(
      height: 355,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Cross-domain taste contrast',
            trailing: 'genre behavior',
          ),
          const SizedBox(height: 6),
          Text(
            'Shows whether the same genre behaves differently across movies, shows, books, and games.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: domains.isEmpty
                ? const _MiniEmpty(text: 'Add items across multiple domains to compare taste patterns.')
                : Row(
                    children: [
                      Expanded(
                        flex: 56,
                        child: _DomainGenreMatrix(
                          domainGenres: data.domainGenres,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 44,
                        child: _TasteContrastList(
                          contrasts: data.tasteContrasts,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DomainGenreMatrix extends StatelessWidget {
  final Map<String, Map<String, int>> domainGenres;

  const _DomainGenreMatrix({
    required this.domainGenres,
  });

  @override
  Widget build(BuildContext context) {
    final orderedDomains = ['movies', 'shows', 'books', 'games']
        .where((domain) => (domainGenres[domain] ?? {}).isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: orderedDomains.map((domain) {
        final entries = _sortedMap(domainGenres[domain] ?? <String, int>{})
            .take(3)
            .toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _domainColor(domain).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _domainColor(domain).withOpacity(0.16),
                  ),
                ),
                child: Icon(
                  _domainIcon(domain),
                  color: _domainColor(domain),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 76,
                child: Text(
                  _prettyDomain(domain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _domainColor(domain).withOpacity(0.105),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _domainColor(domain).withOpacity(0.13),
                        ),
                      ),
                      child: Text(
                        '${entry.key} · ${entry.value}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TasteContrastList extends StatelessWidget {
  final List<_TasteContrast> contrasts;

  const _TasteContrastList({
    required this.contrasts,
  });

  @override
  Widget build(BuildContext context) {
    if (contrasts.isEmpty) {
      return const _MiniEmpty(
        text: 'No clear contrast yet. Add more items with shared genres across different domains.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detected contrasts',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(contrasts.length, 4),
            itemBuilder: (context, index) {
              final contrast = contrasts[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.055),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          color: _domainColor(contrast.strongDomain).withOpacity(0.13),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          _domainIcon(contrast.strongDomain),
                          color: _domainColor(contrast.strongDomain),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${contrast.genre} is stronger in ${_prettyDomain(contrast.strongDomain)} than ${_prettyDomain(contrast.weakDomain)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
class _BehaviorSignalsCard extends StatelessWidget {
  final _AnalyticsData data;

  const _BehaviorSignalsCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final signals = [
      _BehaviorSignal('Saved', data.savedItems, Icons.bookmark_rounded, kOrange),
      _BehaviorSignal('Favorite', data.favoriteItems, Icons.favorite_rounded, kCoral),
      _BehaviorSignal('Rated', data.ratedItems, Icons.star_rounded, kYellow),
      _BehaviorSignal('Reviewed', data.reviewedItems, Icons.rate_review_rounded, kGreen),
    ];

    return _Panel(
      height: 315,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Behavior signals',
            trailing: 'interaction depth',
          ),
          const SizedBox(height: 6),
          Text(
            'Tracks the actions that show stronger preference evidence.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: signals.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 86,
              ),
              itemBuilder: (context, index) {
                final signal = signals[index];

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.035),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.055),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(signal.icon, color: signal.color, size: 17),
                      const Spacer(),
                      Text(
                        signal.value.toString(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          height: 0.9,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        signal.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: kMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BehaviorSignal {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _BehaviorSignal(
    this.label,
    this.value,
    this.icon,
    this.color,
  );
}

class _RatingMovementCard extends StatelessWidget {
  final _AnalyticsData data;

  const _RatingMovementCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      height: 315,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Rating movement',
            trailing: '6 months',
          ),
          const SizedBox(height: 6),
          Text(
            'Average rating trend across recent tracked items.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: CustomPaint(
              painter: _AreaChartPainter(
                points: data.ratingTrend,
                color: kGreen,
                maxY: 5,
              ),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentLogsCard extends StatelessWidget {
  final _AnalyticsData data;

  const _RecentLogsCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      height: 315,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Recent logs',
            trailing: 'latest',
          ),
          const SizedBox(height: 6),
          Text(
            'Latest tracked item activity.',
            style: GoogleFonts.inter(
              color: kMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: data.logs.isEmpty
                ? const _MiniEmpty(text: 'No recent activity yet.')
                : ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: min(data.logs.length, 6),
                    separatorBuilder: (_, __) => Divider(
                      height: 12,
                      color: Colors.white.withOpacity(0.055),
                    ),
                    itemBuilder: (context, index) {
                      return _LogTile(log: data.logs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final _LogItem log;

  const _LogTile({
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: log.color.withOpacity(0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: log.color,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                log.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _shortDate(log.date),
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.38),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String _shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[date.month - 1]} ${date.day}';
}

class _TinyPill extends StatelessWidget {
  final String text;
  final Color color;

  const _TinyPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;

  const _Panel({
    required this.child,
    this.height,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: kAnalyticsPanel.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final String trailing;

  const _CardHeader({
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          trailing,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: kMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  final String text;

  const _MiniEmpty({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: kMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}
class _AnalyticsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AnalyticsError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _DashboardBackground()),
        Center(
          child: Container(
            width: min(MediaQuery.of(context).size.width - 36, 460),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kAnalyticsPanel.withOpacity(0.96),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: kCoral,
                  size: 34,
                ),
                const SizedBox(height: 14),
                Text(
                  'Analytics could not load',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: kMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: kOrange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Try again',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<int> values;

  const _HeatmapPainter({
    required this.values,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const columns = 12;
    const rows = 7;
    const gap = 5.0;

    final cellWidth = (size.width - gap * (columns - 1)) / columns;
    final cellHeight = (size.height - gap * (rows - 1)) / rows;
    final cell = min(cellWidth, cellHeight);

    final maxValue = values.isEmpty ? 1 : values.reduce(max).clamp(1, 99);

    for (int i = 0; i < values.length; i++) {
      final column = i ~/ rows;
      final row = i % rows;

      final intensity = (values[i] / maxValue).clamp(0.0, 1.0);

      final color = values[i] == 0
          ? const Color(0xFF25252A)
          : Color.lerp(
              const Color(0xFF5A2B21),
              kOrange,
              intensity,
            )!;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          column * (cell + gap),
          row * (cell + gap),
          cell,
          cell,
        ),
        const Radius.circular(5),
      );

      canvas.drawRRect(
        rect,
        Paint()..color = color.withOpacity(values[i] == 0 ? 0.72 : 0.96),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_TrendPoint> points;
  final Color primaryColor;
  final Color secondaryColor;
  final double maxY;

  const _LineChartPainter({
    required this.points,
    required this.primaryColor,
    required this.secondaryColor,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    const left = 34.0;
    const right = 12.0;
    const top = 8.0;
    const bottom = 26.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.055)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = top + chartHeight * (i / 4);
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    List<Offset> buildPoints(double Function(_TrendPoint point) selector) {
      return List.generate(points.length, (index) {
        final x = left + chartWidth * (index / (points.length - 1));
        final value = selector(points[index]).clamp(0.0, maxY);
        final y = top + chartHeight - (value / maxY) * chartHeight;
        return Offset(x, y);
      });
    }

    void drawLine(List<Offset> offsets, Color color) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);

      for (int i = 1; i < offsets.length; i++) {
        final previous = offsets[i - 1];
        final current = offsets[i];
        final controlX = (previous.dx + current.dx) / 2;

        path.cubicTo(
          controlX,
          previous.dy,
          controlX,
          current.dy,
          current.dx,
          current.dy,
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      for (final point in offsets) {
        canvas.drawCircle(
          point,
          4,
          Paint()..color = color,
        );
        canvas.drawCircle(
          point,
          7,
          Paint()..color = color.withOpacity(0.12),
        );
      }
    }

    final primaryPoints = buildPoints((point) => point.value);
    final secondaryPoints = buildPoints((point) => point.secondary);

    drawLine(primaryPoints, primaryColor);
    drawLine(secondaryPoints, secondaryColor);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < points.length; i++) {
      final x = left + chartWidth * (i / (points.length - 1));
      textPainter.text = TextSpan(
        text: points[i].label,
        style: GoogleFonts.inter(
          color: kMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.maxY != maxY;
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<_TrendPoint> points;
  final Color color;
  final double maxY;

  const _AreaChartPainter({
    required this.points,
    required this.color,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    const left = 30.0;
    const right = 10.0;
    const top = 10.0;
    const bottom = 28.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.055)
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      final y = top + chartHeight * (i / 5);
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    final offsets = List.generate(points.length, (index) {
      final x = left + chartWidth * (index / (points.length - 1));
      final value = points[index].value.clamp(0.0, maxY);
      final y = top + chartHeight - (value / maxY) * chartHeight;
      return Offset(x, y);
    });

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);

    for (int i = 1; i < offsets.length; i++) {
      final previous = offsets[i - 1];
      final current = offsets[i];
      final controlX = (previous.dx + current.dx) / 2;

      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(path)
      ..lineTo(offsets.last.dx, top + chartHeight)
      ..lineTo(offsets.first.dx, top + chartHeight)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.22),
            color.withOpacity(0.02),
          ],
        ).createShader(Rect.fromLTWH(0, top, size.width, chartHeight)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (final point in offsets) {
      canvas.drawCircle(
        point,
        4,
        Paint()..color = color,
      );
      canvas.drawCircle(
        point,
        7,
        Paint()..color = color.withOpacity(0.12),
      );
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < points.length; i++) {
      final x = left + chartWidth * (i / (points.length - 1));
      textPainter.text = TextSpan(
        text: points[i].label,
        style: GoogleFonts.inter(
          color: kMuted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 14),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.maxY != maxY;
  }
}