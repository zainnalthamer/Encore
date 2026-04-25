import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/media_seed_service.dart';
import '../../items/screens/item_details_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final MediaSeedService _mediaSeedService = MediaSeedService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _query = '';
  String _activeTab = 'Items';

  List<OnboardingMediaItem> _items = [];
  List<_UserResult> _users = [];
  List<_ShelfResult> _shelves = [];

  final List<String> _tabs = const ['Items', 'Users', 'Shelves'];

  @override
  void initState() {
    super.initState();
    _loadDiscover();
  }

  Future<void> _loadDiscover() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _mediaSeedService.getMixedPopularFeed(limit: 100);
      final users = await _loadUsers();
      final shelves = await _loadShelves();

      if (!mounted) return;

      setState(() {
        _items = items.where((item) => item.imageUrl.trim().isNotEmpty).toList();
        _users = users;
        _shelves = shelves;
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

  Future<List<_UserResult>> _loadUsers() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('users').limit(40).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return _UserResult(
        id: doc.id,
        name: (data['name'] ??
                data['displayName'] ??
                data['username'] ??
                'Encore User')
            .toString(),
        username: (data['username'] ?? '').toString(),
        avatarUrl: (data['avatarUrl'] ?? data['photoUrl'] ?? '').toString(),
        bio: (data['bio'] ?? 'No bio yet.').toString(),
      );
    }).toList();
  }

  Future<List<_ShelfResult>> _loadShelves() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('shelves').limit(40).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return _ShelfResult(
        id: doc.id,
        title: (data['title'] ?? 'Untitled Shelf').toString(),
        description: (data['description'] ?? 'A curated media shelf.').toString(),
        ownerName: (data['ownerName'] ?? data['username'] ?? 'Encore User')
            .toString(),
        itemCount: (data['itemCount'] is int) ? data['itemCount'] as int : 0,
      );
    }).toList();
  }

  List<OnboardingMediaItem> get _filteredItems {
    final q = _query.trim().toLowerCase();

    if (q.isEmpty) return _items;

    return _items.where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.domain.toLowerCase().contains(q) ||
          item.genres.any((g) => g.toLowerCase().contains(q)) ||
          item.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  List<_UserResult> get _filteredUsers {
    final q = _query.trim().toLowerCase();

    if (q.isEmpty) return _users;

    return _users.where((user) {
      return user.name.toLowerCase().contains(q) ||
          user.username.toLowerCase().contains(q) ||
          user.bio.toLowerCase().contains(q);
    }).toList();
  }

  List<_ShelfResult> get _filteredShelves {
    final q = _query.trim().toLowerCase();

    if (q.isEmpty) return _shelves;

    return _shelves.where((shelf) {
      return shelf.title.toLowerCase().contains(q) ||
          shelf.description.toLowerCase().contains(q) ||
          shelf.ownerName.toLowerCase().contains(q);
    }).toList();
  }

  List<OnboardingMediaItem> _itemsByDomain(String domain) {
    return _filteredItems.where((item) => item.domain == domain).take(12).toList();
  }

  List<OnboardingMediaItem> get _trendingItems {
    final list = [..._filteredItems];

    list.sort((a, b) {
      final bScore = b.tags.length + b.genres.length + b.description.length;
      final aScore = a.tags.length + a.genres.length + a.description.length;
      return bScore.compareTo(aScore);
    });

    return list.take(12).toList();
  }

  List<OnboardingMediaItem> get _highestRatedItems {
    final list = [..._filteredItems];

    list.sort((a, b) {
      final bScore = b.imageUrl.length + b.description.length + b.genres.length;
      final aScore = a.imageUrl.length + a.description.length + a.genres.length;
      return bScore.compareTo(aScore);
    });

    return list.take(12).toList();
  }

  void _openItem(OnboardingMediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemDetailsScreen(item: item),
      ),
    );
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: const Color(0xFF050507)),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadDiscover,
              color: Colors.white,
              backgroundColor: const Color(0xFF111111),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 108, 22, 120),
                children: [
                  Text(
                    'Discover',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search items, users, and shared shelves in one place.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.62),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SearchBox(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  _TabRow(
                    tabs: _tabs,
                    activeTab: _activeTab,
                    onChanged: (tab) {
                      setState(() {
                        _activeTab = tab;
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  if (_loading)
                    const _DiscoverLoading()
                  else if (_error != null)
                    _ErrorCard(message: _error!, onRetry: _loadDiscover)
                  else if (_activeTab == 'Items')
                    _ItemsView(
                      query: _query,
                      trendingItems: _trendingItems,
                      highestRatedItems: _highestRatedItems,
                      popularItems: _filteredItems.take(14).toList(),
                      movies: _itemsByDomain('movies'),
                      shows: _itemsByDomain('shows'),
                      books: _itemsByDomain('books'),
                      games: _itemsByDomain('games'),
                      onOpenItem: _openItem,
                      domainColor: _domainColor,
                      domainIcon: _domainIcon,
                      domainLabel: _domainLabel,
                    )
                  else if (_activeTab == 'Users')
                    _UsersView(users: _filteredUsers)
                  else
                    _ShelvesView(shelves: _filteredShelves),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _DiscoverTopNav(),
          ),
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
            Colors.black.withOpacity(0.95),
            Colors.black.withOpacity(0.76),
            Colors.black.withOpacity(0.34),
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
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.8,
              ),
            ),
            const Spacer(),
            _NavItem(
              label: 'Home',
              onTap: () => Navigator.pushReplacementNamed(context, '/home'),
            ),
            const SizedBox(width: 24),
            const _NavItem(label: 'Discover', active: true),
            const SizedBox(width: 24),
            _NavItem(
              label: 'Profile',
              onTap: () => Navigator.pushNamed(context, '/profile'),
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
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: const Color(0xFFFFA362),
        decoration: InputDecoration(
          hintText: 'Search movies, shows, books, games, users, shelves...',
          hintStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.38),
            fontSize: 14.5,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.56),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  final List<String> tabs;
  final String activeTab;
  final ValueChanged<String> onChanged;

  const _TabRow({
    required this.tabs,
    required this.activeTab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: tabs.map((tab) {
        final active = tab == activeTab;

        return GestureDetector(
          onTap: () => onChanged(tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFFFA362)
                  : Colors.white.withOpacity(0.055),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active
                    ? const Color(0xFFFFA362)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Text(
              tab,
              style: GoogleFonts.inter(
                color: active ? Colors.black : Colors.white.withOpacity(0.72),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ItemsView extends StatelessWidget {
  final String query;
  final List<OnboardingMediaItem> trendingItems;
  final List<OnboardingMediaItem> highestRatedItems;
  final List<OnboardingMediaItem> popularItems;
  final List<OnboardingMediaItem> movies;
  final List<OnboardingMediaItem> shows;
  final List<OnboardingMediaItem> books;
  final List<OnboardingMediaItem> games;
  final ValueChanged<OnboardingMediaItem> onOpenItem;
  final Color Function(String) domainColor;
  final IconData Function(String) domainIcon;
  final String Function(String) domainLabel;

  const _ItemsView({
    required this.query,
    required this.trendingItems,
    required this.highestRatedItems,
    required this.popularItems,
    required this.movies,
    required this.shows,
    required this.books,
    required this.games,
    required this.onOpenItem,
    required this.domainColor,
    required this.domainIcon,
    required this.domainLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (popularItems.isEmpty) {
      return const _EmptyState(title: 'No items found');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryStrip(
          categories: const [
            _CategoryData('Movies', Icons.local_movies_outlined),
            _CategoryData('TV Shows', Icons.tv_outlined),
            _CategoryData('Books', Icons.menu_book_outlined),
            _CategoryData('Games', Icons.sports_esports_outlined),
          ],
        ),
        const SizedBox(height: 28),
        _SectionTitle(title: query.isEmpty ? 'Popular now' : 'Search results'),
        const SizedBox(height: 14),
        _PosterGrid(
          items: popularItems,
          onOpenItem: onOpenItem,
          domainColor: domainColor,
          domainIcon: domainIcon,
          domainLabel: domainLabel,
        ),
        const SizedBox(height: 34),
        _SectionTitle(title: 'Trending'),
        const SizedBox(height: 14),
        _PosterRow(
          items: trendingItems,
          onOpenItem: onOpenItem,
          domainColor: domainColor,
          domainIcon: domainIcon,
          domainLabel: domainLabel,
        ),
        const SizedBox(height: 34),
        _SectionTitle(title: 'Highest rating'),
        const SizedBox(height: 14),
        _PosterRow(
          items: highestRatedItems,
          onOpenItem: onOpenItem,
          domainColor: domainColor,
          domainIcon: domainIcon,
          domainLabel: domainLabel,
        ),
        const SizedBox(height: 34),
        _SectionTitle(title: 'Movies'),
        const SizedBox(height: 14),
        _PosterRow(
          items: movies,
          onOpenItem: onOpenItem,
          domainColor: domainColor,
          domainIcon: domainIcon,
          domainLabel: domainLabel,
        ),
        const SizedBox(height: 34),
        _SectionTitle(title: 'TV Shows'),
        const SizedBox(height: 14),
        _PosterRow(
          items: shows,
          onOpenItem: onOpenItem,
          domainColor: domainColor,
          domainIcon: domainIcon,
          domainLabel: domainLabel,
        ),
        const SizedBox(height: 34),
        _SectionTitle(title: 'Books'),
        const SizedBox(height: 14),
        _PosterRow(
          items: books,
          onOpenItem: onOpenItem,
          domainColor: domainColor,
          domainIcon: domainIcon,
          domainLabel: domainLabel,
        ),
        const SizedBox(height: 34),
        _SectionTitle(title: 'Games'),
        const SizedBox(height: 14),
        _PosterRow(
          items: games,
          onOpenItem: onOpenItem,
          domainColor: domainColor,
          domainIcon: domainIcon,
          domainLabel: domainLabel,
        ),
      ],
    );
  }
}

class _CategoryData {
  final String label;
  final IconData icon;

  const _CategoryData(this.label, this.icon);
}

class _CategoryStrip extends StatelessWidget {
  final List<_CategoryData> categories;

  const _CategoryStrip({required this.categories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];

          return Container(
            width: 176,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.055),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(
                  category.icon,
                  color: const Color(0xFFFFA362),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  category.label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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

class _PosterGrid extends StatelessWidget {
  final List<OnboardingMediaItem> items;
  final ValueChanged<OnboardingMediaItem> onOpenItem;
  final Color Function(String) domainColor;
  final IconData Function(String) domainIcon;
  final String Function(String) domainLabel;

  const _PosterGrid({
    required this.items,
    required this.onOpenItem,
    required this.domainColor,
    required this.domainIcon,
    required this.domainLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width > 1000
            ? 6
            : width > 760
                ? 4
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: 18,
            crossAxisSpacing: 16,
            childAspectRatio: 0.57,
          ),
          itemBuilder: (context, index) {
            return _PosterCard(
              item: items[index],
              onOpenItem: onOpenItem,
              domainColor: domainColor,
              domainIcon: domainIcon,
              domainLabel: domainLabel,
            );
          },
        );
      },
    );
  }
}

class _PosterRow extends StatelessWidget {
  final List<OnboardingMediaItem> items;
  final ValueChanged<OnboardingMediaItem> onOpenItem;
  final Color Function(String) domainColor;
  final IconData Function(String) domainIcon;
  final String Function(String) domainLabel;

  const _PosterRow({
    required this.items,
    required this.onOpenItem,
    required this.domainColor,
    required this.domainIcon,
    required this.domainLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyState(title: 'Nothing here yet');

    return SizedBox(
      height: 330,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 190,
            child: _PosterCard(
              item: items[index],
              onOpenItem: onOpenItem,
              domainColor: domainColor,
              domainIcon: domainIcon,
              domainLabel: domainLabel,
            ),
          );
        },
      ),
    );
  }
}

class _PosterCard extends StatefulWidget {
  final OnboardingMediaItem item;
  final ValueChanged<OnboardingMediaItem> onOpenItem;
  final Color Function(String) domainColor;
  final IconData Function(String) domainIcon;
  final String Function(String) domainLabel;

  const _PosterCard({
    required this.item,
    required this.onOpenItem,
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
    final color = widget.domainColor(widget.item.domain);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onOpenItem(widget.item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white.withOpacity(0.06),
                        ),
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
                                Colors.black.withOpacity(0.72),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.44),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            widget.domainIcon(widget.item.domain),
                            color: color,
                            size: 17,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Text(
                          widget.domainLabel(widget.item.domain),
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.22,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.item.genres.isNotEmpty
                    ? widget.item.genres.take(2).join(' · ')
                    : widget.domainLabel(widget.item.domain),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.56),
                  fontSize: 12.5,
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

class _UsersView extends StatelessWidget {
  final List<_UserResult> users;

  const _UsersView({required this.users});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const _EmptyState(title: 'No users found');

    return Column(
      children: users.map((user) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.055),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.08),
                backgroundImage:
                    user.avatarUrl.isEmpty ? null : NetworkImage(user.avatarUrl),
                child: user.avatarUrl.isEmpty
                    ? const Icon(Icons.person_rounded, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.username.isEmpty ? user.bio : '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.56),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white54,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ShelvesView extends StatelessWidget {
  final List<_ShelfResult> shelves;

  const _ShelvesView({required this.shelves});

  @override
  Widget build(BuildContext context) {
    if (shelves.isEmpty) return const _EmptyState(title: 'No shelves found');

    return Column(
      children: shelves.map((shelf) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.055),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA362).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.bookmarks_outlined,
                  color: Color(0xFFFFA362),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shelf.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${shelf.ownerName} · ${shelf.itemCount} items',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.56),
                        fontSize: 12.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      shelf.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.68),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 25,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
    );
  }
}

class _DiscoverLoading extends StatelessWidget {
  const _DiscoverLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        6,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;

  const _EmptyState({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.62),
            fontWeight: FontWeight.w600,
          ),
        ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load discover',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.66),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA362),
              foregroundColor: Colors.black,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _UserResult {
  final String id;
  final String name;
  final String username;
  final String avatarUrl;
  final String bio;

  const _UserResult({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.bio,
  });
}

class _ShelfResult {
  final String id;
  final String title;
  final String description;
  final String ownerName;
  final int itemCount;

  const _ShelfResult({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerName,
    required this.itemCount,
  });
}