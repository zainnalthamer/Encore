import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/media_seed_service.dart';
import '../../ai/widgets/ai_recommendation_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MediaSeedService _mediaSeedService = MediaSeedService();
  final PageController _heroController = PageController();

  bool _loading = true;
  String? _error;
  int _heroIndex = 0;

  List<String> _topGenres = [];
  List<String> _topTags = [];
  List<String> _favoriteDomains = [];

  List<OnboardingMediaItem> _popularItems = [];
  List<OnboardingMediaItem> _discoverItems = [];
  List<OnboardingMediaItem> _becauseYouLikedItems = [];

  @override
  void initState() {
    super.initState();
    _loadHomeFeed();
  }

  bool get _isDesktopLike => MediaQuery.sizeOf(context).width >= 980;

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
        _favoriteDomains = favoriteDomains;
        _topGenres = topGenres;
        _topTags = topTags;
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
    final seen = <String>{};
    final popular = <OnboardingMediaItem>[];

    for (final item in items) {
      if (seen.contains(item.id)) continue;
      if (item.imageUrl.trim().isEmpty) continue;
      if (item.description.trim().isEmpty) continue;

      seen.add(item.id);
      popular.add(item);

      if (popular.length >= 6) break;
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
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktopLike = _isDesktopLike;
    final becauseTitle = _topGenres.isEmpty
        ? 'Because you like these'
        : 'Because you like ${_topGenres.first}';

    return Scaffold(
      backgroundColor: const Color(0xFF060608),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xFF060608),
            ),
          ),
          Positioned(
            top: -120,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF8B3D).withOpacity(0.10),
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadHomeFeed,
              color: Colors.white,
              backgroundColor: const Color(0xFF111111),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  desktopLike ? 34 : 20,
                  desktopLike ? 18 : 18,
                  desktopLike ? 34 : 20,
                  110,
                ),
                children: [
                  _FadedTopNav(),
                  const SizedBox(height: 20),
                  if (_loading)
                    const _HomeLoadingState()
                  else if (_error != null)
                    _ErrorCard(
                      message: _error!,
                      onRetry: _loadHomeFeed,
                    )
                  else ...[
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
                    const SizedBox(height: 28),
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
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _AiPillButton(
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
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.03),
              ],
            ),
          ),
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
              const _NavItem(label: 'Library'),
              const SizedBox(width: 24),
              const _NavItem(label: 'Profile'),
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

  const _NavItem({
    required this.label,
    this.active = false,
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
            : Colors.white.withOpacity(0.68);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 160),
        style: GoogleFonts.inter(
          color: color,
          fontSize: 14.5,
          fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
        ),
        child: Text(widget.label),
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
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 470,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (_) => true,
            child: PageView.builder(
              physics: const NeverScrollableScrollPhysics(),
              controller: controller,
              itemCount: items.length,
              onPageChanged: onChanged,
              itemBuilder: (context, index) {
                final item = items[index];
                final color = domainColor(item.domain);

                return ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.imageUrl.trim().isNotEmpty)
                        Image.network(
                          item.imageUrl,
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
                                Colors.black.withOpacity(0.72),
                                Colors.black.withOpacity(0.18),
                                Colors.black.withOpacity(0.45),
                                Colors.black.withOpacity(0.92),
                              ],
                              stops: const [0.0, 0.22, 0.58, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 22,
                        left: 22,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
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
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: color.withOpacity(0.50),
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
                      ),
                      Positioned(
                        left: 26,
                        right: 26,
                        bottom: 52,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 38,
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
                                  fontSize: 14,
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
                                  fontSize: 14.5,
                                  height: 1.58,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 16,
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
            right: 16,
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
            bottom: 18,
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
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(_hovered ? 0.48 : 0.30),
          border: Border.all(
            color: Colors.white.withOpacity(_hovered ? 0.18 : 0.08),
          ),
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
      height: 320,
      child: ListView.separated(
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
    final accent = widget.domainColor(widget.item.domain);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 196,
        transform: Matrix4.identity()..translate(0.0, _hovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
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
                          color: accent,
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
              overflow: TextOverflow.visible,
              softWrap: true,
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
    );
  }
}

class _AiPillButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AiPillButton({
    required this.onTap,
  });

  @override
  State<_AiPillButton> createState() => _AiPillButtonState();
}

class _AiPillButtonState extends State<_AiPillButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF171720).withOpacity(0.96),
                const Color(0xFF101017).withOpacity(0.96),
              ],
            ),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFFF9B57).withOpacity(0.42)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8B3D).withOpacity(
                  _hovered ? 0.24 : 0.14,
                ),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFBC81),
                      Color(0xFFFF8B3D),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.black,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ask Encore AI',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
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
      children: [
        Container(
          height: 470,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        const SizedBox(height: 28),
        ...List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 220,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 320,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, __) {
                      return Container(
                        width: 196,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      );
                    },
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF3A0F18).withOpacity(0.55),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFFB7C5),
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}