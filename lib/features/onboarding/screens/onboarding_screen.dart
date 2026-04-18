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

  List<OnboardingMediaItem> _allItems = [];
  List<OnboardingMediaItem> _visibleItems = [];
  final List<OnboardingMediaItem> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);

    try {
      final items = await _mediaSeedService.getMixedPopularFeed(limit: 60);

      if (!mounted) return;
      setState(() {
        _allItems = items;
        _visibleItems = items;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load items: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _visibleItems = _allItems;
      } else {
        _visibleItems = _allItems.where((item) {
          final title = item.title.toLowerCase();
          final domain = item.domain.toLowerCase();
          final genres = item.genres.join(' ').toLowerCase();
          final tags = item.tags.join(' ').toLowerCase();

          return title.contains(query) ||
              domain.contains(query) ||
              genres.contains(query) ||
              tags.contains(query);
        }).toList();
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 5 items.')),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save preferences: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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

  String _domainLabel(String domain) {
    switch (domain) {
      case 'movies':
        return 'Movie';
      case 'shows':
        return 'TV';
      case 'books':
        return 'Book';
      case 'games':
        return 'Game';
      default:
        return domain;
    }
  }

  int _gridCount(double width) {
    if (width >= 1450) return 6;
    if (width >= 1150) return 5;
    if (width >= 850) return 4;
    if (width >= 620) return 3;
    return 2;
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = _gridCount(size.width);
    final searchText = _searchController.text;

    final titleStyle = GoogleFonts.inter(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: -1.2,
      height: 1,
    );

    final subtitleStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Colors.white.withOpacity(0.68),
      height: 1.4,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                      color: Colors.white.withOpacity(0.04),
                    ),
                    child: const Icon(
                      Icons.explore_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pick what you already like',
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose at least 5 titles to shape your initial profile.',
                    style: subtitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              hintText: 'Search titles, genres, or domains',
                              hintStyle: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 13.5,
                              ),
                              border: InputBorder.none,
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                              suffixIcon: searchText.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white54,
                                        size: 18,
                                      ),
                                    ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 52,
                        width: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: IconButton(
                          onPressed: _loading ? null : _loadFeed,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Selected ${_selectedItems.length}/5 minimum',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_visibleItems.isNotEmpty)
                          Text(
                            '${_visibleItems.length} shown',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Loading your starter mix...',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        padding: const EdgeInsets.only(bottom: 120, top: 4),
                        itemCount: _visibleItems.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.66,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                        ),
                        itemBuilder: (context, index) {
                          final item = _visibleItems[index];
                          final selected = _isSelected(item);
                          final title =
                              item.title.trim().isEmpty ? 'Untitled' : item.title;

                          return GestureDetector(
                            onTap: () => _toggleSelection(item),
                            child: AnimatedScale(
                              scale: selected ? 0.98 : 1,
                              duration: const Duration(milliseconds: 140),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.08),
                                    width: selected ? 2 : 1,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.08),
                                            blurRadius: 20,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      item.imageUrl.isNotEmpty
                                          ? Image.network(
                                              item.imageUrl,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: Colors.white.withOpacity(0.05),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.02),
                                              Colors.black.withOpacity(0.12),
                                              Colors.black.withOpacity(0.92),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        left: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _domainColor(item.domain),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _domainIcon(item.domain),
                                                color: Colors.black,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _domainLabel(item.domain),
                                                style: GoogleFonts.inter(
                                                  color: Colors.black,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.18),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        left: 12,
                                        right: 12,
                                        bottom: 12,
                                        child: Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 12.8,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: SizedBox(
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFE9E9E9),
                          ],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _saving ? null : _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                _selectedItems.length < 5
                                    ? 'Select at least 5'
                                    : 'Continue',
                                style: GoogleFonts.inter(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}