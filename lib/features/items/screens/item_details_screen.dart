import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
                    _QuickStats(
                      userRating: _userRating,
                      saved: _saved,
                      favorite: _favorite,
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
                    const _SimilarSection(),
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

class _QuickStats extends StatelessWidget {
  final double userRating;
  final bool saved;
  final bool favorite;

  const _QuickStats({
    required this.userRating,
    required this.saved,
    required this.favorite,
  });

  @override
  Widget build(BuildContext context) {
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
              title: userRating <= 0 ? '-' : userRating.toStringAsFixed(1),
              subtitle: 'Your rating',
              icon: Icons.star_rounded,
            ),
          ),
          const _SoftDivider(),
          Expanded(
            child: _StatTile(
              title: saved ? 'Yes' : 'No',
              subtitle: 'Saved',
              icon: Icons.bookmark_rounded,
            ),
          ),
          const _SoftDivider(),
          Expanded(
            child: _StatTile(
              title: favorite ? 'Yes' : 'No',
              subtitle: 'Favorite',
              icon: Icons.workspace_premium_rounded,
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
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
              if (snapshot.connectionState == ConnectionState.waiting)
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
                    final rating = ((data['rating'] ?? 0) as num).toDouble();
                    final review = (data['review'] ?? '').toString();

                    return _CommunityReviewTile(
                      name: name,
                      username: username,
                      photoUrl: photoUrl,
                      rating: rating,
                      review: review,
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
  final VoidCallback onTap;

  const _CommunityReviewTile({
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.rating,
    required this.review,
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

class _SimilarSection extends StatelessWidget {
  const _SimilarSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'More like this',
            subtitle: 'Similar mood and genre',
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 10),
                  height: 105,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.movie_creation_outlined,
                      color: Colors.white.withOpacity(0.26),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
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
      padding: const EdgeInsets.all(18),
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