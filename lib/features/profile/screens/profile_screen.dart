import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_library_service.dart';
import '../../items/screens/item_details_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserLibraryService _libraryService = UserLibraryService();

  String _selectedSection = 'Favorites';

  final List<String> _sections = const [
    'Favorites',
    'Shelves',
    'Activity',
    'Saved',
  ];

  Future<void> _openMenu(BuildContext context) async {
    final result = await showMenu<String>(
      context: context,
      color: const Color(0xFF0B0B10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      position: const RelativeRect.fromLTRB(1000, 86, 24, 0),
      items: [
        PopupMenuItem(
          value: 'settings',
          child: _menuItem(Icons.settings_outlined, 'Settings'),
        ),
        PopupMenuItem(
          value: 'analytics',
          child: _menuItem(Icons.insights_outlined, 'Analytics'),
        ),
        PopupMenuItem(
          value: 'logout',
          child: _menuItem(Icons.logout_rounded, 'Log out', destructive: true),
        ),
      ],
    );

    if (!mounted || result == null) return;

    if (result == 'settings') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      return;
    }

    if (result == 'analytics') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analytics will be added next.')),
      );
      return;
    }

    if (result == 'logout') {
      await _authService.logout();
    }
  }

  Widget _menuItem(IconData icon, String label, {bool destructive = false}) {
    final color = destructive ? const Color(0xFFFF8EA1) : Colors.white;

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(Map<String, dynamic> userData) {
    switch (_selectedSection) {
      case 'Favorites':
        return _FavoritesSection(libraryService: _libraryService);

      case 'Shelves':
        return const _SectionSurface(
          child: _LargeInfoBlock(
            title: 'Shelves will live here',
            body:
                'Create custom collections for moods, franchises, genres, or personal themes later.',
          ),
        );

      case 'Activity':
        return _ActivitySection(libraryService: _libraryService);

      case 'Saved':
        return _SavedSection(libraryService: _libraryService);

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF050507),
        body: Center(
          child: Text(
            'No user found.',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load profile.',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final userData = snapshot.data?.data();

          if (userData == null) {
            return Center(
              child: Text(
                'Profile data not found.',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final displayName =
              (userData['displayName'] ?? userData['name'] ?? 'User')
                  .toString();
          final username = (userData['username'] ?? '').toString().trim();
          final bio = (userData['bio'] ?? '').toString().trim();
          final photoUrl = (userData['photoUrl'] ?? '').toString().trim();
          final headerImageUrl = (userData['headerImageUrl'] ?? '')
              .toString()
              .trim();

          final followers = ((userData['followers'] as List?) ?? []).length;
          final following = ((userData['following'] as List?) ?? []).length;

          return Stack(
            children: [
              Positioned.fill(child: Container(color: const Color(0xFF050507))),
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          height: 300,
                          width: double.infinity,
                          child: headerImageUrl.isNotEmpty
                              ? Image.network(
                                  headerImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _headerFallback(),
                                )
                              : _headerFallback(),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.52),
                                  Colors.black.withOpacity(0.18),
                                  Colors.black.withOpacity(0.72),
                                  Colors.black.withOpacity(0.98),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _ProfileTopNav(
                            onMenuTap: () => _openMenu(context),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 18,
                          child: Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 116,
                                  height: 116,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF121217),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.32),
                                        blurRadius: 24,
                                        offset: const Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: photoUrl.isNotEmpty
                                        ? Image.network(
                                            photoUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _avatarFallback(displayName),
                                          )
                                        : _avatarFallback(displayName),
                                  ),
                                ),
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const EditProfileScreen(),
                                            fullscreenDialog: true,
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF121217),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.08,
                                            ),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                      child: Column(
                        children: [
                          const SizedBox(height: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Column(
                              children: [
                                Text(
                                  displayName,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.1,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (username.isNotEmpty)
                                  Text(
                                    '@$username',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.70),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: 680,
                                  child: Text(
                                    bio.isNotEmpty ? bio : 'No bio added yet.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.62),
                                      fontSize: 14.5,
                                      height: 1.65,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 28,
                                  runSpacing: 12,
                                  children: [
                                    _CountTextBlock(
                                      value: followers.toString(),
                                      label: 'Followers',
                                    ),
                                    _CountTextBlock(
                                      value: following.toString(),
                                      label: 'Following',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 34),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (
                                      int i = 0;
                                      i < _sections.length;
                                      i++
                                    ) ...[
                                      _TopSectionTab(
                                        label: _sections[i],
                                        selected:
                                            _selectedSection == _sections[i],
                                        onTap: () {
                                          setState(() {
                                            _selectedSection = _sections[i];
                                          });
                                        },
                                      ),
                                      if (i != _sections.length - 1)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          child: Text(
                                            '|',
                                            style: GoogleFonts.inter(
                                              color: Colors.white.withOpacity(
                                                0.22,
                                              ),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 26),
                                _buildSectionContent(userData),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C0C10), Color(0xFF111118), Color(0xFF171724)],
        ),
      ),
    );
  }

  Widget _avatarFallback(String displayName) {
    final first = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'U';

    return Container(
      color: const Color(0xFF141419),
      child: Center(
        child: Text(
          first,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  final UserLibraryService libraryService;

  const _FavoritesSection({required this.libraryService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: libraryService.watchFavorites(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionSurface(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'Unable to load favorites',
              body: 'Check your Firestore rules for users/{uid}/libraryItems.',
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'No favorites yet',
              body:
                  'Favorite items will appear here with your rating and review.',
            ),
          );
        }

        return _SectionSurface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final count = width > 820
                  ? 5
                  : width > 620
                  ? 4
                  : 2;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.48,
                ),
                itemBuilder: (context, index) {
                  return _FavoriteItemCard(data: docs[index].data());
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SavedSection extends StatelessWidget {
  final UserLibraryService libraryService;

  const _SavedSection({required this.libraryService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: libraryService.watchSaved(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionSurface(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'Unable to load saved items',
              body: 'Check your Firestore rules for users/{uid}/libraryItems.',
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'No saved items yet',
              body: 'Items you save will appear here for easy access later.',
            ),
          );
        }

        return _SectionSurface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final count = width > 820
                  ? 5
                  : width > 620
                  ? 4
                  : 2;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.48,
                ),
                itemBuilder: (context, index) {
                  return _FavoriteItemCard(data: docs[index].data());
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _FavoriteItemCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _FavoriteItemCard({required this.data});

  OnboardingMediaItem _toItem() {
    return OnboardingMediaItem(
      id: (data['itemId'] ?? '').toString(),
      title: (data['title'] ?? 'Untitled').toString(),
      domain: (data['domain'] ?? '').toString(),
      genres: ((data['genres'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      tags: ((data['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      source: 'library',
      description: (data['description'] ?? '').toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _toItem();
    final rating = ((data['userRating'] ?? 0) as num).toDouble();
    final review = (data['review'] ?? '').toString();
    final status = (data['status'] ?? '').toString();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item)),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _posterFallback(),
                      )
                    : _posterFallback(),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.8,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFF8B3D),
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  rating <= 0 ? 'No rating' : rating.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF8B3D).withOpacity(0.82),
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (review.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                review,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.46),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      width: double.infinity,
      color: Colors.white.withOpacity(0.06),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white54),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final UserLibraryService libraryService;

  const _ActivitySection({required this.libraryService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: libraryService.watchActivity(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionSurface(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'Unable to load activity',
              body:
                  'Check your Firestore index/rules for users/{uid}/libraryItems.',
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'No activity yet',
              body:
                  'Likes, favorites, ratings, reviews, and status updates will show here.',
            ),
          );
        }

        return _SectionSurface(
          child: Column(
            children: docs.map((doc) {
              final data = doc.data();
              return _ActivityCard(data: data);
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ActivityCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Untitled').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final activityType = (data['activityType'] ?? 'updated').toString();
    final rating = ((data['userRating'] ?? 0) as num).toDouble();
    final review = (data['review'] ?? '').toString();
    final status = (data['status'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.045)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 52,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _activityImageFallback(),
                  )
                : _activityImageFallback(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activityType.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF8B3D),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.58),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (rating > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rated ${rating.toStringAsFixed(1)} / 5',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.58),
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (review.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    review,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.52),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityImageFallback() {
    return Container(
      width: 52,
      height: 72,
      color: Colors.white.withOpacity(0.06),
      child: const Icon(Icons.image_outlined, color: Colors.white38, size: 20),
    );
  }
}

class _ProfileTopNav extends StatelessWidget {
  final VoidCallback onMenuTap;

  const _ProfileTopNav({required this.onMenuTap});

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
            Colors.black.withOpacity(0.90),
            Colors.black.withOpacity(0.60),
            Colors.black.withOpacity(0.16),
            Colors.transparent,
          ],
          stops: const [0.0, 0.38, 0.74, 1.0],
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
            _TopTextButton(
              label: 'Home',
              onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
            ),
            const SizedBox(width: 24),
            _TopTextButton(
              label: 'Discover',
              onTap: () =>
                  Navigator.of(context).pushReplacementNamed('/discover'),
            ),
            const SizedBox(width: 24),
            const _TopTextButton(label: 'Profile', active: true),
            const SizedBox(width: 18),
            InkWell(
              onTap: onMenuTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.layers_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const _TopTextButton({required this.label, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? Colors.white : Colors.white.withOpacity(0.74),
            fontSize: 14.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TopSectionTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopSectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? Colors.white : Colors.white.withOpacity(0.46),
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CountTextBlock extends StatelessWidget {
  final String value;
  final String label;

  const _CountTextBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.58),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectionSurface extends StatelessWidget {
  final Widget child;

  const _SectionSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LargeInfoBlock extends StatelessWidget {
  final String title;
  final String body;

  const _LargeInfoBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.62),
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
