import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kAnalyticsBg = Color(0xFF050507);
const Color kAnalyticsAccent = Color(0xFFFF8B3D);
const Color kAnalyticsSoft = Color(0xFF141418);

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
      userData: userDoc.data() ?? {},
      libraryItems: librarySnapshot.docs.map((doc) => doc.data()).toList(),
      activities: activitySnapshot.docs.map((doc) => doc.data()).toList(),
    );
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
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _AnalyticsError(
              message: snapshot.error?.toString() ?? 'Could not load analytics.',
              onRetry: () {
                setState(() {
                  _future = _loadAnalytics();
                });
              },
            );
          }

          final data = snapshot.data!;

          return Stack(
            children: [
              const Positioned.fill(child: _MinimalBackground()),
              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _TopNav(
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
                        child: _HeroStory(data: data),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 34, 26, 0),
                        child: _WrappedNumbers(data: data),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 42, 26, 0),
                        child: _TasteShiftSection(data: data),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 42, 26, 0),
                        child: _DiscoveryFlowSection(data: data),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 42, 26, 0),
                        child: _TasteMapSection(data: data),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 42, 26, 120),
                        child: _BehaviorSummary(data: data),
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

class _AnalyticsData {
  final String displayName;

  final List<Map<String, dynamic>> libraryItems;
  final List<Map<String, dynamic>> activities;

  final List<String> initialDomains;
  final List<String> initialGenres;
  final List<String> initialTags;

  final Map<String, int> actualDomains;
  final Map<String, int> actualGenres;
  final Map<String, int> discoverySources;
  final Map<String, int> ratingsByDomain;
  final Map<String, double> avgRatingByDomain;
  final Map<String, int> activityTypes;

  final int totalItems;
  final int ratedItems;
  final int reviewedItems;
  final int savedItems;
  final int favoriteItems;
  final int activeDomains;
  final int activeGenres;

  final double averageRating;
  final double tasteShiftScore;
  final double recommendationInfluence;
  final double socialInfluence;
  final double explorationScore;

  final String topDomain;
  final String topGenre;
  final String topDiscoverySource;
  final String strongestFinding;

  const _AnalyticsData({
    required this.displayName,
    required this.libraryItems,
    required this.activities,
    required this.initialDomains,
    required this.initialGenres,
    required this.initialTags,
    required this.actualDomains,
    required this.actualGenres,
    required this.discoverySources,
    required this.ratingsByDomain,
    required this.avgRatingByDomain,
    required this.activityTypes,
    required this.totalItems,
    required this.ratedItems,
    required this.reviewedItems,
    required this.savedItems,
    required this.favoriteItems,
    required this.activeDomains,
    required this.activeGenres,
    required this.averageRating,
    required this.tasteShiftScore,
    required this.recommendationInfluence,
    required this.socialInfluence,
    required this.explorationScore,
    required this.topDomain,
    required this.topGenre,
    required this.topDiscoverySource,
    required this.strongestFinding,
  });

