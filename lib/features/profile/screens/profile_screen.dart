import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/auth_service.dart';
import 'edit_profile_screen.dart';
import '../../settings/screens/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        ),
      );
      return;
    }

    if (result == 'analytics') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analytics will be added next.'),
        ),
      );
      return;
    }

    if (result == 'logout') {
      await _authService.logout();
      return;
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
    final favoriteItemIds =
        (userData['favoriteItemIds'] as Map<String, dynamic>?) ?? {};

    final movies = (favoriteItemIds['movies'] as List?)?.length ?? 0;
    final shows = (favoriteItemIds['shows'] as List?)?.length ?? 0;
    final books = (favoriteItemIds['books'] as List?)?.length ?? 0;
    final games = (favoriteItemIds['games'] as List?)?.length ?? 0;

    final derived =
        (userData['derivedPreferences'] as Map<String, dynamic>?) ?? {};
    final topGenres =
        ((derived['topGenres'] as List?) ?? []).map((e) => e.toString()).toList();
    final favoriteDomains = ((derived['favoriteDomains'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();

    switch (_selectedSection) {
      case 'Favorites':
        return _SectionSurface(
          child: Column(
            children: [
              _InfoRow(
                label: 'Movies',
                value: movies.toString(),
                accent: const Color(0xFFFF9E57),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Shows',
                value: shows.toString(),
                accent: const Color(0xFF8CAFFF),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Books',
                value: books.toString(),
                accent: const Color(0xFFF0C46A),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Games',
                value: games.toString(),
                accent: const Color(0xFF63D8AE),
              ),
            ],
          ),
        );

      case 'Shelves':
        return const _SectionSurface(
          child: _LargeInfoBlock(
            title: 'Shelves will live here',
            body:
                'Create custom collections for moods, franchises, genres, or personal themes later.',
          ),
        );

      case 'Activity':
        return _SectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TagBlock(
                title: 'Top genres',
                tags: topGenres,
              ),
              const SizedBox(height: 18),
              _TagBlock(
                title: 'Favorite domains',
                tags: favoriteDomains,
              ),
            ],
          ),
        );

      case 'Saved':
        return const _SectionSurface(
          child: _LargeInfoBlock(
            title: 'Nothing saved yet',
            body:
                'Items you want to come back to later can appear here once you start saving them.',
          ),
        );

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
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
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
              (userData['displayName'] ?? userData['name'] ?? 'User').toString();
          final username = (userData['username'] ?? '').toString().trim();
          final bio = (userData['bio'] ?? '').toString().trim();
          final photoUrl = (userData['photoUrl'] ?? '').toString().trim();
          final headerImageUrl =
              (userData['headerImageUrl'] ?? '').toString().trim();

          final followers = ((userData['followers'] as List?) ?? []).length;
          final following = ((userData['following'] as List?) ?? []).length;

          return Stack(
            children: [
              Positioned.fill(
                child: Container(color: const Color(0xFF050507)),
              ),
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
                                            builder: (context) =>
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
                                            color: Colors.white.withOpacity(0.08),
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
                          const SizedBox(height:5),
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
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (int i = 0; i < _sections.length; i++) ...[
                                      _TopSectionTab(
                                        label: _sections[i],
                                        selected: _selectedSection == _sections[i],
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
                                              color: Colors.white.withOpacity(0.22),
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
          colors: [
            Color(0xFF0C0C10),
            Color(0xFF111118),
            Color(0xFF171724),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String displayName) {
    final first =
        displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : 'U';

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

class _ProfileTopNav extends StatelessWidget {
  final VoidCallback onMenuTap;

  const _ProfileTopNav({
    required this.onMenuTap,
  });

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
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 24),
            _TopTextButton(
              label: 'Discover',
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 24),
            const _TopTextButton(
              label: 'Profile',
              active: true,
            ),
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

  const _TopTextButton({
    required this.label,
    this.onTap,
    this.active = false,
  });

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

  const _CountTextBlock({
    required this.value,
    required this.label,
  });

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

  const _SectionSurface({
    required this.child,
  });

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
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.86),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeInfoBlock extends StatelessWidget {
  final String title;
  final String body;

  const _LargeInfoBlock({
    required this.title,
    required this.body,
  });

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

class _TagBlock extends StatelessWidget {
  final String title;
  final List<String> tags;

  const _TagBlock({
    required this.title,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (tags.isEmpty)
            Text(
              'Nothing here yet',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13.5,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w600,
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