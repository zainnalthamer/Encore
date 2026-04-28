import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../items/screens/item_details_screen.dart';

class DiscoverResultsScreen extends StatefulWidget {
  final String title;
  final List<OnboardingMediaItem> items;

  const DiscoverResultsScreen({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  State<DiscoverResultsScreen> createState() => _DiscoverResultsScreenState();
}

class _DiscoverResultsScreenState extends State<DiscoverResultsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String _selectedDomain = 'all';
  String _selectedType = 'items';

  final List<String> _domains = const ['all', 'movies', 'shows', 'books', 'games'];
  final List<String> _types = const ['items', 'users', 'shelves'];

  static const Color _bg = Color(0xFF050507);
  static const Color _accent = Color(0xFFFF8B3D);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OnboardingMediaItem> get _filteredItems {
    if (_selectedType != 'items') return [];

    final q = _query.toLowerCase().trim();

    return widget.items.where((item) {
      final matchesDomain =
          _selectedDomain == 'all' || item.domain == _selectedDomain;

      final matchesSearch = q.isEmpty ||
          item.title.toLowerCase().contains(q) ||
          item.domain.toLowerCase().contains(q) ||
          item.genres.any((g) => g.toLowerCase().contains(q)) ||
          item.tags.any((t) => t.toLowerCase().contains(q));

      return matchesDomain && matchesSearch;
    }).toList();
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

  String _typeLabel(String type) {
    switch (type) {
      case 'items':
        return 'Items';
      case 'users':
        return 'Users soon';
      case 'shelves':
        return 'Shelves soon';
      default:
        return type;
    }
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
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
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
                        modalSetState(() {
                          _selectedType = value;
                        });
                        setState(() {
                          _selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    _FilterGroup(
                      title: 'Domain',
                      options: _domains,
                      selected: _selectedDomain,
                      label: _domainLabel,
                      onSelected: (value) {
                        modalSetState(() {
                          _selectedDomain = value;
                        });
                        setState(() {
                          _selectedDomain = value;
                        });
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

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 108, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _DiscoverSearchBar(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _query = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _showFilterSheet,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ActiveFilterLine(
                        type: _typeLabel(_selectedType),
                        domain: _domainLabel(_selectedDomain),
                        count: items.length,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: _EmptyState(
                      type: _selectedType,
                      query: _query,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _DiscoverResultCard(item: items[index]);
                      },
                      childCount: items.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 185,
                      mainAxisExtent: 292,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 18,
                    ),
                  ),
                ),
            ],
          ),
          const _ResultsTopNav(),
        ],
      ),
    );
  }
}

class _ResultsTopNav extends StatelessWidget {
  const _ResultsTopNav();

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
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
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
            Text(
              'Discover',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.72),
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _DiscoverSearchBar({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: Colors.white,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.45),
          ),
          hintText: 'Search this section...',
          hintStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.35),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
        ),
      ),
    );
  }
}

class _ActiveFilterLine extends StatelessWidget {
  final String type;
  final String domain;
  final int count;

  const _ActiveFilterLine({
    required this.type,
    required this.domain,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count results • $type • $domain',
      style: GoogleFonts.inter(
        color: Colors.white.withOpacity(0.42),
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
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
                      ? const Color(0xFFFF8B3D)
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? const Color(0xFFFF8B3D)
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

class _DiscoverResultCard extends StatelessWidget {
  final OnboardingMediaItem item;

  const _DiscoverResultCard({
    required this.item,
  });

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

  @override
  Widget build(BuildContext context) {
    final imageUrl = _image(item.imageUrl);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(item: item),
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 232,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: imageUrl.trim().isEmpty
                    ? _FallbackPoster(domain: item.domain)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.topCenter,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) {
                          return _FallbackPoster(domain: item.domain);
                        },
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
                letterSpacing: -0.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.genres.isEmpty
                  ? _domainLabel(item.domain)
                  : item.genres.take(2).join(' • '),
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
      ),
    );
  }
}

class _FallbackPoster extends StatelessWidget {
  final String domain;

  const _FallbackPoster({
    required this.domain,
  });

  IconData _icon() {
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
        return Icons.image_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.07),
      child: Center(
        child: Icon(
          _icon(),
          color: Colors.white54,
          size: 30,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String type;
  final String query;

  const _EmptyState({
    required this.type,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final isComingSoon = type == 'users' || type == 'shelves';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComingSoon
                ? Icons.lock_clock_rounded
                : Icons.search_off_rounded,
            color: Colors.white54,
            size: 36,
          ),
          const SizedBox(height: 14),
          Text(
            isComingSoon
                ? type == 'users'
                    ? 'Users are coming soon'
                    : 'Shelves are coming soon'
                : query.trim().isEmpty
                    ? 'No items found'
                    : 'No results for "$query"',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isComingSoon
                ? 'This filter is here so the structure is ready once public discovery is added.'
                : 'Try another search or change the filters.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.45),
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}