import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/discover_api_service.dart';
import '../../../core/services/social_service.dart';
import '../../items/screens/item_details_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'discover_results_screen.dart';

const Color kDiscoverBg = Color(0xFF050507);
const Color kDiscoverAccent = Color(0xFFFF8B3D);

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final DiscoverApiService _service = DiscoverApiService();
  final SocialService _socialService = SocialService();
  final TextEditingController _searchController = TextEditingController();

  late Future<DiscoverData> _future;

  Timer? _debounce;
  bool _searching = false;
  String _query = '';
  String _selectedType = 'items';
  String _selectedDomain = 'all';

  List<OnboardingMediaItem> _searchResults = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _userResults = [];

  final List<String> _types = const ['items', 'users', 'shelves'];
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
    _future = _service.loadDiscover();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String value) async {
    final clean = value.trim();

    setState(() => _query = clean);

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (clean.isEmpty) {
        if (!mounted) return;

        setState(() {
          _searching = false;
          _searchResults = [];
          _userResults = [];
        });

        return;
      }

      setState(() => _searching = true);

      if (_selectedType == 'users') {
        final users = await _socialService.searchUsers(clean);

        if (!mounted) return;

        setState(() {
          _userResults = users;
          _searchResults = [];
          _searching = false;
        });

        return;
      }

      if (_selectedType == 'shelves') {
        if (!mounted) return;

        setState(() {
          _searching = false;
          _searchResults = [];
          _userResults = [];
        });

        return;
      }

      final results = await _service.searchAll(clean);

      if (!mounted) return;

      setState(() {
        _searchResults = _selectedDomain == 'all'
            ? results
            : results.where((item) => item.domain == _selectedDomain).toList();
        _userResults = [];
        _searching = false;
      });
    });
  }

  void _openResults(String title, List<OnboardingMediaItem> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiscoverResultsScreen(
          title: title,
          items: items,
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
              decoration: const BoxDecoration(
                color: Color(0xFF101014),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Filter',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FilterGroup(
                      title: 'Type',
                      options: _types,
                      selected: _selectedType,
                      label: _typeLabel,
                      onSelected: (value) {
                        modalSetState(() => _selectedType = value);

                        setState(() {
                          _selectedType = value;
                          _searchResults = [];
                          _userResults = [];
                        });

                        if (_query.trim().isNotEmpty) {
                          _runSearch(_query);
                        }
                      },
                    ),
                    const SizedBox(height: 22),
                    _FilterGroup(
                      title: 'Domain',
                      options: _domains,
                      selected: _selectedDomain,
                      label: _domainLabelForFilter,
                      onSelected: (value) {
                        modalSetState(() => _selectedDomain = value);

                        setState(() => _selectedDomain = value);

                        if (_query.trim().isNotEmpty) {
                          _runSearch(_query);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<OnboardingMediaItem> _uniqueMix(List<OnboardingMediaItem> items) {
    final seen = <String>{};
    final output = <OnboardingMediaItem>[];

    for (final item in items) {
      final key = '${item.domain}_${item.title.toLowerCase()}';
      if (seen.contains(key)) continue;
      seen.add(key);
      output.add(item);
    }

    return output;
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'items':
        return 'Items';
      case 'users':
        return 'Users';
      case 'shelves':
        return 'Shelves soon';
      default:
        return type;
    }
  }

  String _domainLabelForFilter(String domain) {
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

  @override
  Widget build(BuildContext context) {
    final hasSearch = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: kDiscoverBg,
      body: Stack(
        children: [
          FutureBuilder<DiscoverData>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 106, 22, 0),
                      child: _SearchHeader(
                        controller: _searchController,
                        selectedType: _selectedType,
                        onChanged: _runSearch,
                        onFilter: _showFilterSheet,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  if (hasSearch)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
                      sliver: _SearchResultsSliver(
                        searching: _searching,
                        query: _query,
                        selectedType: _selectedType,
                        items: _searchResults,
                        users: _userResults,
                      ),
                    )
                  else if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else if (data == null)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'Could not load Discover.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: _FreshPickGrid(
                          featured: _uniqueMix([
                            ...data.popular,
                            ...data.trending,
                            ...data.games,
                            ...data.books,
                          ]).first,
                          sideItems: _uniqueMix([
                            ...data.trending,
                            ...data.games,
                            ...data.books,
                            ...data.highestRated,
                          ]).skip(1).take(2).toList(),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    SliverToBoxAdapter(
                      child: _PosterSection(
                        title: 'Popular now',
                        items: data.popular,
                        onSeeAll: () => _openResults(
                          'Popular now',
                          data.popular,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    SliverToBoxAdapter(
                      child: _VibeSection(
                        data: data,
                        onOpen: _openResults,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    SliverToBoxAdapter(
                      child: _PosterSection(
                        title: 'Trending shows',
                        items: data.trending,
                        onSeeAll: () => _openResults(
                          'Trending shows',
                          data.trending,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    SliverToBoxAdapter(
                      child: _PosterSection(
                        title: 'Highest rated',
                        items: data.highestRated,
                        onSeeAll: () => _openResults(
                          'Highest rated',
                          data.highestRated,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    SliverToBoxAdapter(
                      child: _PosterSection(
                        title: 'Games',
                        items: data.games,
                        onSeeAll: () => _openResults('Games', data.games),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                    SliverToBoxAdapter(
                      child: _PosterSection(
                        title: 'Books',
                        items: data.books,
                        onSeeAll: () => _openResults('Books', data.books),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22),
                        child: _FutureDiscoveryBlock(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ],
              );
            },
          ),
          const _DiscoverTopNav(),
        ],
      ),
    );
  }
}
class _DiscoverTopNav extends StatelessWidget {
  const _DiscoverTopNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.96),
            Colors.black.withOpacity(0.72),
            Colors.transparent,
          ],
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
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.9,
              ),
            ),
            const Spacer(),
            _NavText(label: 'Home', onTap: () => Navigator.pop(context)),
            const SizedBox(width: 24),
            const _NavText(label: 'Discover', active: true),
            const SizedBox(width: 24),
            _NavText(
              label: 'Profile',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavText extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavText({
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: active ? Colors.white : Colors.white.withOpacity(0.62),
          fontSize: 14.5,
          fontWeight: active ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final String selectedType;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;

  const _SearchHeader({
    required this.controller,
    required this.selectedType,
    required this.onChanged,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final hint = selectedType == 'users'
        ? 'Search users by username...'
        : selectedType == 'shelves'
            ? 'Search shelves...'
            : 'Search movies, shows, books, games...';

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.055),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: Colors.white,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withOpacity(0.42),
                ),
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.32),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onFilter,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.065),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchResultsSliver extends StatelessWidget {
  final bool searching;
  final String query;
  final String selectedType;
  final List<OnboardingMediaItem> items;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;

  const _SearchResultsSliver({
    required this.searching,
    required this.query,
    required this.selectedType,
    required this.items,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedType == 'users') {
      if (searching) {
        return const SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }

      if (users.isEmpty) {
        return SliverFillRemaining(
          child: Center(
            child: Text(
              'No users found for "$query"',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.68),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _UserSearchCard(doc: users[index]),
          childCount: users.length,
        ),
      );
    }

    if (selectedType == 'shelves') {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'Shelf discovery is coming soon.',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.68),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    if (searching) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (items.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'No results for "$query"',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.68),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _PosterCard(item: items[index]),
        childCount: items.length,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisExtent: 286,
        mainAxisSpacing: 24,
        crossAxisSpacing: 18,
      ),
    );
  }
}

class _UserSearchCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _UserSearchCard({
    required this.doc,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final name = (data['displayName'] ?? data['name'] ?? 'User').toString();
    final username = (data['username'] ?? '').toString();
    final photoUrl =
        (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString().trim();
    final bio = (data['bio'] ?? '').toString();
    final followers = ((data['followers'] as List?) ?? []).length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: doc.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.045),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.08),
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(
                      name.trim().isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '@$username',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (bio.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.42),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$followers followers',
              style: GoogleFonts.inter(
                color: kDiscoverAccent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreshPickGrid extends StatelessWidget {
  final OnboardingMediaItem featured;
  final List<OnboardingMediaItem> sideItems;

  const _FreshPickGrid({
    required this.featured,
    required this.sideItems,
  });

  @override
  Widget build(BuildContext context) {
    final items = sideItems.take(2).toList();

    return SizedBox(
      height: 322,
      child: Row(
        children: [
          Expanded(flex: 3, child: _FeaturedCard(item: featured)),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Row(
              children: List.generate(items.length, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == items.length - 1 ? 0 : 14,
                    ),
                    child: _SidePosterCard(item: items[index]),
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

class _FeaturedCard extends StatelessWidget {
  final OnboardingMediaItem item;

  const _FeaturedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _image(item.imageUrl);

    return GestureDetector(
      onTap: () => _openItem(context, item),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(34),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => _fallback(item.domain),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.92),
                    Colors.black.withOpacity(0.50),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 26,
              right: 26,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Pill(label: 'Fresh pick'),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    _subtitleForItem(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.66),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidePosterCard extends StatelessWidget {
  final OnboardingMediaItem item;

  const _SidePosterCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _image(item.imageUrl);

    return GestureDetector(
      onTap: () => _openItem(context, item),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => _fallback(item.domain),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 15,
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterSection extends StatelessWidget {
  final String title;
  final List<OnboardingMediaItem> items;
  final VoidCallback onSeeAll;

  const _PosterSection({
    required this.title,
    required this.items,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(
                    'See all',
                    style: GoogleFonts.inter(
                      color: kDiscoverAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 286,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length.clamp(0, 14),
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 156,
                  child: _PosterCard(item: items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final OnboardingMediaItem item;

  const _PosterCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _image(item.imageUrl);

    return GestureDetector(
      onTap: () => _openItem(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 228,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: imageUrl.isEmpty
                  ? _fallback(item.domain)
                  : Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => _fallback(item.domain),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitleForItem(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.42),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeSection extends StatelessWidget {
  final DiscoverData data;
  final void Function(String, List<OnboardingMediaItem>) onOpen;

  const _VibeSection({
    required this.data,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final vibes = [
      _VibeData('Sci-fi mood', Icons.auto_awesome_outlined, data.genrePicks),
      _VibeData('Screen obsessions', Icons.movie_outlined, [
        ...data.popular.take(8),
        ...data.trending.take(8),
      ]),
      _VibeData('Play next', Icons.sports_esports_outlined, data.games),
      _VibeData('Reading queue', Icons.menu_book_outlined, data.books),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discover by vibe',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: vibes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisExtent: 120,
              crossAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final vibe = vibes[index];

              return GestureDetector(
                onTap: () => onOpen(vibe.title, vibe.items),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.055),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(vibe.icon, color: kDiscoverAccent, size: 24),
                      const Spacer(),
                      Text(
                        vibe.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VibeData {
  final String title;
  final IconData icon;
  final List<OnboardingMediaItem> items;

  const _VibeData(this.title, this.icon, this.items);
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kDiscoverAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FutureDiscoveryBlock extends StatelessWidget {
  const _FutureDiscoveryBlock();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _FutureCard(
            title: 'Shelves',
            subtitle: 'Community collections later',
            icon: Icons.collections_bookmark_outlined,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _FutureCard(
            title: 'Public profiles',
            subtitle: 'Find and follow users',
            icon: Icons.people_alt_outlined,
          ),
        ),
      ],
    );
  }
}

class _FutureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _FutureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kDiscoverAccent, size: 25),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _FilterGroup extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;
  final String Function(String) label;
  final ValueChanged<String> onSelected;

  const _FilterGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.50),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final active = selected == option;

            return GestureDetector(
              onTap: () => onSelected(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? kDiscoverAccent
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? kDiscoverAccent
                        : Colors.white.withOpacity(0.07),
                  ),
                ),
                child: Text(
                  label(option),
                  style: GoogleFonts.inter(
                    color: active ? Colors.black : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

String _image(String url) {
  if (url.contains('image.tmdb.org/t/p/w500')) {
    return url.replaceAll('/w500/', '/original/');
  }

  if (url.contains('image.tmdb.org/t/p/w780')) {
    return url.replaceAll('/w780/', '/original/');
  }

  if (url.contains('http://')) {
    return url.replaceAll('http://', 'https://');
  }

  return url;
}

String _domainLabel(String domain) {
  switch (domain) {
    case 'movies':
      return 'Movie';
    case 'shows':
      return 'Show';
    case 'books':
      return 'Book';
    case 'games':
      return 'Game';
    default:
      return domain;
  }
}

String _subtitleForItem(OnboardingMediaItem item) {
  final genres = item.genres;

  if (genres.isEmpty) {
    return _domainLabel(item.domain);
  }

  return genres.take(3).join(' • ');
}

Widget _fallback(String domain) {
  IconData icon;

  switch (domain) {
    case 'movies':
      icon = Icons.local_movies_outlined;
      break;
    case 'shows':
      icon = Icons.tv_outlined;
      break;
    case 'books':
      icon = Icons.menu_book_outlined;
      break;
    case 'games':
      icon = Icons.sports_esports_outlined;
      break;
    default:
      icon = Icons.image_outlined;
  }

  return Container(
    color: Colors.white.withOpacity(0.07),
    child: Center(
      child: Icon(
        icon,
        color: Colors.white54,
        size: 30,
      ),
    ),
  );
}

void _openItem(BuildContext context, OnboardingMediaItem item) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ItemDetailsScreen(item: item),
    ),
  );
}