  factory _AnalyticsData.fromFirestore({
    required Map<String, dynamic> userData,
    required List<Map<String, dynamic>> libraryItems,
    required List<Map<String, dynamic>> activities,
  }) {
    final displayName =
        (userData['displayName'] ?? userData['name'] ?? 'Your').toString();

    final derived = userData['derivedPreferences'] is Map<String, dynamic>
        ? userData['derivedPreferences'] as Map<String, dynamic>
        : <String, dynamic>{};

    final initialDomains = _stringList(derived['favoriteDomains']);
    final initialGenres = _stringList(derived['topGenres']);
    final initialTags = _stringList(derived['topTags']);

    final actualDomains = <String, int>{};
    final actualGenres = <String, int>{};
    final discoverySources = <String, int>{};
    final activityTypes = <String, int>{};

    final ratingsByDomain = <String, int>{};
    final ratingTotalsByDomain = <String, double>{};

    int ratedItems = 0;
    int reviewedItems = 0;
    int savedItems = 0;
    int favoriteItems = 0;

    double ratingTotal = 0;

    for (final item in libraryItems) {
      final domain = _cleanDomain((item['domain'] ?? '').toString());

      if (domain.isNotEmpty) {
        actualDomains[domain] = (actualDomains[domain] ?? 0) + 1;
      }

      for (final genre in _stringList(item['genres'])) {
        final clean = _cleanLabel(genre);
        if (clean.isEmpty) continue;
        actualGenres[clean] = (actualGenres[clean] ?? 0) + 1;
      }

      final source = _cleanDiscoverySource(
        (item['discoverySource'] ?? 'unknown').toString(),
      );

      discoverySources[source] = (discoverySources[source] ?? 0) + 1;

      final rating = _readRating(item);

      if (rating > 0) {
        ratedItems++;
        ratingTotal += rating;

        if (domain.isNotEmpty) {
          ratingsByDomain[domain] = (ratingsByDomain[domain] ?? 0) + 1;
          ratingTotalsByDomain[domain] =
              (ratingTotalsByDomain[domain] ?? 0) + rating;
        }
      }

      final review = (item['review'] ??
              item['lastReview'] ??
              item['latestReview'] ??
              '')
          .toString()
          .trim();

      if (review.isNotEmpty) reviewedItems++;
      if (item['isSaved'] == true) savedItems++;
      if (item['isFavorite'] == true) favoriteItems++;
    }

    for (final activity in activities) {
      final type = (activity['activityType'] ?? activity['type'] ?? '')
          .toString()
          .trim();

      if (type.isNotEmpty) {
        activityTypes[type] = (activityTypes[type] ?? 0) + 1;
      }

      final source = _cleanDiscoverySource(
        (activity['discoverySource'] ?? '').toString(),
      );

      if (source.isNotEmpty && source != 'unknown') {
        discoverySources[source] = (discoverySources[source] ?? 0) + 1;
      }
    }

    final avgRatingByDomain = <String, double>{};

    for (final entry in ratingsByDomain.entries) {
      final domain = entry.key;
      final count = entry.value;
      final total = ratingTotalsByDomain[domain] ?? 0;

      if (count > 0) {
        avgRatingByDomain[domain] = total / count;
      }
    }

    final totalItems = libraryItems.length;
    final averageRating = ratedItems == 0 ? 0.0 : ratingTotal / ratedItems;

    final topDomain = _topKey(actualDomains, fallback: 'none');
    final topGenre = _topKey(actualGenres, fallback: 'none');
    final topDiscoverySource = _topKey(discoverySources, fallback: 'unknown');

    final actualGenreSet =
        actualGenres.keys.map((e) => e.toLowerCase().trim()).toSet();

    final initialGenreSet =
        initialGenres.map((e) => e.toLowerCase().trim()).toSet();

    final newGenres =
        actualGenreSet.where((genre) => !initialGenreSet.contains(genre)).length;

    final tasteShiftScore =
        actualGenreSet.isEmpty ? 0.0 : (newGenres / actualGenreSet.length) * 100;

    final recommendationSources = [
      'home',
      'home_see_all',
      'discover',
      'discover_see_all',
      'see_all',
      'ai',
    ];

    final recommendationCount = discoverySources.entries
        .where((entry) => recommendationSources.contains(entry.key))
        .fold<int>(0, (sum, entry) => sum + entry.value);

    final socialCount = discoverySources.entries
        .where((entry) => entry.key == 'friend' || entry.key == 'shelf')
        .fold<int>(0, (sum, entry) => sum + entry.value);

    final totalDiscoveryEvents =
        discoverySources.values.fold<int>(0, (sum, value) => sum + value);

    final recommendationInfluence = totalDiscoveryEvents == 0
        ? 0.0
        : (recommendationCount / totalDiscoveryEvents) * 100;

    final socialInfluence = totalDiscoveryEvents == 0
        ? 0.0
        : (socialCount / totalDiscoveryEvents) * 100;

    final activeDomains = actualDomains.keys.length;
    final activeGenres = actualGenres.keys.length;

    final explorationScore = min(
      100.0,
      (activeDomains * 18) + min(activeGenres, 12) * 4 + tasteShiftScore * 0.35,
    );

    final strongestFinding = _buildStrongestFinding(
      totalItems: totalItems,
      topGenre: topGenre,
      topDomain: topDomain,
      tasteShiftScore: tasteShiftScore,
      recommendationInfluence: recommendationInfluence,
      socialInfluence: socialInfluence,
      explorationScore: explorationScore,
    );

    return _AnalyticsData(
      displayName: displayName,
      libraryItems: libraryItems,
      activities: activities,
      initialDomains: initialDomains,
      initialGenres: initialGenres,
      initialTags: initialTags,
      actualDomains: actualDomains,
      actualGenres: actualGenres,
      discoverySources: discoverySources,
      ratingsByDomain: ratingsByDomain,
      avgRatingByDomain: avgRatingByDomain,
      activityTypes: activityTypes,
      totalItems: totalItems,
      ratedItems: ratedItems,
      reviewedItems: reviewedItems,
      savedItems: savedItems,
      favoriteItems: favoriteItems,
      activeDomains: activeDomains,
      activeGenres: activeGenres,
      averageRating: averageRating,
      tasteShiftScore: tasteShiftScore,
      recommendationInfluence: recommendationInfluence,
      socialInfluence: socialInfluence,
      explorationScore: explorationScore,
      topDomain: topDomain,
      topGenre: topGenre,
      topDiscoverySource: topDiscoverySource,
      strongestFinding: strongestFinding,
    );
  }
    static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  static String _cleanLabel(String value) {
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

  static String _cleanDomain(String value) {
    final clean = value.trim().toLowerCase();

    switch (clean) {
      case 'movie':
      case 'movies':
        return 'movies';
      case 'show':
      case 'shows':
      case 'tv':
      case 'tv shows':
        return 'shows';
      case 'book':
      case 'books':
        return 'books';
      case 'game':
      case 'games':
        return 'games';
      default:
        return clean;
    }
  }

  static String _cleanDiscoverySource(String value) {
    final clean = value.trim().toLowerCase();

    if (clean.isEmpty) return 'unknown';

    if (clean.contains('ai')) return 'ai';
    if (clean.contains('friend')) return 'friend';
    if (clean.contains('shelf')) return 'shelf';
    if (clean.contains('search')) return 'search';
    if (clean.contains('home')) return clean;
    if (clean.contains('discover')) return clean;
    if (clean.contains('see_all')) return clean;

    return clean;
  }

  static double _readRating(Map<String, dynamic> data) {
    final candidates = [
      data['userRating'],
      data['rating'],
      data['latestRating'],
      data['score'],
      data['stars'],
    ];

    for (final value in candidates) {
      if (value is num) return value.toDouble();

      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }

    return 0.0;
  }

  static String _topKey(
    Map<String, int> map, {
    required String fallback,
  }) {
    if (map.isEmpty) return fallback;

    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.first.key;
  }

  static String _buildStrongestFinding({
    required int totalItems,
    required String topGenre,
    required String topDomain,
    required double tasteShiftScore,
    required double recommendationInfluence,
    required double socialInfluence,
    required double explorationScore,
  }) {
    if (totalItems == 0) {
      return 'Start saving, rating, and reviewing to reveal how your taste is forming.';
    }

    if (tasteShiftScore >= 55) {
      return 'Your real behavior has moved far beyond your original onboarding taste.';
    }

    if (socialInfluence >= 35) {
      return 'Friends and shelves are strongly shaping what you choose next.';
    }

    if (recommendationInfluence >= 45) {
      return 'Your exposure is being heavily shaped by recommendation surfaces.';
    }

    if (explorationScore >= 70) {
      return 'You explore widely across genres and media types.';
    }

    return 'Your taste is currently centered around $topGenre and $topDomain.';
  }
}

class _MinimalBackground extends StatelessWidget {
  const _MinimalBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: kAnalyticsBg),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.8, -0.9),
                radius: 1.0,
                colors: [
                  kAnalyticsAccent.withOpacity(0.18),
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
                center: const Alignment(-0.9, 0.15),
                radius: 0.9,
                colors: [
                  const Color(0xFF7C3AED).withOpacity(0.09),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.22),
                  Colors.transparent,
                  Colors.black.withOpacity(0.52),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopNav extends StatelessWidget {
  final VoidCallback onBack;

  const _TopNav({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Encore',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          Text(
            'Taste analytics',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.58),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStory extends StatelessWidget {
  final _AnalyticsData data;

  const _HeroStory({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final source = _prettySource(data.topDiscoverySource);
    final hasData = data.totalItems > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;

        final story = Column(
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            _TinyLabel(text: 'YOUR TASTE STORY'),
            const SizedBox(height: 22),
            Text(
              hasData
                  ? '${data.displayName}, your taste is being shaped by $source.'
                  : 'Your taste story is still waiting to unfold.',
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: compact ? 42 : 68,
                fontWeight: FontWeight.w900,
                letterSpacing: -3.4,
                height: 0.88,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Text(
                hasData
                    ? data.strongestFinding
                    : 'Interact with items through saving, rating, reviewing, shelves, friends, search, and recommendations to generate meaningful insights.',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.60),
                  fontSize: 15,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );

        final score = _HeroScore(
          score: data.explorationScore,
          title: 'Exploration',
          subtitle: '${data.activeDomains} domains • ${data.activeGenres} genres',
        );

        if (compact) {
          return Column(
            children: [
              story,
              const SizedBox(height: 34),
              score,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 3, child: story),
            const SizedBox(width: 36),
            Expanded(child: score),
          ],
        );
      },
    );
  }

  String _prettySource(String source) {
    switch (source) {
      case 'ai':
        return 'AI';
      case 'friend':
        return 'friends';
      case 'shelf':
        return 'shelves';
      case 'search':
        return 'search';
      case 'home':
      case 'home_see_all':
        return 'Home';
      case 'discover':
      case 'discover_see_all':
      case 'see_all':
        return 'Discover';
      default:
        return 'mixed discovery';
    }
  }
}

class _HeroScore extends StatelessWidget {
  final double score;
  final String title;
  final String subtitle;

  const _HeroScore({
    required this.score,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          _ScoreRing(
            score: score,
            size: 168,
            value: '${score.round()}%',
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.46),
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
class _WrappedNumbers extends StatelessWidget {
  final _AnalyticsData data;

  const _WrappedNumbers({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _NumberStat(
        value: data.totalItems.toString(),
        label: 'items tracked',
      ),
      _NumberStat(
        value: data.averageRating == 0
            ? '—'
            : data.averageRating.toStringAsFixed(1),
        label: 'avg rating',
      ),
      _NumberStat(
        value: '${data.tasteShiftScore.round()}%',
        label: 'taste shift',
      ),
      _NumberStat(
        value: '${data.socialInfluence.round()}%',
        label: 'social pull',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 900 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 118,
          ),
          itemBuilder: (context, index) {
            return _NumberCard(stat: stats[index]);
          },
        );
      },
    );
  }
}

class _NumberStat {
  final String value;
  final String label;

  const _NumberStat({
    required this.value,
    required this.label,
  });
}

class _NumberCard extends StatelessWidget {
  final _NumberStat stat;

  const _NumberCard({
    required this.stat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            stat.value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
              height: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stat.label,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.46),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TasteShiftSection extends StatelessWidget {
  final _AnalyticsData data;

  const _TasteShiftSection({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final initial = data.initialGenres.take(7).toList();
    final actual = _sortedEntries(data.actualGenres).take(7).toList();

    return _SectionShell(
      eyebrow: 'PREFERENCE SHIFT',
      title: 'What you thought you liked vs what you actually chose',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 850;

          final initialBlock = _MinimalBlock(
            title: 'Initial signals',
            subtitle: 'Onboarding',
            child: initial.isEmpty
                ? const _EmptyTiny(text: 'No onboarding genres found.')
                : Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: initial.map((genre) {
                      return _SoftPill(text: genre);
                    }).toList(),
                  ),
          );

          final shiftBlock = _ShiftCenter(
            score: data.tasteShiftScore,
            text: data.tasteShiftScore >= 50
                ? 'Your real behavior broke away from the first profile.'
                : 'Your real behavior still overlaps with onboarding.',
          );

          final actualBlock = _MinimalBlock(
            title: 'Actual signals',
            subtitle: 'From saves, ratings, reviews',
            child: actual.isEmpty
                ? const _EmptyTiny(text: 'No activity genres yet.')
                : Column(
                    children: actual.map((entry) {
                      return _ThinBar(
                        label: entry.key,
                        value: entry.value,
                        maxValue: actual.first.value,
                      );
                    }).toList(),
                  ),
          );

          if (compact) {
            return Column(
              children: [
                initialBlock,
                const SizedBox(height: 14),
                shiftBlock,
                const SizedBox(height: 14),
                actualBlock,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: initialBlock),
              const SizedBox(width: 16),
              SizedBox(width: 280, child: shiftBlock),
              const SizedBox(width: 16),
              Expanded(child: actualBlock),
            ],
          );
        },
      ),
    );
  }
}

class _DiscoveryFlowSection extends StatelessWidget {
  final _AnalyticsData data;

  const _DiscoveryFlowSection({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final sources = _groupSources(data.discoverySources);
    final entries = _sortedEntries(sources).take(6).toList();

    return _SectionShell(
      eyebrow: 'DISCOVERY FLOW',
      title: 'The paths that shaped your choices',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 850;

          final left = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                '${data.recommendationInfluence.round()}%',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3.5,
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'recommendation-shaped exposure',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.inter(
                  color: kAnalyticsAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Home, Discover, See All, and AI are treated as recommendation surfaces. Friends and shelves are counted as social discovery.',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.52),
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _InlineMetric(
                label: 'social discovery',
                value: '${data.socialInfluence.round()}%',
              ),
              const SizedBox(height: 10),
              _InlineMetric(
                label: 'top source',
                value: _prettySource(data.topDiscoverySource),
              ),
            ],
          );

          final right = entries.isEmpty
              ? const _EmptyTiny(text: 'No discovery paths tracked yet.')
              : Column(
                  children: entries.map((entry) {
                    return _SourceLine(
                      label: _prettySource(entry.key),
                      value: entry.value,
                      maxValue: entries.first.value,
                      color: _sourceColor(entry.key),
                    );
                  }).toList(),
                );

          if (compact) {
            return Column(
              children: [
                left,
                const SizedBox(height: 24),
                right,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 2, child: left),
              const SizedBox(width: 36),
              Expanded(flex: 3, child: right),
            ],
          );
        },
      ),
    );
  }

  Map<String, int> _groupSources(Map<String, int> raw) {
    final grouped = <String, int>{};

    for (final entry in raw.entries) {
      final key = entry.key;

      String group;
      if (key == 'ai') {
        group = 'ai';
      } else if (key == 'friend') {
        group = 'friend';
      } else if (key == 'shelf') {
        group = 'shelf';
      } else if (key == 'search') {
        group = 'search';
      } else if (key.contains('home')) {
        group = 'home';
      } else if (key.contains('discover') || key.contains('see_all')) {
        group = 'discover';
      } else {
        group = 'unknown';
      }

      grouped[group] = (grouped[group] ?? 0) + entry.value;
    }

    return grouped;
  }

  String _prettySource(String source) {
    switch (source) {
      case 'ai':
        return 'AI';
      case 'friend':
        return 'Friends';
      case 'shelf':
        return 'Shelves';
      case 'search':
        return 'Search';
      case 'home':
        return 'Home';
      case 'discover':
        return 'Discover';
      default:
        return 'Unknown';
    }
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'ai':
        return const Color(0xFFB794F6);
      case 'friend':
        return const Color(0xFF60A5FA);
      case 'shelf':
        return const Color(0xFF34D399);
      case 'search':
        return const Color(0xFFFBBF24);
      case 'home':
        return kAnalyticsAccent;
      case 'discover':
        return const Color(0xFFFF6F91);
      default:
        return Colors.white70;
    }
  }
}
class _TasteMapSection extends StatelessWidget {
  final _AnalyticsData data;

  const _TasteMapSection({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final domains = _sortedEntries(data.actualDomains);
    final ratings = data.avgRatingByDomain.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _SectionShell(
      eyebrow: 'TASTE MAP',
      title: 'Where your attention actually goes',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;

          final domainBlock = _MinimalBlock(
            title: 'Domain spread',
            subtitle: '${data.activeDomains} active domains',
            child: domains.isEmpty
                ? const _EmptyTiny(text: 'No domains yet.')
                : Column(
                    children: domains.map((entry) {
                      return _ThinBar(
                        label: _prettyDomain(entry.key),
                        value: entry.value,
                        maxValue: domains.first.value,
                      );
                    }).toList(),
                  ),
          );

          final genreBlock = _MinimalBlock(
            title: 'Top genres',
            subtitle: '${data.activeGenres} active genres',
            child: data.actualGenres.isEmpty
                ? const _EmptyTiny(text: 'No genres yet.')
                : Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: _sortedEntries(data.actualGenres)
                        .take(10)
                        .map((entry) {
                      return _SoftPill(
                        text: '${entry.key} · ${entry.value}',
                      );
                    }).toList(),
                  ),
          );

          final ratingBlock = _MinimalBlock(
            title: 'Enjoyment signal',
            subtitle: 'Average rating by domain',
            child: ratings.isEmpty
                ? const _EmptyTiny(text: 'No ratings yet.')
                : Column(
                    children: ratings.map((entry) {
                      return _RatingLine(
                        label: _prettyDomain(entry.key),
                        rating: entry.value,
                      );
                    }).toList(),
                  ),
          );

          if (compact) {
            return Column(
              children: [
                domainBlock,
                const SizedBox(height: 14),
                genreBlock,
                const SizedBox(height: 14),
                ratingBlock,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: domainBlock),
              const SizedBox(width: 16),
              Expanded(child: genreBlock),
              const SizedBox(width: 16),
              Expanded(child: ratingBlock),
            ],
          );
        },
      ),
    );
  }

  String _prettyDomain(String domain) {
    switch (domain) {
      case 'movies':
        return 'Movies';
      case 'shows':
        return 'Shows';
      case 'books':
        return 'Books';
      case 'games':
        return 'Games';
      default:
        return domain;
    }
  }
}

