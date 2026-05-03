import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/user_library_service.dart';
import '../../profile/screens/profile_screen.dart';

class ItemDetailsScreen extends StatefulWidget {
  final OnboardingMediaItem item;

  const ItemDetailsScreen({
    super.key,
    required this.item,
  });

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  final UserLibraryService _libraryService = UserLibraryService();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _itemSub;

  bool _saved = false;
  bool _favorite = false;
  late String _status;

  double _userRating = 0;
  String _lastReview = '';

  static const Color _accent = Color(0xFFFF8B3D);
  static const Color _bg = Color(0xFF050507);

  @override
  void initState() {
    super.initState();
    _status = _defaultStatus(widget.item.domain);
    _listenToItemState();
  }

  void _listenToItemState() {
    _itemSub = _libraryService.watchItem(widget.item.id).listen((snapshot) {
      final data = snapshot.data();
      if (!mounted || data == null) return;

      setState(() {
        _saved = data['isSaved'] == true;
        _favorite = data['isFavorite'] == true;
        _status = (data['status'] ?? _status).toString();
        _userRating = ((data['userRating'] ?? 0) as num).toDouble();
        _lastReview = (data['lastReview'] ?? '').toString();
      });
    });
  }

  @override
  void dispose() {
    _itemSub?.cancel();
    super.dispose();
  }

  String _defaultStatus(String domain) {
    switch (domain) {
      case 'movies':
      case 'shows':
        return 'Want to watch';
      case 'books':
        return 'Want to read';
      case 'games':
        return 'Want to try';
      default:
        return 'Want to try';
    }
  }

