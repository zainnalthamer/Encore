import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/discover_api_service.dart';
import '../../../core/services/social_service.dart';
import '../../items/screens/item_details_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../profile/screens/shelf_screen.dart';
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
  bool _loadingDirectory = false;

  String _query = '';
  String _selectedType = 'items';
  String _selectedDomain = 'all';

  List<OnboardingMediaItem> _searchResults = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _userResults = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _shelfResults = [];

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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadAllUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .limit(60)
        .get();

    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _searchUsers(
    String query,
  ) async {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return _loadAllUsers();
    }

    final users = await _socialService.searchUsers(q);
    return users;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadAllShelves() async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('shelves')
        .limit(60)
        .get();

    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _searchShelves(
    String query,
  ) async {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      return _loadAllShelves();
    }

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('shelves')
        .orderBy('searchName')
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(60)
        .get();

    return snapshot.docs;
  }

  Future<void> _loadDirectoryForSelectedType() async {
    if (_selectedType != 'users' && _selectedType != 'shelves') return;

    setState(() {
      _loadingDirectory = true;
      _searching = false;
      _searchResults = [];
      _userResults = [];
      _shelfResults = [];
    });

    try {
      if (_selectedType == 'users') {
        final users = await _loadAllUsers();

        if (!mounted) return;

        setState(() {
          _userResults = users;
          _shelfResults = [];
          _searchResults = [];
        });
      } else if (_selectedType == 'shelves') {
        final shelves = await _loadAllShelves();

        if (!mounted) return;

        setState(() {
          _shelfResults = shelves;
          _userResults = [];
          _searchResults = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDirectory = false);
      }
    }
  }

  Future<void> _runSearch(String value) async {
    final clean = value.trim();

    setState(() => _query = clean);

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (_selectedType == 'users') {
        setState(() => _searching = true);

        final users = await _searchUsers(clean);

        if (!mounted) return;

        setState(() {
          _userResults = users;
          _shelfResults = [];
          _searchResults = [];
          _searching = false;
        });

        return;
      }

      if (_selectedType == 'shelves') {
        setState(() => _searching = true);

        final shelves = await _searchShelves(clean);

        if (!mounted) return;

        setState(() {
          _shelfResults = shelves;
          _userResults = [];
          _searchResults = [];
          _searching = false;
        });

        return;
      }

      if (clean.isEmpty) {
        if (!mounted) return;

        setState(() {
          _searching = false;
          _searchResults = [];
          _userResults = [];
          _shelfResults = [];
        });

        return;
      }

      setState(() => _searching = true);

      final results = await _service.searchAll(clean);

      if (!mounted) return;

      setState(() {
        _searchResults = _selectedDomain == 'all'
            ? results
            : results.where((item) => item.domain == _selectedDomain).toList();
        _userResults = [];
        _shelfResults = [];
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
                          _shelfResults = [];
                        });

                        Navigator.pop(context);

                        if (value == 'users' || value == 'shelves') {
                          _loadDirectoryForSelectedType();
                        } else if (_query.trim().isNotEmpty) {
                          _runSearch(_query);
                        }
                      },
                    ),
                    if (_selectedType == 'items') ...[
                      const SizedBox(height: 22),
                      _FilterGroup(
                        title: 'Domain',
                        options: _domains,
                        selected: _selectedDomain,
                        label: _domainLabelForFilter,
                        onSelected: (value) {
                          modalSetState(() => _selectedDomain = value);

                          setState(() => _selectedDomain = value);

                          Navigator.pop(context);

                          if (_query.trim().isNotEmpty) {
                            _runSearch(_query);
                          }
                        },
                      ),
                    ],
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
        return 'Shelves';
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
    final directoryMode = _selectedType == 'users' || _selectedType == 'shelves';

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
                        selectedDomain: _selectedDomain,
                        onChanged: _runSearch,
                        onFilter: _showFilterSheet,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  if (hasSearch || directoryMode)
                    SliverToBoxAdapter(
                      child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
                      child: _SearchResultsBody(
                        searching: _searching || _loadingDirectory,
                        query: _query,
                        selectedType: _selectedType,
                        items: _searchResults,
                        users: _userResults,
                        shelves: _shelfResults,
                      ),
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
  final String selectedDomain;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;

  const _SearchHeader({
    required this.controller,
    required this.selectedType,
    required this.selectedDomain,
    required this.onChanged,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final hint = selectedType == 'users'
        ? 'Search users by username...'
        : selectedType == 'shelves'
            ? 'Search shelves by name...'
            : 'Search movies, shows, books, games...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _SmallFilterPill(
              text: selectedType == 'items'
                  ? 'Items'
                  : selectedType == 'users'
                      ? 'Users'
                      : 'Shelves',
              active: true,
            ),
            if (selectedType == 'items')
              _SmallFilterPill(
                text: selectedDomain == 'all'
                    ? 'All domains'
                    : selectedDomain[0].toUpperCase() +
                        selectedDomain.substring(1),
                active: false,
              ),
          ],
        ),
      ],
    );
  }
}