class _BehaviorSummary extends StatelessWidget {
  final _AnalyticsData data;

  const _BehaviorSummary({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      eyebrow: 'BEHAVIOR SIGNALS',
      title: 'What your actions say about your taste',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;

          final signals = [
            _ActionSignal(
              label: 'Saved',
              value: data.savedItems,
              icon: Icons.bookmark_rounded,
            ),
            _ActionSignal(
              label: 'Favorited',
              value: data.favoriteItems,
              icon: Icons.favorite_rounded,
            ),
            _ActionSignal(
              label: 'Rated',
              value: data.ratedItems,
              icon: Icons.star_rounded,
            ),
            _ActionSignal(
              label: 'Reviewed',
              value: data.reviewedItems,
              icon: Icons.rate_review_rounded,
            ),
          ];

          final left = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                data.ratedItems == 0
                    ? 'No strong rating signal yet.'
                    : 'Your strongest preference evidence comes from ${data.ratedItems} ratings.',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.3,
                  height: 1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Saves show interest. Favorites show attachment. Ratings and reviews show stronger preference evidence.',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.52),
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          final right = GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: signals.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: compact ? 2 : 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 112,
            ),
            itemBuilder: (context, index) {
              return _ActionSignalCard(signal: signals[index]);
            },
          );

          if (compact) {
            return Column(
              children: [
                left,
                const SizedBox(height: 22),
                right,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: 24),
              right,
            ],
          );
        },
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget child;

  const _SectionShell({
    required this.eyebrow,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TinyLabel(text: eyebrow),
          const SizedBox(height: 11),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
                height: 0.98,
              ),
            ),
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _MinimalBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _MinimalBlock({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.038),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.055)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.40),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ShiftCenter extends StatelessWidget {
  final double score;
  final String text;

  const _ShiftCenter({
    required this.score,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kAnalyticsAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: kAnalyticsAccent.withOpacity(0.16)),
      ),
      child: Column(
        children: [
          _ScoreRing(
            score: score,
            size: 138,
            value: '${score.round()}%',
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.68),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinBar extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;

  const _ThinBar({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final factor = maxValue <= 0 ? 0.0 : value / maxValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                    color: Colors.white.withOpacity(0.74),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                value.toString(),
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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
                  color: Colors.white.withOpacity(0.07),
                ),
                FractionallySizedBox(
                  widthFactor: factor.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [
                          kAnalyticsAccent,
                          Color(0xFFFF6F91),
                        ],
                      ),
                    ),
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
class _SourceLine extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const _SourceLine({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final factor = maxValue <= 0 ? 0.0 : value / maxValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.72),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(
                    height: 28,
                    color: Colors.white.withOpacity(0.065),
                  ),
                  FractionallySizedBox(
                    widthFactor: factor.clamp(0.0, 1.0),
                    child: Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 34,
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.50),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  final String label;
  final double rating;

  const _RatingLine({
    required this.label,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final factor = (rating / 5).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.72),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    color: Colors.white.withOpacity(0.07),
                  ),
                  FractionallySizedBox(
                    widthFactor: factor,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: kAnalyticsAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.48),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InlineMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.055)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  final String text;

  const _SoftPill({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.065)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.76),
          fontSize: 12.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TinyLabel extends StatelessWidget {
  final String text;

  const _TinyLabel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: kAnalyticsAccent,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _ActionSignal {
  final String label;
  final int value;
  final IconData icon;

  const _ActionSignal({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _ActionSignalCard extends StatelessWidget {
  final _ActionSignal signal;

  const _ActionSignalCard({
    required this.signal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.055)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(signal.icon, color: kAnalyticsAccent, size: 20),
          const Spacer(),
          Text(
            signal.value.toString(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 0.9,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            signal.label,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.48),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final double score;
  final double size;
  final String value;

  const _ScoreRing({
    required this.score,
    required this.size,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: (score / 100).clamp(0.0, 1.0),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: size < 150 ? 31 : 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  const _RingPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.07;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          kAnalyticsAccent,
          Color(0xFFFF6F91),
          Color(0xFFB794F6),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      progress * 2 * pi,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _EmptyTiny extends StatelessWidget {
  final String text;

  const _EmptyTiny({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.44),
          fontSize: 12.5,
          height: 1.45,
          fontWeight: FontWeight.w700,
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
    return Scaffold(
      backgroundColor: kAnalyticsBg,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(22),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: kAnalyticsAccent,
                size: 38,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load analytics',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.54),
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: kAnalyticsAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Try again',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<MapEntry<String, int>> _sortedEntries(Map<String, int> map) {
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return entries;
}