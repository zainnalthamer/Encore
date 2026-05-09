import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/media_seed_service.dart';
import '../../../core/services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final MediaSeedService _mediaSeedService = MediaSeedService();
  final OnboardingService _onboardingService = OnboardingService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String _selectedDomain = 'all';

  List<OnboardingMediaItem> _allItems = [];
  List<OnboardingMediaItem> _visibleItems = [];
  final List<OnboardingMediaItem> _selectedItems = [];

  final List<String> _domains = const [
    'all',
    'movies',
    'shows',
    'books',
    'games',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);

    try {
      final items = await _mediaSeedService.getMixedPopularFeed(limit: 80);

      if (!mounted) return;

      setState(() {
        _allItems = items;
        _visibleItems = items;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to load items: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _visibleItems = _allItems.where((item) {
        final matchesDomain =
            _selectedDomain == 'all' || item.domain == _selectedDomain;

        final title = item.title.toLowerCase();
        final domain = item.domain.toLowerCase();
        final genres = item.genres.join(' ').toLowerCase();
        final tags = item.tags.join(' ').toLowerCase();

        final matchesSearch = query.isEmpty ||
            title.contains(query) ||
            domain.contains(query) ||
            genres.contains(query) ||
            tags.contains(query);

        return matchesDomain && matchesSearch;
      }).toList();
    });
  }

  void _toggleSelection(OnboardingMediaItem item) {
    setState(() {
      final exists = _selectedItems.any((i) => i.id == item.id);
      if (exists) {
        _selectedItems.removeWhere((i) => i.id == item.id);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  bool _isSelected(OnboardingMediaItem item) {
    return _selectedItems.any((i) => i.id == item.id);
  }

  Future<void> _continue() async {
    if (_selectedItems.length < 5) {
      _showSnack('Please select at least 5 items.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      await _onboardingService.saveInitialPreferences(
        uid: uid,
        selectedItems: _selectedItems,
      );

      if (!mounted) return;

      _showSnack('Preferences saved');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save preferences: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF18181B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Color _domainColor(String domain) {
    switch (domain) {
      case 'movies':
        return const Color(0xFFFF6B6B);
      case 'shows':
        return const Color(0xFF7C3AED);
      case 'books':
        return const Color(0xFFF59E0B);
      case 'games':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFFFF8B3D);
    }
  }

  IconData _domainIcon(String domain) {
    switch (domain) {
      case 'movies':
        return Icons.local_movies_rounded;
      case 'shows':
        return Icons.tv_rounded;
      case 'books':
        return Icons.auto_stories_rounded;
      case 'games':
        return Icons.sports_esports_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }

  String _domainLabel(String domain) {
    switch (domain) {
      case 'all':
        return 'All';
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

  int _gridCount(double width) {
    if (width >= 1500) return 7;
    if (width >= 1250) return 6;
    if (width >= 1000) return 5;
    if (width >= 760) return 4;
    if (width >= 520) return 3;
    return 2;
  }

  OnboardingMediaItem? get _heroItem {
    if (_selectedItems.isNotEmpty) return _selectedItems.last;
    if (_allItems.isNotEmpty) return _allItems.first;
    return null;
  }

  double get _progress {
    final value = _selectedItems.length / 5;
    if (value > 1) return 1;
    return value;
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = _gridCount(width);
    final hero = _heroItem;

    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Stack(
        children: [
          Positioned.fill(
            child: _BackgroundAtmosphere(hero: hero),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopBar(onRefresh: _loading ? null : _loadFeed),
                        const SizedBox(height: 22),
                        Text(
                          'Pick what you already like',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select at least 5 items to shape your initial Encore profile.',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.58),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SearchPanel(
                          controller: _searchController,
                          selectedDomain: _selectedDomain,
                          domains: _domains,
                          domainLabel: _domainLabel,
                          domainIcon: _domainIcon,
                          domainColor: _domainColor,
                          onDomainChanged: (domain) {
                            setState(() => _selectedDomain = domain);
                            _applyFilters();
                          },
                        ),
                        const SizedBox(height: 18),
                        _FeedMetaRow(
                          visibleCount: _visibleItems.length,
                          selectedCount: _selectedItems.length,
                          selectedDomain: _domainLabel(_selectedDomain),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _LoadingState(),
                  )
                else if (_visibleItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      onClear: () {
                        _searchController.clear();
                        setState(() => _selectedDomain = 'all');
                        _applyFilters();
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _visibleItems[index];

                          return _MediaChoiceCard(
                            item: item,
                            selected: _isSelected(item),
                            domainColor: _domainColor(item.domain),
                            domainIcon: _domainIcon(item.domain),
                            domainLabel: _domainLabel(item.domain),
                            onTap: () => _toggleSelection(item),
                          );
                        },
                        childCount: _visibleItems.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.64,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomActionBar(
              selectedCount: _selectedItems.length,
              progress: _progress,
              saving: _saving,
              onContinue: _saving ? null : _continue,
            ),
          ),
        ],
      ),
    );
  }
}
class _BackgroundAtmosphere extends StatelessWidget {
  final OnboardingMediaItem? hero;

  const _BackgroundAtmosphere({required this.hero});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (hero != null && hero!.imageUrl.isNotEmpty)
          Positioned.fill(
            child: Image.network(
              hero!.imageUrl,
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.18),
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.75, -0.7),
                radius: 1.2,
                colors: [
                  Color(0x443B82F6),
                  Color(0x22050507),
                  Color(0xFF050507),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xAA050507),
                  Color(0xF2050507),
                  Color(0xFF050507),
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
  final VoidCallback? onRefresh;

  const _TopBar({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Encore',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onRefresh,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
          ),
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final String selectedDomain;
  final List<String> domains;
  final String Function(String domain) domainLabel;
  final IconData Function(String domain) domainIcon;
  final Color Function(String domain) domainColor;
  final ValueChanged<String> onDomainChanged;

  const _SearchPanel({
    required this.controller,
    required this.selectedDomain,
    required this.domains,
    required this.domainLabel,
    required this.domainIcon,
    required this.domainColor,
    required this.onDomainChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.075),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D10).withOpacity(0.86),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: const Color(0xFFFF8B3D),
                  decoration: InputDecoration(
                    hintText: 'Search by title, genre, domain...',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.white.withOpacity(0.65),
                      size: 21,
                    ),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: controller.clear,
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.white.withOpacity(0.55),
                              size: 18,
                            ),
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: domains.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final domain = domains[index];
                    final active = selectedDomain == domain;
                    final color = domainColor(domain);

                    return GestureDetector(
                      onTap: () => onDomainChanged(domain),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: active
                              ? color.withOpacity(domain == 'all' ? 0.95 : 0.22)
                              : Colors.white.withOpacity(0.065),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? color.withOpacity(0.72)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              domainIcon(domain),
                              color: active && domain == 'all'
                                  ? Colors.black
                                  : active
                                      ? color
                                      : Colors.white.withOpacity(0.62),
                              size: 16,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              domainLabel(domain),
                              style: GoogleFonts.inter(
                                color: active && domain == 'all'
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 12.5,
                                fontWeight:
                                    active ? FontWeight.w800 : FontWeight.w600,
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
          ),
        ),
      ),
    );
  }
}
class _FeedMetaRow extends StatelessWidget {
  final int visibleCount;
  final int selectedCount;
  final String selectedDomain;

  const _FeedMetaRow({
    required this.visibleCount,
    required this.selectedCount,
    required this.selectedDomain,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$visibleCount picks',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'in $selectedDomain',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.46),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.075),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Text(
            '$selectedCount selected',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaChoiceCard extends StatelessWidget {
  final OnboardingMediaItem item;
  final bool selected;
  final Color domainColor;
  final IconData domainIcon;
  final String domainLabel;
  final VoidCallback onTap;

  const _MediaChoiceCard({
    required this.item,
    required this.selected,
    required this.domainColor,
    required this.domainIcon,
    required this.domainLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim().isEmpty ? 'Untitled' : item.title.trim();
    final genres = item.genres.take(2).join(' • ');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 0.965 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: selected
                  ? domainColor.withOpacity(0.95)
                  : Colors.white.withOpacity(0.08),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: domainColor.withOpacity(0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ImageFallback(
                          icon: domainIcon,
                        ),
                      )
                    : _ImageFallback(icon: domainIcon),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.02),
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.72),
                          Colors.black.withOpacity(0.96),
                        ],
                        stops: const [0, 0.36, 0.74, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _CardBadge(
                    icon: domainIcon,
                    label: domainLabel,
                    color: domainColor,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white
                          : Colors.black.withOpacity(0.34),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? Colors.white
                            : Colors.white.withOpacity(0.20),
                      ),
                    ),
                    child: Icon(
                      selected ? Icons.check_rounded : Icons.add_rounded,
                      color: selected ? Colors.black : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (genres.isNotEmpty) ...[
                        Text(
                          genres.toLowerCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.52),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                          height: 1.15,
                        ),
                      ),
                    ],
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
class _CardBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CardBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.36),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final IconData icon;

  const _ImageFallback({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF151519),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withOpacity(0.32),
          size: 34,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.075),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFFFF8B3D),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Curating your starter universe...',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Movies, shows, books, and games are being mixed.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.52),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;

  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.065),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Colors.white.withOpacity(0.72),
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              'No matches found',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Try another title, genre, or switch back to all domains.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.52),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onClear,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'Clear filters',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final int selectedCount;
  final double progress;
  final bool saving;
  final VoidCallback? onContinue;

  const _BottomActionBar({
    required this.selectedCount,
    required this.progress,
    required this.saving,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final ready = selectedCount >= 5;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF09090B).withOpacity(0.82),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ready
                            ? 'Your first taste profile is ready'
                            : 'Select ${5 - selectedCount} more to continue',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: Colors.white.withOpacity(0.10),
                          color: const Color(0xFFFF8B3D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          ready ? const Color(0xFFFF8B3D) : Colors.white10,
                      foregroundColor: ready ? Colors.black : Colors.white54,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ready ? 'Continue' : '$selectedCount/5',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (ready) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
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