  List<String> _statusOptions(String domain) {
    switch (domain) {
      case 'movies':
      case 'shows':
        return ['Want to watch', 'Watching', 'Completed', 'Paused'];
      case 'books':
        return ['Want to read', 'Reading', 'Completed', 'Paused'];
      case 'games':
        return ['Want to try', 'Playing', 'Completed', 'Paused'];
      default:
        return ['Want to try', 'In progress', 'Completed', 'Paused'];
    }
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

  String _availabilityTitle(String domain) {
    switch (domain) {
      case 'movies':
      case 'shows':
        return 'Where to watch';
      case 'books':
        return 'Where to read';
      case 'games':
        return 'Where to play';
      default:
        return 'Availability';
    }
  }

  List<String> _fakeProviders(String domain) {
    switch (domain) {
      case 'movies':
      case 'shows':
        return ['Netflix', 'Prime Video', 'Apple TV'];
      case 'books':
        return ['Google Books', 'Open Library', 'Kindle'];
      case 'games':
        return ['Steam', 'PlayStation', 'Xbox'];
      default:
        return ['Provider'];
    }
  }

  Future<void> _toggleSaved() async {
    final newValue = !_saved;
    setState(() => _saved = newValue);

    try {
      await _libraryService.toggleSaved(
        item: widget.item,
        saved: newValue,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saved = !newValue);
      _showSnack('Could not update saved item.');
    }
  }

  Future<void> _toggleFavorite() async {
    final newValue = !_favorite;
    setState(() => _favorite = newValue);

    try {
      await _libraryService.toggleFavorite(
        item: widget.item,
        favorite: newValue,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _favorite = !newValue);
      _showSnack('Could not update favorite.');
    }
  }

  Future<void> _saveRating(double rating) async {
    try {
      await _libraryService.updateRating(
        item: widget.item,
        rating: rating,
      );

      if (!mounted) return;
      _showSnack('Rating saved.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not save rating.');
    }
  }

  Future<void> _addReview({
    required double rating,
    required String review,
  }) async {
    final cleanReview = review.trim();

    if (cleanReview.isEmpty) {
      await _saveRating(rating);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    try {
      await _libraryService.addReview(
        item: widget.item,
        rating: rating,
        review: cleanReview,
        displayName: user?.displayName ?? 'Encore User',
        username: user?.email?.split('@').first ?? '',
        photoUrl: user?.photoURL ?? '',
      );

      if (!mounted) return;
      _showSnack('Review added.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not add review.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showStatusSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final statuses = _statusOptions(widget.item.domain);

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
          decoration: const BoxDecoration(
            color: Color(0xFF101014),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Update status',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...statuses.map((status) {
                final selected = _status == status;

                return GestureDetector(
                  onTap: () async {
                    setState(() => _status = status);

                    await _libraryService.updateStatus(
                      item: widget.item,
                      status: status,
                    );

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected
                          ? _accent.withOpacity(0.14)
                          : Colors.white.withOpacity(0.045),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: selected
                            ? _accent.withOpacity(0.40)
                            : Colors.white.withOpacity(0.07),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: selected ? _accent : Colors.white54,
                          size: 21,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          status,
                          style: GoogleFonts.inter(
                            color: selected ? _accent : Colors.white,
                            fontSize: 15,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showFullTextSheet({
    required String title,
    required String subtitle,
    required String body,
    String? imageUrl,
    double? rating,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (context, controller) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF101014),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (imageUrl != null && imageUrl.trim().isNotEmpty) ...[
                        CircleAvatar(
                          radius: 27,
                          backgroundImage: NetworkImage(imageUrl),
                          backgroundColor: Colors.white.withOpacity(0.08),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.7,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.48),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (rating != null && rating > 0) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: _accent,
                          size: 19,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    body,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final providers = _fakeProviders(item.domain);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeroSection(
                item: item,
                saved: _saved,
                favorite: _favorite,
                status: _status,
                domainLabel: _domainLabel,
                domainIcon: _domainIcon,
                onSave: _toggleSaved,
                onFavorite: _toggleFavorite,
                onStatus: _showStatusSheet,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ItemPublicStats(
                      item: item,
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle(
                            title: 'Overview',
                            subtitle: 'About this title',
                          ),
                          const SizedBox(height: 14),
                          Text(
                            item.description.trim().isEmpty
                                ? 'No description available yet.'
                                : item.description,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.70),
                              fontSize: 15,
                              height: 1.7,
                            ),
                          ),
                          if (item.tags.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: item.tags.take(10).map((tag) {
                                return _Tag(label: tag);
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ReviewComposerCard(
                      rating: _userRating,
                      lastReview: _lastReview,
                      onSaveRating: _saveRating,
                      onAddReview: _addReview,
                      onViewLastReview: _lastReview.trim().isEmpty
                          ? null
                          : () {
                              _showFullTextSheet(
                                title: 'Your latest review',
                                subtitle: item.title,
                                body: _lastReview,
                                rating: _userRating,
                              );
                            },
                    ),
                    const SizedBox(height: 16),
                    _CommunityReviewsCard(
                      libraryService: _libraryService,
                      itemId: widget.item.id,
                      onOpenReview: ({
                        required String name,
                        required String username,
                        required String photoUrl,
                        required double rating,
                        required String review,
                      }) {
                        _showFullTextSheet(
                          title: name,
                          subtitle: username.isEmpty ? item.title : '@$username',
                          body: review,
                          imageUrl: photoUrl,
                          rating: rating,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _AvailabilityCard(
                      title: _availabilityTitle(item.domain),
                      providers: providers,
                    ),
                    const SizedBox(height: 16),
                    _SimilarSection(currentItem: item),
                  ],
                ),
              ),
            ],
          ),
          const _DetailsTopNav(),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final OnboardingMediaItem item;
  final bool saved;
  final bool favorite;
  final String status;
  final String Function(String) domainLabel;
  final IconData Function(String) domainIcon;
  final VoidCallback onSave;
  final VoidCallback onFavorite;
  final VoidCallback onStatus;

  const _HeroSection({
    required this.item,
    required this.saved,
    required this.favorite,
    required this.status,
    required this.domainLabel,
    required this.domainIcon,
    required this.onSave,
    required this.onFavorite,
    required this.onStatus,
  });

  static const Color _accent = Color(0xFFFF8B3D);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 460,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.imageUrl.trim().isNotEmpty)
            Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: const Color(0xFF111114)),
            )
          else
            Container(color: const Color(0xFF111114)),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: Colors.black.withOpacity(0.22)),
            ),
          ),
          if (item.imageUrl.trim().isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.68,
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF050507),
                    const Color(0xFF050507).withOpacity(0.96),
                    const Color(0xFF050507).withOpacity(0.70),
                    const Color(0xFF050507).withOpacity(0.08),
                  ],
                  stops: const [0, 0.34, 0.67, 1],
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
                    Colors.black.withOpacity(0.76),
                    Colors.transparent,
                    const Color(0xFF050507),
                  ],
                  stops: const [0, 0.46, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 150,
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: item.imageUrl.trim().isNotEmpty
                        ? Image.network(item.imageUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.white.withOpacity(0.06),
                            child: Icon(
                              domainIcon(item.domain),
                              color: _accent,
                              size: 38,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DomainPill(
                          icon: domainIcon(item.domain),
                          label: domainLabel(item.domain).toUpperCase(),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          item.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            height: 0.98,
                            letterSpacing: -1.7,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.genres.isEmpty
                              ? 'Curated for you'
                              : item.genres.take(4).join('  •  '),
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.62),
                            fontSize: 14.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _PrimaryButton(
                              label: status,
                              icon: Icons.add_rounded,
                              onTap: onStatus,
                            ),
                            _CircleAction(
                              icon: saved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              active: saved,
                              tooltip: saved ? 'Saved' : 'Save',
                              onTap: onSave,
                            ),
                            _CircleAction(
                              icon: favorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              active: favorite,
                              tooltip: favorite ? 'Favorited' : 'Favorite',
                              onTap: onFavorite,
                            ),
                          ],
                        ),
                      ],
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

class _DetailsTopNav extends StatelessWidget {
  const _DetailsTopNav();

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
            Colors.black.withOpacity(0.70),
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
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.8,
              ),
            ),
            const Spacer(),
            _NavText(label: 'Home', onTap: () => Navigator.pop(context)),
            const SizedBox(width: 24),
            const _NavText(label: 'Discover'),
            const SizedBox(width: 24),
            _NavText(
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

class _NavText extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _NavText({
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.70),
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ItemPublicStats extends StatelessWidget {
  final OnboardingMediaItem item;

  const _ItemPublicStats({
    required this.item,
  });

  double _calculateAverageRating(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final ratings = docs
        .map((doc) => ((doc.data()['rating'] ?? 0) as num).toDouble())
        .where((rating) => rating > 0)
        .toList();

    if (ratings.isEmpty) return 0;

    final total = ratings.fold<double>(0, (sum, rating) => sum + rating);
    return total / ratings.length;
  }

  int _calculateMatchPercentage(Map<String, dynamic>? userData) {
    if (userData == null) return 0;

    String clean(String value) {
      return value
          .toLowerCase()
          .trim()
          .replaceAll('&', 'and')
          .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    }

    Map<String, int> readCounts(dynamic value) {
      if (value is Map) {
        return value.map(
          (key, val) => MapEntry(
            clean(key.toString()),
            val is num ? val.toInt() : 1,
          ),
        );
      }

      if (value is List) {
        return {
          for (final item in value) clean(item.toString()): 1,
        };
      }

      return {};
    }

    final domainCounts = readCounts(userData['domainCounts']);
    final genreCounts = readCounts(userData['genreCounts']);
    final tagCounts = readCounts(userData['tagCounts']);

    final itemDomain = clean(item.domain);

    final itemGenres = item.genres.map((genre) => clean(genre)).toList();
    final itemTags = item.tags.map((tag) => clean(tag)).toList();

    double score = 0;

    bool hasLooseMatch(String itemValue, Map<String, int> preferences) {
      for (final pref in preferences.keys) {
        if (pref.contains(itemValue) || itemValue.contains(pref)) {
          return true;
        }
      }
      return false;
    }

    if (domainCounts.containsKey(itemDomain)) {
      score += 25;
    }

    for (final genre in itemGenres) {
      if (genreCounts.containsKey(genre) || hasLooseMatch(genre, genreCounts)) {
        score += 18;
      }
    }

    for (final tag in itemTags) {
      if (tagCounts.containsKey(tag) || hasLooseMatch(tag, tagCounts)) {
        score += 10;
      }
    }

    if (score == 0) {
      int fallback = 8;

      if (item.domain.trim().isNotEmpty) fallback += 7;
      if (itemGenres.isNotEmpty) fallback += itemGenres.length.clamp(1, 4) * 4;
      if (itemTags.isNotEmpty) fallback += itemTags.length.clamp(1, 5) * 3;

      return fallback.clamp(10, 42);
    }

    return score.clamp(22, 97).round();
  }

  int _fakeSaveCountForItem(String itemId) {
    if (itemId.trim().isEmpty) return 0;

    final hash = itemId.codeUnits.fold<int>(
      0,
      (previous, value) => previous + value,
    );

    return 18 + (hash % 430);
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .doc(item.id)
          .collection('reviews')
          .snapshots(),
      builder: (context, reviewsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collectionGroup('libraryItems')
              .where('itemId', isEqualTo: item.id)
              .snapshots(),
          builder: (context, savesSnapshot) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: uid == null
                  ? null
                  : FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .snapshots(),
              builder: (context, userSnapshot) {
                final reviewDocs = reviewsSnapshot.data?.docs ?? [];
                final allLibraryDocs = savesSnapshot.data?.docs ?? [];

                final realSaveCount = allLibraryDocs.where((doc) {
                  final data = doc.data();

                  return data['isSaved'] == true || data['saved'] == true;
                }).length;

                final websiteAverage = _calculateAverageRating(reviewDocs);
                final apiAverage = item.apiRating;

                final averageRating = websiteAverage > 0 ? websiteAverage : apiAverage;
                final saveCount = realSaveCount > 0
                    ? realSaveCount
                    : _fakeSaveCountForItem(item.id);
                final match = _calculateMatchPercentage(
                  userSnapshot.data?.data(),
                );

                return Container(
                  height: 86,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0B0D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          title: averageRating <= 0
                              ? '-'
                              : averageRating.toStringAsFixed(1),
                          subtitle: 'Average rating',
                          icon: Icons.star_rounded,
                        ),
                      ),
                      const _SoftDivider(),
                      Expanded(
                        child: _StatTile(
                          title: _formatCount(saveCount),
                          subtitle: saveCount == 1 ? 'Save' : 'Saves',
                          icon: Icons.bookmark_rounded,
                        ),
                      ),
                      const _SoftDivider(),
                      Expanded(
                        child: _StatTile(
                          title: '$match%',
                          subtitle: 'Match',
                          icon: Icons.auto_awesome_rounded,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: Colors.white.withOpacity(0.07),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _StatTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  static const Color _accent = Color(0xFFFF8B3D);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _accent, size: 19),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.48),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewComposerCard extends StatefulWidget {
  final double rating;
  final String lastReview;
  final Future<void> Function(double rating) onSaveRating;
  final Future<void> Function({
    required double rating,
    required String review,
  }) onAddReview;
  final VoidCallback? onViewLastReview;

  const _ReviewComposerCard({
    required this.rating,
    required this.lastReview,
    required this.onSaveRating,
    required this.onAddReview,
    required this.onViewLastReview,
  });

  @override
  State<_ReviewComposerCard> createState() => _ReviewComposerCardState();
}

class _ReviewComposerCardState extends State<_ReviewComposerCard> {
  late double _rating;
  final TextEditingController _controller = TextEditingController();
  bool _savingRating = false;
  bool _postingReview = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.rating;
  }

  @override
  void didUpdateWidget(covariant _ReviewComposerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rating != widget.rating) {
      _rating = widget.rating;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveRating() async {
    setState(() => _savingRating = true);
    try {
      await widget.onSaveRating(_rating);
    } finally {
      if (mounted) setState(() => _savingRating = false);
    }
  }

  Future<void> _postReview() async {
    setState(() => _postingReview = true);
    try {
      await widget.onAddReview(
        rating: _rating,
        review: _controller.text,
      );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _postingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Your thoughts',
            subtitle: 'Rate it once, post as many reviews as you want',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  final value = index + 1.0;
                  final active = _rating >= value;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = value;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        active
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFFF8B3D),
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 12),
              Text(
                _rating <= 0 ? 'No rating' : '${_rating.toStringAsFixed(1)} / 5',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _savingRating ? null : _saveRating,
                child: Text(
                  _savingRating ? 'Saving...' : 'Save rating',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF8B3D),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (widget.lastReview.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: widget.onViewLastReview,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8B3D).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.rate_review_outlined,
                        color: Color(0xFFFF8B3D),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.lastReview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.66),
                          fontSize: 13.2,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'View',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF8B3D),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 7,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                height: 1.55,
              ),
              cursorColor: const Color(0xFFFF8B3D),
              decoration: InputDecoration(
                hintText: 'Write a new review...',
                hintStyle: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.34),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _postingReview ? null : _postReview,
              icon: const Icon(Icons.send_rounded, size: 17),
              label: Text(
                _postingReview ? 'Posting...' : 'Post review',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8B3D),
                disabledBackgroundColor: Colors.white.withOpacity(0.12),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityReviewsCard extends StatelessWidget {
  final UserLibraryService libraryService;
  final String itemId;
  final void Function({
    required String name,
    required String username,
    required String photoUrl,
    required double rating,
    required String review,
  }) onOpenReview;

  const _CommunityReviewsCard({
    required this.libraryService,
    required this.itemId,
    required this.onOpenReview,
  });

  Future<void> _deleteReview({
    required BuildContext context,
    required String reviewId,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101014),
          title: Text(
            'Delete review?',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'This will remove your review permanently.',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.65),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF8B3D),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .collection('reviews')
          .doc(reviewId)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted.')),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete review.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return _SectionCard(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: libraryService.watchReviewsForItem(itemId),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Community reviews',
                subtitle: 'Tap any review to read it fully',
              ),
              const SizedBox(height: 16),
              if (snapshot.hasError)
                Text(
                  'Could not load reviews: ${snapshot.error}',
                  style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                ),
              )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              else if (docs.isEmpty)
                Text(
                  'No reviews yet.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 14,
                  ),
                )
              else
                Column(
                  children: docs.map((doc) {
                    final data = doc.data();

                    final name =
                        (data['displayName'] ?? 'Encore User').toString();
                    final username = (data['username'] ?? '').toString();
                    final photoUrl = (data['photoUrl'] ?? '').toString();
                    final rating =
                        ((data['rating'] ?? 0) as num).toDouble();
                    final review = (data['review'] ?? '').toString();
                    final reviewOwnerUid = (data['uid'] ?? '').toString();

                    final canDelete = currentUid != null &&
                        currentUid.isNotEmpty &&
                        reviewOwnerUid == currentUid;

                    return _CommunityReviewTile(
                      name: name,
                      username: username,
                      photoUrl: photoUrl,
                      rating: rating,
                      review: review,
                      canDelete: canDelete,
                      onDelete: canDelete
                          ? () => _deleteReview(
                                context: context,
                                reviewId: doc.id,
                              )
                          : null,
                      onTap: () {
                        onOpenReview(
                          name: name,
                          username: username,
                          photoUrl: photoUrl,
                          rating: rating,
                          review: review,
                        );
                      },
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CommunityReviewTile extends StatelessWidget {
  final String name;
  final String username;
  final String photoUrl;
  final double rating;
  final String review;
  final bool canDelete;
  final VoidCallback? onDelete;
  final VoidCallback onTap;

  const _CommunityReviewTile({
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.rating,
    required this.review,
    required this.canDelete,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.24),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withOpacity(0.08),
              backgroundImage:
                  photoUrl.trim().isEmpty ? null : NetworkImage(photoUrl),
              child: photoUrl.trim().isEmpty
                  ? const Icon(
                      Icons.person_rounded,
                      color: Colors.white54,
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFF8B3D),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (canDelete) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            onDelete?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFFF8B3D),
                              size: 17,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (username.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.42),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (review.trim().isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      review,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.68),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Read full review',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFF8B3D),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final String title;
  final List<String> providers;

  const _AvailabilityCard({
    required this.title,
    required this.providers,
  });

  static const Color _accent = Color(0xFFFF8B3D);

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: title,
            subtitle: 'Sources shown for reference',
          ),
          const SizedBox(height: 14),
          Text(
            'This title may be available through:',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: providers.map((provider) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _accent.withOpacity(0.24)),
                ),
                child: Text(
                  provider,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SimilarSection extends StatefulWidget {
  final OnboardingMediaItem currentItem;

  const _SimilarSection({
    required this.currentItem,
  });

  @override
  State<_SimilarSection> createState() => _SimilarSectionState();
}

class _SimilarSectionState extends State<_SimilarSection> {
  late Future<List<OnboardingMediaItem>> _future;

  static const String tmdbApiKey = 'YOUR_TMDB_API_KEY';
  static const String rawgApiKey = 'YOUR_RAWG_API_KEY';

  @override
  void initState() {
    super.initState();
    _future = _fetchSimilarItems();
  }

  Future<List<OnboardingMediaItem>> _fetchSimilarItems() async {
    final domain = widget.currentItem.domain.toLowerCase().trim();

    List<OnboardingMediaItem> items = [];

    try {
      if (domain == 'movies') {
        items = await _fetchTmdbItems(type: 'movie');
      } else if (domain == 'shows') {
        items = await _fetchTmdbItems(type: 'tv');
      } else if (domain == 'games') {
        items = await _fetchRawgItems();
      } else if (domain == 'books') {
        items = await _fetchBookItems();
      }
    } catch (e) {
      debugPrint('Similar fetch failed: $e');
    }

    if (items.length >= 3) return items.take(3).toList();

    final fallback = _fallbackItems(domain);

    final merged = [
      ...items,
      ...fallback.where((fallbackItem) {
        return fallbackItem.id != widget.currentItem.id &&
            !items.any((item) => item.id == fallbackItem.id);
      }),
    ];

    return merged.take(3).toList();
  }

  List<OnboardingMediaItem> _fallbackItems(String domain) {
    final genres = widget.currentItem.genres.map((e) => e.toLowerCase()).toList();
    final tags = widget.currentItem.tags.map((e) => e.toLowerCase()).toList();
    final title = widget.currentItem.title.toLowerCase();

    bool hasAny(List<String> words) {
      return words.any((word) {
        return title.contains(word) ||
            genres.any((g) => g.contains(word) || word.contains(g)) ||
            tags.any((t) => t.contains(word) || word.contains(t));
      });
    }

    if (domain == 'movies') {
      if (hasAny(['horror', 'thriller', 'mystery', 'dark'])) {
        return const [
          OnboardingMediaItem(
            id: '419430',
            title: 'Get Out',
            domain: 'movies',
            genres: ['Horror', 'Mystery', 'Thriller'],
            tags: ['dark', 'psychological', 'suspense'],
            imageUrl: 'https://image.tmdb.org/t/p/w780/tFXcEccSQMf3lfhfXKSU9iRBpa3.jpg',
            source: 'tmdb',
            description: 'A psychological thriller about fear, control, and hidden violence.',
            apiRating: 3.85,
          ),
          OnboardingMediaItem(
            id: '381288',
            title: 'Split',
            domain: 'movies',
            genres: ['Thriller', 'Horror'],
            tags: ['psychological', 'dark', 'suspense'],
            imageUrl: 'https://image.tmdb.org/t/p/w780/lli31lYTFpvxVBeFHWoe5PMfW5s.jpg',
            source: 'tmdb',
            description: 'A tense psychological thriller.',
            apiRating: 3.65,
          ),
          OnboardingMediaItem(
            id: '11324',
            title: 'Shutter Island',
            domain: 'movies',
            genres: ['Mystery', 'Thriller'],
            tags: ['psychological', 'detective', 'dark'],
            imageUrl: 'https://image.tmdb.org/t/p/w780/4GDy0PHYX3VRXUtwK5ysFbg3kEx.jpg',
            source: 'tmdb',
            description: 'A mystery thriller set around an investigation on an isolated island.',
            apiRating: 4.1,
          ),
        ];
      }

      if (hasAny(['romance', 'love', 'drama'])) {
        return const [
          OnboardingMediaItem(
            id: '313369',
            title: 'La La Land',
            domain: 'movies',
            genres: ['Romance', 'Drama', 'Music'],
            tags: ['love', 'dreams', 'emotional'],
            imageUrl: 'https://image.tmdb.org/t/p/w780/uDO8zWDhfWwoFdKS4fzkUJt0Rf0.jpg',
            source: 'tmdb',
            description: 'A romantic drama about ambition, love, and dreams.',
            apiRating: 3.95,
          ),
          OnboardingMediaItem(
            id: '11036',
            title: 'The Notebook',
            domain: 'movies',
            genres: ['Romance', 'Drama'],
            tags: ['love', 'emotional', 'relationship'],
            imageUrl: 'https://image.tmdb.org/t/p/w780/qom1SZSENdmHFNZBXbtJAU0WTlC.jpg',
            source: 'tmdb',
            description: 'A romantic drama about lasting love.',
            apiRating: 3.9,
          ),
          OnboardingMediaItem(
            id: '398818',
            title: 'Call Me by Your Name',
            domain: 'movies',
            genres: ['Romance', 'Drama'],
            tags: ['summer', 'love', 'emotional'],
            imageUrl: 'https://image.tmdb.org/t/p/w780/mZ4gBdfkhP9tvLH1DO4m4HYtiyi.jpg',
            source: 'tmdb',
            description: 'A quiet coming-of-age romance.',
            apiRating: 4.0,
          ),
        ];
      }

      if (hasAny(['animation', 'family', 'kids', 'comedy'])) {
        return const [
          OnboardingMediaItem(
            id: '150540',
            title: 'Inside Out',
            domain: 'movies',
            genres: ['Animation', 'Family', 'Comedy'],
            tags: ['emotions', 'family', 'colorful'],
            imageUrl: 'https://image.tmdb.org/t/p/w780/2H1TmgdfNtsKlU9jKdeNyYL5y8T.jpg',
            source: 'tmdb',
            description: 'An animated story about emotions and growing up.',
            apiRating: 4.0,
          ),
          OnboardingMediaItem(
            id: '862',
            title: 'Toy Story',
            domain: 'movies',
            genres: ['Animation', 'Family', 'Comedy'],
            tags: ['toys', 'friendship', 'adventure'],
            imageUrl: 'https://image.tmdb.org/t/p/w780/uXDfjJbdP4ijW5hWSBrPrlKpxab.jpg',
            source: 'tmdb',
            description: 'A friendship adventure about toys coming to life.',
            apiRating: 4.0,
          ),
          OnboardingMediaItem(
            id: '508943',
            title: 'Luca',
            domain: 'movies',
            genres: ['Animation', 'Family', 'Comedy'],
            tags: ['friendship', 'summer', 'adventure'],
            imageUrl: 'https://image.tmdb.org/t/p/w780/jTswp6KyDYKtvC52GbHagrZbGvD.jpg',
            source: 'tmdb',
            description: 'A warm animated coming-of-age story.',
            apiRating: 3.8,
          ),
        ];
      }

      return const [
        OnboardingMediaItem(
          id: '27205',
          title: 'Inception',
          domain: 'movies',
          genres: ['Action', 'Sci-Fi', 'Thriller'],
          tags: ['mind', 'dreams', 'heist'],
          imageUrl: 'https://image.tmdb.org/t/p/w780/oYuLEt3zVCKq57qu2F8dT7NIa6f.jpg',
          source: 'tmdb',
          description: 'A sci-fi thriller about dreams and memory.',
          apiRating: 4.2,
        ),
        OnboardingMediaItem(
          id: '157336',
          title: 'Interstellar',
          domain: 'movies',
          genres: ['Sci-Fi', 'Drama', 'Adventure'],
          tags: ['space', 'time', 'emotional'],
          imageUrl: 'https://image.tmdb.org/t/p/w780/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
          source: 'tmdb',
          description: 'A space drama about survival, time, and love.',
          apiRating: 4.35,
        ),
        OnboardingMediaItem(
          id: '603',
          title: 'The Matrix',
          domain: 'movies',
          genres: ['Sci-Fi', 'Action'],
          tags: ['future', 'reality', 'technology'],
          imageUrl: 'https://image.tmdb.org/t/p/w780/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg',
          source: 'tmdb',
          description: 'A sci-fi action film about reality and control.',
          apiRating: 4.1,
        ),
      ];
    }

    return _fallbackItemsByDomainOnly(domain);
  }

  List<OnboardingMediaItem> _fallbackItemsByDomainOnly(String domain) {
    if (domain == 'shows') {
      return const [
        OnboardingMediaItem(
          id: '66732',
          title: 'Stranger Things',
          domain: 'shows',
          genres: ['Drama', 'Sci-Fi', 'Mystery'],
          tags: ['supernatural', 'friends', '80s'],
          imageUrl: 'https://image.tmdb.org/t/p/w780/uOOtwVbSr4QDjAGIifLDwpb2Pdl.jpg',
          source: 'tmdb',
          description: 'A small town uncovers supernatural mysteries.',
          apiRating: 4.3,
        ),
        OnboardingMediaItem(
          id: '1396',
          title: 'Breaking Bad',
          domain: 'shows',
          genres: ['Drama', 'Crime', 'Thriller'],
          tags: ['crime', 'dark', 'character study'],
          imageUrl: 'https://image.tmdb.org/t/p/w780/3xnWaLQjelJDDF7LT1WBo6f4BRe.jpg',
          source: 'tmdb',
          description: 'A chemistry teacher becomes involved in crime.',
          apiRating: 4.4,
        ),
        OnboardingMediaItem(
          id: '1399',
          title: 'Game of Thrones',
          domain: 'shows',
          genres: ['Drama', 'Fantasy', 'Adventure'],
          tags: ['kingdoms', 'power', 'war'],
          imageUrl: 'https://image.tmdb.org/t/p/w780/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg',
          source: 'tmdb',
          description: 'Noble families fight for power.',
          apiRating: 4.2,
        ),
      ];
    }

    if (domain == 'games') {
      return const [
        OnboardingMediaItem(
          id: '3328',
          title: 'The Witcher 3: Wild Hunt',
          domain: 'games',
          genres: ['RPG', 'Adventure'],
          tags: ['fantasy', 'open world', 'story'],
          imageUrl: 'https://media.rawg.io/media/games/618/618c2031a07bbff6b4f611f10b6bcdbc.jpg',
          source: 'rawg',
          description: 'A fantasy RPG following Geralt of Rivia.',
          apiRating: 4.65,
        ),
        OnboardingMediaItem(
          id: '3498',
          title: 'Grand Theft Auto V',
          domain: 'games',
          genres: ['Action', 'Adventure'],
          tags: ['open world', 'crime', 'story'],
          imageUrl: 'https://media.rawg.io/media/games/20a/20aa03a10caedf99a672ef8ca56f5797.jpg',
          source: 'rawg',
          description: 'An open-world action game set in Los Santos.',
          apiRating: 4.47,
        ),
        OnboardingMediaItem(
          id: '4200',
          title: 'Portal 2',
          domain: 'games',
          genres: ['Puzzle', 'Platformer'],
          tags: ['puzzle', 'sci-fi', 'comedy'],
          imageUrl: 'https://media.rawg.io/media/games/2ba/2bac0e87a51a4090db76cc0e96bf9b67.jpg',
          source: 'rawg',
          description: 'A puzzle game built around portals.',
          apiRating: 4.6,
        ),
      ];
    }

    return const [
      OnboardingMediaItem(
        id: 'zyTCAlFPjgYC',
        title: 'The Hunger Games',
        domain: 'books',
        genres: ['Young Adult', 'Dystopian'],
        tags: ['survival', 'competition', 'rebellion'],
        imageUrl: 'https://books.google.com/books/content?id=zyTCAlFPjgYC&printsec=frontcover&img=1&zoom=2',
        source: 'google_books',
        description: 'A dystopian story about survival and rebellion.',
        apiRating: 4.3,
      ),
      OnboardingMediaItem(
        id: 'wrOQLV6xB-wC',
        title: 'Harry Potter and the Sorcerer’s Stone',
        domain: 'books',
        genres: ['Fantasy', 'Adventure'],
        tags: ['magic', 'school', 'friendship'],
        imageUrl: 'https://books.google.com/books/content?id=wrOQLV6xB-wC&printsec=frontcover&img=1&zoom=2',
        source: 'google_books',
        description: 'A young wizard discovers his magical world.',
        apiRating: 4.5,
      ),
      OnboardingMediaItem(
        id: 'i8WCDwAAQBAJ',
        title: 'The Hobbit',
        domain: 'books',
        genres: ['Fantasy', 'Adventure'],
        tags: ['quest', 'dragon', 'journey'],
        imageUrl: 'https://books.google.com/books/content?id=i8WCDwAAQBAJ&printsec=frontcover&img=1&zoom=2',
        source: 'google_books',
        description: 'Bilbo Baggins joins a journey to reclaim a mountain.',
        apiRating: 4.4,
      ),
    ];
  }

  Future<List<OnboardingMediaItem>> _fetchTmdbItems({
    required String type,
  }) async {
    final List<OnboardingMediaItem> collected = [];

    Future<void> addFromUrl(String url) async {
      if (collected.length >= 3) return;

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final results = (data['results'] as List?) ?? [];

      for (final json in results) {
        if (collected.length >= 3) break;

        final id = json['id'].toString();
        final posterPath = (json['poster_path'] ?? '').toString();

        if (id == widget.currentItem.id) continue;
        if (posterPath.isEmpty) continue;

        collected.add(
          OnboardingMediaItem(
            id: id,
            title: type == 'movie'
                ? (json['title'] ?? 'Untitled').toString()
                : (json['name'] ?? 'Untitled').toString(),
            domain: type == 'movie' ? 'movies' : 'shows',
            genres: widget.currentItem.genres,
            tags: widget.currentItem.tags,
            imageUrl: 'https://image.tmdb.org/t/p/w500$posterPath',
            source: 'tmdb',
            description: (json['overview'] ?? '').toString(),
            apiRating: ((json['vote_average'] ?? 0) as num).toDouble() / 2,
          ),
        );
      }
    }

    await addFromUrl(
      'https://api.themoviedb.org/3/$type/${widget.currentItem.id}/similar'
      '?api_key=$tmdbApiKey&page=1',
    );

    if (collected.length < 3) {
      final query = widget.currentItem.genres.isNotEmpty
          ? widget.currentItem.genres.first
          : widget.currentItem.title;

      await addFromUrl(
        'https://api.themoviedb.org/3/search/$type'
        '?api_key=$tmdbApiKey&query=${Uri.encodeComponent(query)}&page=1',
      );
    }

    if (collected.length < 3) {
      await addFromUrl(
        'https://api.themoviedb.org/3/$type/popular'
        '?api_key=$tmdbApiKey&page=1',
      );
    }

    if (collected.length < 3) {
      await addFromUrl(
        'https://api.themoviedb.org/3/trending/$type/week'
        '?api_key=$tmdbApiKey',
      );
    }

    return collected.take(3).toList();
  }

  Future<List<OnboardingMediaItem>> _fetchRawgItems() async {
    final List<OnboardingMediaItem> collected = [];

    Future<void> addFromUrl(String url) async {
      if (collected.length >= 3) return;

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final results = (data['results'] as List?) ?? [];

      for (final json in results) {
        if (collected.length >= 3) break;

        final id = json['id'].toString();
        final imageUrl = (json['background_image'] ?? '').toString();

        if (id == widget.currentItem.id) continue;
        if (imageUrl.isEmpty) continue;

        collected.add(
          OnboardingMediaItem(
            id: id,
            title: (json['name'] ?? 'Untitled').toString(),
            domain: 'games',
            genres: ((json['genres'] as List?) ?? [])
                .map((g) => (g['name'] ?? '').toString())
                .where((g) => g.isNotEmpty)
                .toList(),
            tags: ((json['tags'] as List?) ?? [])
                .take(5)
                .map((t) => (t['name'] ?? '').toString())
                .where((t) => t.isNotEmpty)
                .toList(),
            imageUrl: imageUrl,
            source: 'rawg',
            description: '',
            apiRating: ((json['rating'] ?? 0) as num).toDouble(),
          ),
        );
      }
    }

    final query = widget.currentItem.genres.isNotEmpty
        ? widget.currentItem.genres.first
        : widget.currentItem.title;

    await addFromUrl(
      'https://api.rawg.io/api/games'
      '?key=$rawgApiKey&search=${Uri.encodeComponent(query)}&page_size=10',
    );

    if (collected.length < 3) {
      await addFromUrl(
        'https://api.rawg.io/api/games'
        '?key=$rawgApiKey&ordering=-rating&page_size=10',
      );
    }

    if (collected.length < 3) {
      await addFromUrl(
        'https://api.rawg.io/api/games'
        '?key=$rawgApiKey&ordering=-added&page_size=10',
      );
    }

    return collected.take(3).toList();
  }

  Future<List<OnboardingMediaItem>> _fetchBookItems() async {
    final List<OnboardingMediaItem> collected = [];

    Future<void> addFromQuery(String query) async {
      if (collected.length >= 3) return;

      final url = Uri.parse(
        'https://www.googleapis.com/books/v1/volumes'
        '?q=${Uri.encodeComponent(query)}&maxResults=10',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final results = (data['items'] as List?) ?? [];

      for (final json in results) {
        if (collected.length >= 3) break;

        final id = (json['id'] ?? '').toString();
        final info = json['volumeInfo'] ?? {};
        final imageLinks = info['imageLinks'] ?? {};
        final imageUrl = (imageLinks['thumbnail'] ?? '').toString();

        if (id == widget.currentItem.id) continue;
        if (imageUrl.isEmpty) continue;

        collected.add(
          OnboardingMediaItem(
            id: id,
            title: (info['title'] ?? 'Untitled').toString(),
            domain: 'books',
            genres: ((info['categories'] as List?) ?? [])
                .map((e) => e.toString())
                .toList(),
            tags: ((info['categories'] as List?) ?? [])
                .map((e) => e.toString())
                .toList(),
            imageUrl: imageUrl,
            source: 'google_books',
            description: (info['description'] ?? '').toString(),
            apiRating: ((info['averageRating'] ?? 0) as num).toDouble(),
          ),
        );
      }
    }

    if (widget.currentItem.genres.isNotEmpty) {
      await addFromQuery('subject:${widget.currentItem.genres.first}');
    }

    if (collected.length < 3) {
      await addFromQuery(widget.currentItem.title);
    }

    if (collected.length < 3) {
      await addFromQuery('popular fiction');
    }

    if (collected.length < 3) {
      await addFromQuery('bestsellers');
    }

    return collected.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: FutureBuilder<List<OnboardingMediaItem>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'More like this',
                subtitle: 'Similar picks you might like',
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              else if (items.isEmpty)
                const SizedBox.shrink()
              else
                Row(
                  children: List.generate(items.length, (index) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index == items.length - 1 ? 0 : 18,
                        ),
                        child: _SimilarItemCard(item: items[index]),
                      ),
                    );
                  }),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SimilarItemCard extends StatelessWidget {
  final OnboardingMediaItem item;

  const _SimilarItemCard({
    required this.item,
  });

  String _highQualityImage(String url) {
    if (url.contains('image.tmdb.org/t/p/w500')) {
      return url.replaceAll('/w500/', '/w780/');
    }

    if (url.contains('books.google.com')) {
      return url.replaceAll('zoom=1', 'zoom=2');
    }

    return url;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _highQualityImage(item.imageUrl);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ItemDetailsScreen(item: item),
            ),
          );
        },
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            color: const Color(0xFF111114),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.trim().isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => _fallback(),
                  )
                else
                  _fallback(),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.18),
                          Colors.black.withOpacity(0.88),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.genres.isEmpty
                            ? item.domain
                            : item.genres.take(2).join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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

  Widget _fallback() {
    return Container(
      color: Colors.white.withOpacity(0.06),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white54,
          size: 28,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  static const Color _accent = Color(0xFFFF8B3D);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  static const Color _accent = Color(0xFFFF8B3D);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? _accent : Colors.white.withOpacity(0.11),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 49,
            height: 49,
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.65,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.40),
            fontSize: 12.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white.withOpacity(0.68),
          fontSize: 12.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DomainPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DomainPill({
    required this.icon,
    required this.label,
  });

  static const Color _accent = Color(0xFFFF8B3D);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _accent.withOpacity(0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _accent, size: 13),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _accent,
              fontSize: 10.8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}