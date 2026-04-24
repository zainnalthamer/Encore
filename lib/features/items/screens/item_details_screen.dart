import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
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
  bool _liked = false;
  bool _favorite = false;
  late String _status;

  static const Color _accent = Color(0xFFFF8B3D);
  static const Color _bg = Color(0xFF050507);

  @override
  void initState() {
    super.initState();
    _status = _defaultStatus(widget.item.domain);
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
                  'Add to shelf',
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
                  onTap: () {
                    setState(() => _status = status);
                    Navigator.pop(context);
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
                liked: _liked,
                favorite: _favorite,
                status: _status,
                domainLabel: _domainLabel,
                domainIcon: _domainIcon,
                onLike: () => setState(() => _liked = !_liked),
                onFavorite: () => setState(() => _favorite = !_favorite),
                onStatus: _showStatusSheet,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _QuickStats(),
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
                    _AvailabilityCard(
                      title: _availabilityTitle(item.domain),
                      providers: providers,
                    ),
                    const SizedBox(height: 16),
                    const _ReviewPreviewCard(),
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
  final bool liked;
  final bool favorite;
  final String status;
  final String Function(String) domainLabel;
  final IconData Function(String) domainIcon;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onStatus;

  const _HeroSection({
    required this.item,
    required this.liked,
    required this.favorite,
    required this.status,
    required this.domainLabel,
    required this.domainIcon,
    required this.onLike,
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
                        Row(
                          children: [
                            _PrimaryButton(
                              label: status,
                              icon: Icons.add_rounded,
                              onTap: onStatus,
                            ),
                            const SizedBox(width: 12),
                            _CircleAction(
                              icon: liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              active: liked,
                              onTap: onLike,
                            ),
                            const SizedBox(width: 10),
                            _CircleAction(
                              icon: favorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              active: favorite,
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
  const _QuickStats();

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
        children: const [
          Expanded(
            child: _StatTile(
              title: '8.7',
              subtitle: 'Rating',
              icon: Icons.star_rounded,
            ),
          ),
          _SoftDivider(),
          Expanded(
            child: _StatTile(
              title: '94%',
              subtitle: 'Match',
              icon: Icons.bolt_rounded,
            ),
          ),
          _SoftDivider(),
          Expanded(
            child: _StatTile(
              title: '12K',
              subtitle: 'Saved',
              icon: Icons.bookmark_rounded,
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

class _ReviewPreviewCard extends StatelessWidget {
  const _ReviewPreviewCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Reviews',
            subtitle: 'Your thoughts and community notes',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  color: Colors.white.withOpacity(0.58),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Write a review or add a quick reflection later.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.58),
                      fontSize: 13.5,
                      height: 1.45,
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
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  static const Color _accent = Color(0xFFFF8B3D);

  @override
  Widget build(BuildContext context) {
    return Material(
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
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

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