import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/media_seed_service.dart';
import '../../ai/widgets/ai_recommendation_panel.dart';
import '../../discover/screens/discover_results_screen.dart';
import '../../items/screens/item_details_screen.dart';
import '../../profile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MediaSeedService _mediaSeedService = MediaSeedService();
  final PageController _heroController = PageController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _navScrolled = false;
  String? _error;
  int _heroIndex = 0;

  List<String> _topGenres = [];

  List<OnboardingMediaItem> _popularItems = [];
  List<OnboardingMediaItem> _discoverItems = [];
  List<OnboardingMediaItem> _becauseYouLikedItems = [];
  List<_FriendActivity> _friendActivities = [];

  static const double _heroHeight = 560;
  static const double _navHeight = 92;
  static const double _cardWidth = 220;
  static const double _rowHeight = 360;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadHomeFeed();
  }

  void _handleScroll() {
    final scrolled =
        _scrollController.hasClients && _scrollController.offset > 24;

    if (scrolled != _navScrolled && mounted) {
      setState(() => _navScrolled = scrolled);
    }
  }

  Future<void> _loadHomeFeed() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preferences = await _loadUserPreferences();
      final fetchedItems =
          await _mediaSeedService.getMixedPopularFeed(limit: 72);

      final favoriteDomains = preferences.favoriteDomains.isEmpty
          ? ['movies', 'shows', 'books', 'games']
          : preferences.favoriteDomains;

      final topGenres = preferences.topGenres;
      final topTags = preferences.topTags;

      final popular = _buildPopularItems(fetchedItems);

      final scored = _scoreItems(
        fetchedItems,
        favoriteDomains: favoriteDomains,
        topGenres: topGenres,
        topTags: topTags,
      );

      final discover = _buildDiscoverItems(scored);

      final becauseYouLiked = _buildBecauseYouLikedItems(
        scored,
        topGenres: topGenres,
      );

      final friendActivities = await _loadFriendActivitiesThisWeek();

      if (!mounted) return;

      setState(() {
        _topGenres = topGenres;
        _popularItems = popular;
        _discoverItems = discover;
        _becauseYouLikedItems = becauseYouLiked;
        _friendActivities = friendActivities;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<_DerivedPreferences> _loadUserPreferences() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _DerivedPreferences(
        favoriteDomains: ['movies', 'shows', 'books', 'games'],
        topGenres: ['Drama', 'Thriller', 'Fantasy'],
        topTags: [],
      );
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final data = doc.data() ?? {};

    final derived = data['derivedPreferences'] is Map<String, dynamic>
        ? data['derivedPreferences'] as Map<String, dynamic>
        : <String, dynamic>{};

    return _DerivedPreferences(
      favoriteDomains: (derived['favoriteDomains'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      topGenres:
          (derived['topGenres'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      topTags:
          (derived['topTags'] as List?)?.map((e) => e.toString()).toList() ??
              [],
    );
  }

  Future<List<String>> _loadFollowingIds(String currentUid) async {
    final ids = <String>{};

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();

    final userData = userDoc.data() ?? {};
    final followingRaw = userData['following'];

    if (followingRaw is List) {
      for (final value in followingRaw) {
        if (value is String) {
          final clean = value.trim();
          if (clean.isNotEmpty && clean != currentUid) {
            ids.add(clean);
          }
        }

        if (value is Map) {
          final uid = (value['uid'] ?? value['userId'] ?? value['id'] ?? '')
              .toString()
              .trim();

          if (uid.isNotEmpty && uid != currentUid) {
            ids.add(uid);
          }
        }
      }
    }

    try {
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .get();

      for (final doc in followingSnapshot.docs) {
        final id = doc.id.trim();
        if (id.isNotEmpty && id != currentUid) {
          ids.add(id);
        }
      }
    } catch (_) {}

    return ids.toList();
  }

  Future<List<_FriendActivity>> _loadFriendActivitiesThisWeek() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final following = await _loadFollowingIds(user.uid);
    if (following.isEmpty) return [];

    final startOfWeek = DateTime.now().subtract(const Duration(days: 7));
    final activities = <_FriendActivity>[];

    for (final followedUid in following) {
      final friendDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(followedUid)
          .get();

      if (!friendDoc.exists) continue;

      final friendData = friendDoc.data() ?? {};

      final displayName =
          (friendData['displayName'] ?? friendData['name'] ?? 'User')
              .toString();

      final username = (friendData['username'] ?? '').toString();

      final photoUrl =
          (friendData['photoUrl'] ?? friendData['avatarUrl'] ?? '').toString();

      final activitySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(followedUid)
          .collection('activity')
          .get();

      for (final doc in activitySnapshot.docs) {
        final data = doc.data();

        final createdAt = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : null;

        if (createdAt == null) continue;
        if (createdAt.isBefore(startOfWeek)) continue;

        final rawType =
            (data['activityType'] ?? data['type'] ?? '').toString().trim();

        final reviewText =
            (data['review'] ?? data['text'] ?? '').toString().trim();

        final rating = data['userRating'] is num
            ? (data['userRating'] as num).toDouble()
            : data['rating'] is num
                ? (data['rating'] as num).toDouble()
                : 0.0;

        final isReview = rawType == 'reviewed' ||
            rawType == 'review' ||
            reviewText.isNotEmpty;

        final isRating =
            rawType == 'rated' || rawType == 'rating' || rating > 0;

        final isFavorite = rawType == 'favorited' ||
            rawType == 'favorite' ||
            rawType == 'liked' ||
            rawType == 'like';

        final isSaved = rawType == 'saved' || rawType == 'save';

        final isRemoved = rawType == 'unsaved' ||
            rawType == 'unfavorited' ||
            rawType == 'removed' ||
            rawType == 'removed_saved' ||
            rawType == 'removed_favorite';

        if (isRemoved) continue;
        if (!isReview && !isRating && !isFavorite && !isSaved) continue;

        final itemId =
            (data['itemId'] ?? data['safeItemId'] ?? data['id'] ?? '')
                .toString();

        final title = (data['title'] ?? 'Untitled').toString();
        final domain = (data['domain'] ?? '').toString();
        final imageUrl = (data['imageUrl'] ?? '').toString();
        final source = (data['source'] ?? 'activity').toString();

        if (itemId.trim().isEmpty && title.trim().isEmpty) continue;

        activities.add(
          _FriendActivity(
            userId: followedUid,
            displayName: displayName,
            username: username,
            userPhotoUrl: photoUrl,
            itemId: itemId,
            title: title,
            domain: domain,
            imageUrl: imageUrl,
            source: source,
            type: isReview
                ? 'reviewed'
                : isRating
                    ? 'rated'
                    : isFavorite
                        ? 'favorited'
                        : 'saved',
            rating: rating,
            review: reviewText,
            createdAt: createdAt,
          ),
        );
      }
    }

    activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final latestByItem = <String, _FriendActivity>{};

    for (final activity in activities) {
      final key = _activityItemKey(activity);
      if (key.isEmpty) continue;

      final existing = latestByItem[key];

      if (existing == null || activity.createdAt.isAfter(existing.createdAt)) {
        latestByItem[key] = activity;
      }
    }

    final deduped = latestByItem.values.toList();
    deduped.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return deduped;
  }

  String _activityItemKey(_FriendActivity activity) {
    final rawId = activity.itemId.trim().toLowerCase();

    if (rawId.isNotEmpty) {
      return rawId
          .replaceAll('tmdb_movie_', '')
          .replaceAll('tmdb_show_', '')
          .replaceAll('rawg_game_', '')
          .replaceAll('google_book_', '')
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    return activity.title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
    List<OnboardingMediaItem> _buildPopularItems(List<OnboardingMediaItem> items) {
    final scored = items.map((item) {
      var score = 0;

      if (item.imageUrl.trim().isNotEmpty) score += 20;
      if (item.description.trim().isNotEmpty) score += 12;
      if (item.genres.isNotEmpty) score += 6;
      if (item.domain == 'movies' || item.domain == 'shows') score += 8;

      return _ScoredItem(item: item, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    final seenTitles = <String>{};
    final popular = <OnboardingMediaItem>[];

    for (final entry in scored) {
      final item = entry.item;
      final key = item.title.trim().toLowerCase();

      if (item.imageUrl.trim().isEmpty) continue;
      if (key.isEmpty || seenTitles.contains(key)) continue;

      seenTitles.add(key);
      popular.add(item);

      if (popular.length >= 8) break;
    }

    return popular;
  }

  List<_ScoredItem> _scoreItems(
    List<OnboardingMediaItem> items, {
    required List<String> favoriteDomains,
    required List<String> topGenres,
    required List<String> topTags,
  }) {
    final scored = <_ScoredItem>[];

    for (final item in items) {
      var score = 0;

      if (favoriteDomains.contains(item.domain)) score += 30;

      for (final genre in item.genres) {
        if (topGenres.any((g) => g.toLowerCase() == genre.toLowerCase())) {
          score += 18;
        }
      }

      for (final tag in item.tags) {
        if (topTags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
          score += 8;
        }
      }

      if (item.imageUrl.trim().isNotEmpty) score += 6;
      if (item.genres.isNotEmpty) score += 4;

      scored.add(_ScoredItem(item: item, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  List<OnboardingMediaItem> _buildDiscoverItems(List<_ScoredItem> scored) {
    final discover = <OnboardingMediaItem>[];
    final seen = <String>{};

    for (final entry in scored) {
      final item = entry.item;
      final key = item.title.trim().toLowerCase();

      if (seen.contains(key)) continue;
      if (item.imageUrl.trim().isEmpty) continue;

      seen.add(key);
      discover.add(item);

      if (discover.length >= 12) break;
    }

    return discover;
  }

  List<OnboardingMediaItem> _buildBecauseYouLikedItems(
    List<_ScoredItem> scored, {
    required List<String> topGenres,
  }) {
    if (topGenres.isEmpty) {
      return scored.map((e) => e.item).take(10).toList();
    }

    final targetGenre = topGenres.first.toLowerCase();

    final filtered = scored
        .where(
          (entry) => entry.item.genres.any(
            (genre) => genre.toLowerCase() == targetGenre,
          ),
        )
        .map((entry) => entry.item)
        .toList();

    if (filtered.length >= 8) return filtered.take(10).toList();

    return scored.map((e) => e.item).take(10).toList();
  }

  String _genreLine(OnboardingMediaItem item) {
    if (item.genres.isNotEmpty) {
      return item.genres.take(3).join(' • ');
    }

    if (item.tags.isNotEmpty) {
      return item.tags.take(3).join(' • ');
    }

    return _domainLabel(item.domain);
  }

  String _domainLabel(String domain) {
    switch (domain) {
      case 'movies':
        return 'Movie';
      case 'shows':
        return 'TV Show';
      case 'books':
        return 'Book';
      case 'games':
        return 'Game';
      default:
        return domain;
    }
  }

  IconData _domainIcon(String domain) {
    switch (domain) {
      case 'movies':
        return Icons.local_movies_outlined;
      case 'shows':
        return Icons.tv_outlined;
      case 'books':
        return Icons.menu_book_outlined;
      case 'games':
        return Icons.sports_esports_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Color _domainColor(String domain) {
    switch (domain) {
      case 'movies':
        return const Color(0xFFA78BFA);
      case 'shows':
        return const Color(0xFF60A5FA);
      case 'books':
        return const Color(0xFFF59E0B);
      case 'games':
        return const Color(0xFF34D399);
      default:
        return Colors.white70;
    }
  }

  void _openItemDetails(OnboardingMediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailsScreen(item: item),
      ),
    );
  }

  void _openSeeAll(String title, List<OnboardingMediaItem> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscoverResultsScreen(
          title: title,
          items: items,
        ),
      ),
    );
  }

  void _openAiPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AI Panel',
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) {
        return const Align(
          alignment: Alignment.centerRight,
          child: AiRecommendationPanel(),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _nextHero() {
    if (_popularItems.isEmpty) return;

    final next = (_heroIndex + 1) % _popularItems.length;

    _heroController.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousHero() {
    if (_popularItems.isEmpty) return;

    final previous =
        (_heroIndex - 1 + _popularItems.length) % _popularItems.length;

    _heroController.animateToPage(
      previous,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final becauseTitle = _topGenres.isEmpty
        ? 'Because you like these'
        : 'Because you like ${_topGenres.first}';

    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xFF050507),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadHomeFeed,
              color: Colors.white,
              backgroundColor: const Color(0xFF111111),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  if (_loading)
                    const _HeroLoadingBackdrop()
                  else if (_popularItems.isNotEmpty)
                    _HeroCarousel(
                      items: _popularItems,
                      heroIndex: _heroIndex,
                      controller: _heroController,
                      onPrevious: _previousHero,
                      onNext: _nextHero,
                      onChanged: (index) {
                        setState(() => _heroIndex = index);
                      },
                      onOpenItem: _openItemDetails,
                      domainColor: _domainColor,
                      domainIcon: _domainIcon,
                      domainLabel: _domainLabel,
                      genreLine: _genreLine,
                    )
                  else
                    const SizedBox(height: 120),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _HomeLoadingState(),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ErrorCard(
                        message: _error!,
                        onRetry: _loadHomeFeed,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _SectionTitle(
                            title: 'Discover',
                            actionLabel: 'See all',
                            onTap: () => _openSeeAll(
                              'Discover',
                              _discoverItems,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _PosterRow(
                            items: _discoverItems,
                            domainColor: _domainColor,
                            domainIcon: _domainIcon,
                            domainLabel: _domainLabel,
                            onOpenItem: _openItemDetails,
                          ),
                          const SizedBox(height: 30),
                          _SectionTitle(
                            title: becauseTitle,
                            actionLabel: 'See all',
                            onTap: () => _openSeeAll(
                              becauseTitle,
                              _becauseYouLikedItems,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _PosterRow(
                            items: _becauseYouLikedItems,
                            domainColor: _domainColor,
                            domainIcon: _domainIcon,
                            domainLabel: _domainLabel,
                            onOpenItem: _openItemDetails,
                          ),
                          const SizedBox(height: 30),
                          _SectionTitle(
                            title: 'New from friends',
                            actionLabel: 'See all',
                            onTap: () {},
                          ),
                          const SizedBox(height: 14),
                          _FriendActivityRow(
                            activities: _friendActivities,
                            domainIcon: _domainIcon,
                            domainColor: _domainColor,
                            onOpenItem: _openItemDetails,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _FadedTopNav(scrolled: _navScrolled),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _AiCornerButton(onTap: _openAiPanel),
    );
  }
}
class _DerivedPreferences {
  final List<String> favoriteDomains;
  final List<String> topGenres;
  final List<String> topTags;

  const _DerivedPreferences({
    required this.favoriteDomains,
    required this.topGenres,
    required this.topTags,
  });
}

class _ScoredItem {
  final OnboardingMediaItem item;
  final int score;

  const _ScoredItem({
    required this.item,
    required this.score,
  });
}

class _FriendActivity {
  final String userId;
  final String displayName;
  final String username;
  final String userPhotoUrl;
  final String itemId;
  final String title;
  final String domain;
  final String imageUrl;
  final String source;
  final String type;
  final double rating;
  final String review;
  final DateTime createdAt;

  const _FriendActivity({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.userPhotoUrl,
    required this.itemId,
    required this.title,
    required this.domain,
    required this.imageUrl,
    required this.source,
    required this.type,
    required this.rating,
    required this.review,
    required this.createdAt,
  });

  OnboardingMediaItem toItem() {
    return OnboardingMediaItem(
      id: itemId,
      title: title,
      domain: domain,
      genres: const [],
      tags: const [],
      imageUrl: imageUrl,
      source: source,
      description: review,
    );
  }
}

class _FadedTopNav extends StatelessWidget {
  final bool scrolled;

  const _FadedTopNav({
    required this.scrolled,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: _HomeScreenState._navHeight,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(scrolled ? 0.95 : 0.85),
            Colors.black.withOpacity(scrolled ? 0.75 : 0.55),
            Colors.black.withOpacity(scrolled ? 0.35 : 0.20),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.75, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Text(
              'Encore',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.8,
              ),
            ),
            const Spacer(),
            const _NavItem(label: 'Home', active: true),
            const SizedBox(width: 24),
            _NavItem(
              label: 'Discover',
              onTap: () => Navigator.pushReplacementNamed(context, '/discover'),
            ),
            const SizedBox(width: 24),
            _NavItem(
              label: 'Profile',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? Colors.white
        : _hovered
            ? Colors.white
            : Colors.white.withOpacity(0.70);

    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 140),
          style: GoogleFonts.inter(
            color: color,
            fontSize: 14.5,
            fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  final List<OnboardingMediaItem> items;
  final int heroIndex;
  final PageController controller;
  final ValueChanged<int> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<OnboardingMediaItem> onOpenItem;
  final Color Function(String) domainColor;
  final IconData Function(String) domainIcon;
  final String Function(String) domainLabel;
  final String Function(OnboardingMediaItem) genreLine;

  const _HeroCarousel({
    required this.items,
    required this.heroIndex,
    required this.controller,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenItem,
    required this.domainColor,
    required this.domainIcon,
    required this.domainLabel,
    required this.genreLine,
  });

  @override
  Widget build(BuildContext context) {
    final item = items[heroIndex];
    final color = domainColor(item.domain);

    return SizedBox(
      height: _HomeScreenState._heroHeight,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onOpenItem(items[heroIndex]),
            child: PageView.builder(
              physics: const NeverScrollableScrollPhysics(),
              controller: controller,
              itemCount: items.length,
              onPageChanged: onChanged,
              itemBuilder: (context, index) {
                final current = items[index];

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (current.imageUrl.trim().isNotEmpty)
                      Image.network(
                        current.imageUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: const Color(0xFF111114),
                          );
                        },
                      )
                    else
                      Container(
                        color: const Color(0xFF111114),
                      ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.88),
                              Colors.black.withOpacity(0.34),
                              Colors.black.withOpacity(0.42),
                              Colors.black.withOpacity(0.96),
                            ],
                            stops: const [0.0, 0.22, 0.58, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 70,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onOpenItem(item),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'POPULAR',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: color.withOpacity(0.48),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                domainIcon(item.domain),
                                color: color,
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                domainLabel(item.domain).toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: color,
                                  fontSize: 10.8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.3,
                        height: 0.98,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      genreLine(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 14.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.description.trim().isEmpty
                          ? 'A standout title from the current popular feed.'
                          : item.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.86),
                        fontSize: 14.6,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
                    Positioned(
            left: 18,
            top: 0,
            bottom: 0,
            child: Center(
              child: _HeroArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPrevious,
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 0,
            bottom: 0,
            child: Center(
              child: _HeroArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNext,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (index) {
                final active = index == heroIndex;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        active ? Colors.white : Colors.white.withOpacity(0.32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HeroArrowButton> createState() => _HeroArrowButtonState();
}

class _HeroArrowButtonState extends State<_HeroArrowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(_hovered ? 0.48 : 0.28),
        ),
        child: IconButton(
          onPressed: widget.onTap,
          icon: Icon(
            widget.icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onTap;

  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final action = Text(
      actionLabel,
      style: GoogleFonts.inter(
        color: const Color(0xFFFF8B3D),
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
        ),
        onTap == null
            ? action
            : GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: action,
                ),
              ),
      ],
    );
  }
}

class _PosterRow extends StatelessWidget {
  final List<OnboardingMediaItem> items;
  final Color Function(String) domainColor;
  final IconData Function(String) domainIcon;
  final String Function(String) domainLabel;
  final ValueChanged<OnboardingMediaItem> onOpenItem;

  const _PosterRow({
    required this.items,
    required this.domainColor,
    required this.domainIcon,
    required this.domainLabel,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _HomeScreenState._rowHeight,
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return _PosterCard(
            item: items[index],
            domainIcon: domainIcon,
            domainLabel: domainLabel,
            onOpenItem: onOpenItem,
          );
        },
      ),
    );
  }
}

class _PosterCard extends StatefulWidget {
  final OnboardingMediaItem item;
  final IconData Function(String) domainIcon;
  final String Function(String) domainLabel;
  final ValueChanged<OnboardingMediaItem> onOpenItem;

  const _PosterCard({
    required this.item,
    required this.domainIcon,
    required this.domainLabel,
    required this.onOpenItem,
  });

  @override
  State<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<_PosterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onOpenItem(widget.item),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0,
            end: _hovered ? -6 : 0,
          ),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, offset, child) {
            return Transform.translate(
              offset: Offset(0, offset),
              child: child,
            );
          },
          child: SizedBox(
            width: _HomeScreenState._cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.item.imageUrl.trim().isNotEmpty)
                          Image.network(
                            widget.item.imageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: Colors.white.withOpacity(0.05),
                              );
                            },
                          )
                        else
                          Container(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.08),
                                  Colors.black.withOpacity(0.66),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.34),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.domainIcon(widget.item.domain),
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.item.genres.isNotEmpty
                      ? widget.item.genres.take(2).join(' · ')
                      : widget.domainLabel(widget.item.domain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12.7,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _FriendActivityRow extends StatelessWidget {
  final List<_FriendActivity> activities;
  final IconData Function(String) domainIcon;
  final Color Function(String) domainColor;
  final ValueChanged<OnboardingMediaItem> onOpenItem;

  const _FriendActivityRow({
    required this.activities,
    required this.domainIcon,
    required this.domainColor,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        height: 150,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          'No new activity from people you follow this week.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.50),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      height: _HomeScreenState._rowHeight,
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        scrollDirection: Axis.horizontal,
        itemCount: activities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return _FriendActivityCard(
            activity: activities[index],
            domainIcon: domainIcon,
            domainColor: domainColor,
            onOpenItem: onOpenItem,
          );
        },
      ),
    );
  }
}

class _FriendActivityCard extends StatefulWidget {
  final _FriendActivity activity;
  final IconData Function(String) domainIcon;
  final Color Function(String) domainColor;
  final ValueChanged<OnboardingMediaItem> onOpenItem;

  const _FriendActivityCard({
    required this.activity,
    required this.domainIcon,
    required this.domainColor,
    required this.onOpenItem,
  });

  @override
  State<_FriendActivityCard> createState() => _FriendActivityCardState();
}

class _FriendActivityCardState extends State<_FriendActivityCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final color = widget.domainColor(a.domain);

    final icon = a.type == 'reviewed'
        ? Icons.rate_review_rounded
        : a.type == 'rated'
            ? Icons.star_rounded
            : a.type == 'favorited'
                ? Icons.favorite_rounded
                : Icons.bookmark_rounded;

    final rating = a.rating > 0 ? a.rating : 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onOpenItem(a.toItem()),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _hovered ? -6 : 0),
          duration: const Duration(milliseconds: 180),
          builder: (_, offset, child) {
            return Transform.translate(offset: Offset(0, offset), child: child);
          },
          child: SizedBox(
            width: _HomeScreenState._cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        a.imageUrl.isNotEmpty
                            ? Image.network(a.imageUrl, fit: BoxFit.cover)
                            : _fallbackPoster(a.domain),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                if (rating > 0)
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < rating.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 14,
                        color: const Color(0xFFFFC46B),
                      );
                    }),
                  ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundImage: a.userPhotoUrl.isNotEmpty
                          ? NetworkImage(a.userPhotoUrl)
                          : null,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      child: a.userPhotoUrl.isEmpty
                          ? Text(
                              a.displayName.isNotEmpty
                                  ? a.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(fontSize: 9),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.username.isNotEmpty
                            ? '@${a.username}'
                            : a.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackPoster(String domain) {
    return Container(
      color: Colors.white.withOpacity(0.05),
      child: Center(
        child: Icon(widget.domainIcon(domain), color: Colors.white54),
      ),
    );
  }
}

class _HeroLoadingBackdrop extends StatelessWidget {
  const _HeroLoadingBackdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _HomeScreenState._heroHeight,
      child: Container(
        color: const Color(0xFF111114),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFA362),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your feed...',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.60),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _shimmerBox(width: double.infinity, height: 32),
        const SizedBox(height: 14),
        _shimmerBox(width: 120, height: 20),
        const SizedBox(height: 14),
        SizedBox(
          height: _HomeScreenState._rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, __) => _shimmerBox(
              width: _HomeScreenState._cardWidth,
              height: _HomeScreenState._rowHeight,
            ),
          ),
        ),
        const SizedBox(height: 30),
        _shimmerBox(width: double.infinity, height: 32),
        const SizedBox(height: 14),
        _shimmerBox(width: 120, height: 20),
        const SizedBox(height: 14),
        SizedBox(
          height: _HomeScreenState._rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, __) => _shimmerBox(
              width: _HomeScreenState._cardWidth,
              height: _HomeScreenState._rowHeight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        border: Border.all(
          color: Colors.red.withOpacity(0.24),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red.withOpacity(0.70),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unable to load feed',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.70),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA362),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiCornerButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AiCornerButton({
    required this.onTap,
  });

  @override
  State<_AiCornerButton> createState() => _AiCornerButtonState();
}

class _AiCornerButtonState extends State<_AiCornerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.72),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFFFA362).withOpacity(0.45)
                  : Colors.white.withOpacity(0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFFFA362),
            size: 24,
          ),
        ),
      ),
    );
  }
}