class _SmallFilterPill extends StatelessWidget {
  final String text;
  final bool active;

  const _SmallFilterPill({
    required this.text,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: active ? kDiscoverAccent : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: active ? Colors.black : Colors.white.withOpacity(0.72),
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SearchResultsBody extends StatelessWidget {
  final bool searching;
  final String query;
  final String selectedType;
  final List<OnboardingMediaItem> items;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> shelves;

  const _SearchResultsBody({
    required this.searching,
    required this.query,
    required this.selectedType,
    required this.items,
    required this.users,
    required this.shelves,
  });

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const SizedBox(
        height: 420,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (selectedType == 'users') {
      if (users.isEmpty) {
        return _EmptySearchMessage(
          text: query.trim().isEmpty ? 'No users yet' : 'No users found',
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: users.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 430,
          mainAxisExtent: 150,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemBuilder: (context, index) => _UserSearchCard(doc: users[index]),
      );
    }

    if (selectedType == 'shelves') {
      if (shelves.isEmpty) {
        return _EmptySearchMessage(
          text: query.trim().isEmpty ? 'No shelves yet' : 'No shelves found',
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: shelves.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 460,
          mainAxisExtent: 132,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemBuilder: (context, index) => _ShelfSearchCard(doc: shelves[index]),
      );
    }

    if (items.isEmpty) {
      return _EmptySearchMessage(text: 'No results for "$query"');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisExtent: 286,
        mainAxisSpacing: 24,
        crossAxisSpacing: 18,
      ),
      itemBuilder: (context, index) => _PosterCard(item: items[index]),
    );
  }
}

class _EmptySearchMessage extends StatelessWidget {
  final String text;

  const _EmptySearchMessage({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.68),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
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
    final bio = (data['bio'] ?? '').toString().trim();
    final followers = ((data['followers'] as List?) ?? []).length;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: doc.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF101014),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white.withOpacity(0.08),
              backgroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 110,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 4),
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: kDiscoverAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 5),
                    if (bio.isNotEmpty)
                      Text(
                        bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 7),
                    Text(
                      '$followers followers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.38),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.35),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfSearchCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _ShelfSearchCard({
    required this.doc,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final name = (data['name'] ?? 'Untitled shelf').toString();
    final description = (data['description'] ?? '').toString().trim();
    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    final ownerId =
        (data['ownerId'] ?? doc.reference.parent.parent?.id ?? '').toString();
    final itemsCount = (data['itemsCount'] ?? 0) is num
        ? (data['itemsCount'] as num).toInt()
        : 0;
    final peopleCount = (((data['collaboratorIds'] as List?) ?? []).length) + 1;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: ownerId.isEmpty
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShelfScreen(
                    ownerId: ownerId,
                    shelfId: doc.id,
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF101014),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 74,
              height: 94,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.collections_bookmark_outlined,
                        color: Colors.white54,
                      ),
                    )
                  : const Icon(
                      Icons.collections_bookmark_outlined,
                      color: Colors.white54,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Text(
                    '$itemsCount items • $peopleCount people',
                    style: GoogleFonts.inter(
                      color: kDiscoverAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.35),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final String text;

  const _MiniInfoPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.70),
          fontSize: 10.8,
          fontWeight: FontWeight.w800,
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
                      filterQuality: FilterQuality.high,
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
            subtitle: 'Search public shelves',
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