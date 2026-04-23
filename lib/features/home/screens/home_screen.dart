
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/media_seed_service.dart';
import '../../ai/widgets/ai_recommendation_panel.dart';
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

  static const double _heroHeight = 560;
  static const double _navHeight = 92;

  final List<OnboardingMediaItem> _friendPlaceholders = const [
    OnboardingMediaItem(
      id: 'friend_placeholder_1',
      title: 'Friends activity coming soon',
      domain: 'shows',
      genres: ['Social'],
      tags: ['Placeholder'],
      imageUrl: '',
      source: 'local',
      description: 'This section will show what your friends recently added.',
    ),
    OnboardingMediaItem(
      id: 'friend_placeholder_2',
      title: 'Shared shelves will appear here',
      domain: 'books',
      genres: ['Community'],
      tags: ['Placeholder'],
      imageUrl: '',
      source: 'local',
      description: 'Shared shelves and notes will appear here later.',
    ),
    OnboardingMediaItem(
      id: 'friend_placeholder_3',
      title: 'Recent entries from friends',
      domain: 'movies',
      genres: ['Placeholder'],
      tags: ['Placeholder'],
      imageUrl: '',
      source: 'local',
      description: 'You will be able to see recent friend activity here.',
    ),
    OnboardingMediaItem(
      id: 'friend_placeholder_4',
      title: 'Reactions and likes later',
      domain: 'games',
      genres: ['Placeholder'],
      tags: ['Placeholder'],
      imageUrl: '',
      source: 'local',
      description: 'Likes, reactions, and activity updates will go here.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadHomeFeed();
  }

  void _handleScroll() {
    final scrolled = _scrollController.hasClients && _scrollController.offset > 24;
    if (scrolled != _navScrolled) {
      setState(() {
        _navScrolled = scrolled;
      });
    }
  }

  Future<void> _loadHomeFeed() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preferences = await _loadUserPreferences();
      final fetchedItems = await _mediaSeedService.getMixedPopularFeed(limit: 72);

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

      if (!mounted) return;

      setState(() {
        _topGenres = topGenres;
        _popularItems = popular;
        _discoverItems = discover;
        _becauseYouLikedItems = becauseYouLiked;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
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

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data() ?? {};
    final derived = (data['derivedPreferences'] as Map<String, dynamic>?) ?? {};

    return _DerivedPreferences(
      favoriteDomains: (derived['favoriteDomains'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      topGenres:
          (derived['topGenres'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      topTags:
          (derived['topTags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
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
        .where((entry) => entry.item.genres.any(
              (genre) => genre.toLowerCase() == targetGenre,
            ))
        .map((entry) => entry.item)
        .toList();

    if (filtered.length >= 8) return filtered.take(10).toList();
    return scored.map((e) => e.item).take(10).toList();
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
    final previous = (_heroIndex - 1 + _popularItems.length) % _popularItems.length;
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
                        setState(() {
                          _heroIndex = index;
                        });
                      },
                      domainColor: _domainColor,
                      domainIcon: _domainIcon,
                      domainLabel: _domainLabel,
                    ),
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
                          const _SectionTitle(
                            title: 'Discover',
                            actionLabel: 'See all',
                          ),
                          const SizedBox(height: 14),
                          _PosterRow(
                            items: _discoverItems,
                            domainColor: _domainColor,
                            domainIcon: _domainIcon,
                            domainLabel: _domainLabel,
                          ),
                          const SizedBox(height: 30),
                          _SectionTitle(
                            title: becauseTitle,
                            actionLabel: 'See all',
                          ),
                          const SizedBox(height: 14),
                          _PosterRow(
                            items: _becauseYouLikedItems,
                            domainColor: _domainColor,
                            domainIcon: _domainIcon,
                            domainLabel: _domainLabel,
                          ),
                          const SizedBox(height: 30),
                          const _SectionTitle(
                            title: 'New from friends',
                            actionLabel: 'See all',
                          ),
                          const SizedBox(height: 14),
                          _FriendsPlaceholderRow(
                            items: _friendPlaceholders,
                            domainIcon: _domainIcon,
                            domainColor: _domainColor,
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
            child: _FadedTopNav(
              scrolled: _navScrolled,
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _AiCornerButton(
        onTap: _openAiPanel,
      ),
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

class _FadedTopNav extends StatelessWidget {
  final bool scrolled;

  const _FadedTopNav({
    required this.scrolled,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: AnimatedContainer(
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
              Colors.transparent, // IMPORTANT: full transparent at bottom
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
              const _NavItem(label: 'Discover'),
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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
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
  final Color Function(String) domainColor;
  final IconData Function(String) domainIcon;
  final String Function(String) domainLabel;

  const _HeroCarousel({
    required this.items,
    required this.heroIndex,
    required this.controller,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.domainColor,
    required this.domainIcon,
    required this.domainLabel,
  });

  @override
  Widget build(BuildContext context) {
    final item = items[heroIndex];
    final color = domainColor(item.domain);

    return SizedBox(
      height: _HomeScreenState._heroHeight,
      child: Stack(
        children: [
          PageView.builder(
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
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF111114),
                      ),
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
          Positioned(
            left: 28,
            right: 28,
            bottom: 70,
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
                    item.genres.isEmpty
                        ? 'Genres: Curated'
                        : 'Genres: ${item.genres.take(3).join(', ')}',
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
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.86),
                      fontSize: 14.6,
                      height: 1.6,
                    ),
                  ),
                ],
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
                    color: active
                        ? Colors.white
                        : Colors.white.withOpacity(0.32),
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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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

  const _SectionTitle({
    required this.title,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
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
        Text(
          actionLabel,
          style: GoogleFonts.inter(
            color: const Color(0xFFFF8B3D),
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
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

  const _PosterRow({
    required this.items,
    required this.domainColor,
    required this.domainIcon,
    required this.domainLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 336,
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return _PosterCard(
            item: items[index],
            domainColor: domainColor,
            domainIcon: domainIcon,
            domainLabel: domainLabel,
          );
        },
      ),
    );
  }
}

class _PosterCard extends StatefulWidget {
  final OnboardingMediaItem item;
  final Color Function(String) domainColor;
  final IconData Function(String) domainIcon;
  final String Function(String) domainLabel;

  const _PosterCard({
    required this.item,
    required this.domainColor,
    required this.domainIcon,
    required this.domainLabel,
  });

  @override
  State<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<_PosterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _hovered ? -6 : 0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, offset, child) {
          return Transform.translate(
            offset: Offset(0, offset),
            child: child,
          );
        },
        child: SizedBox(
          width: 196,
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
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white.withOpacity(0.05),
                          ),
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
              const SizedBox(height: 10),
              Text(
                widget.item.title,
                maxLines: 3,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.22,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.item.genres.isNotEmpty
                    ? widget.item.genres.take(2).join(' · ')
                    : widget.domainLabel(widget.item.domain),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.60),
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsPlaceholderRow extends StatelessWidget {
  final List<OnboardingMediaItem> items;
  final IconData Function(String) domainIcon;
  final Color Function(String) domainColor;

  const _FriendsPlaceholderRow({
    required this.items,
    required this.domainIcon,
    required this.domainColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          final color = domainColor(item.domain);

          return Container(
            width: 220,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.34),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    domainIcon(item.domain),
                    color: color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
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
          height: 336,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, __) => _shimmerBox(width: 196, height: 336),
          ),
        ),
        const SizedBox(height: 30),
        _shimmerBox(width: double.infinity, height: 32),
        const SizedBox(height: 14),
        _shimmerBox(width: 120, height: 20),
        const SizedBox(height: 14),
        SizedBox(
          height: 336,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, __) => _shimmerBox(width: 196, height: 336),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox({required double width, required double height}) {
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
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
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