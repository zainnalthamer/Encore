import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/onboarding_media_item.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/social_service.dart';
import '../../items/screens/item_details_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final SocialService _socialService = SocialService();

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
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
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

  Widget _buildSectionContent({
    required bool isOwnProfile,
    required String profileUid,
  }) {
    switch (_selectedSection) {
      case 'Favorites':
        return _FavoritesSection(profileUid: profileUid);

      case 'Shelves':
        return _ShelvesSection(
          profileUid: profileUid,
          isOwnProfile: isOwnProfile,
        );

      case 'Activity':
        return _ActivitySection(profileUid: profileUid);

      case 'Saved':
        return _SavedSection(profileUid: profileUid);

      default:
        return const SizedBox.shrink();
    }
  }

  List<String> _safeStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final profileUid = widget.userId ?? currentUid;
    final isOwnProfile = currentUid != null && profileUid == currentUid;

    if (profileUid == null) {
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
            .doc(profileUid)
            .snapshots(),
        builder: (context, snapshot) {
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

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
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
          final photoUrl = (userData['photoUrl'] ?? userData['avatarUrl'] ?? '')
              .toString()
              .trim();
          final headerImageUrl =
              (userData['headerImageUrl'] ?? '').toString().trim();

          final followersList = _safeStringList(userData['followers']);
          final followingList = _safeStringList(userData['following']);

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
                            isOwnProfile: isOwnProfile,
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
                                if (isOwnProfile)
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
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF121217),
                                            border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.08),
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
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
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
                                      value: followersList.length.toString(),
                                      label: 'Followers',
                                    ),
                                    _CountTextBlock(
                                      value: followingList.length.toString(),
                                      label: 'Following',
                                    ),
                                  ],
                                ),
                                if (!isOwnProfile && currentUid != null) ...[
                                  const SizedBox(height: 22),
                                  _FollowButton(
                                    targetUid: profileUid,
                                    currentUid: currentUid,
                                    followers: followersList,
                                    socialService: _socialService,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 34),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1080),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (int i = 0;
                                        i < _sections.length;
                                        i++) ...[
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
                                              color:
                                                  Colors.white.withOpacity(0.22),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 30),
                                _buildSectionContent(
                                  isOwnProfile: isOwnProfile,
                                  profileUid: profileUid,
                                ),
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

class _ShelvesSection extends StatelessWidget {
  final String profileUid;
  final bool isOwnProfile;

  const _ShelvesSection({
    required this.profileUid,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(profileUid)
        .collection('shelves')
        .orderBy('updatedAt', descending: true);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ref.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _SectionSurface(
                child: _LargeInfoBlock(
                  title: 'Could not load shelves',
                  body: 'Check Firestore rules or shelf data.',
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const _SectionSurface(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: _LargeInfoBlock(
                    title: 'No shelves yet',
                    body: 'Create collections for movies, shows, books, and games.',
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 86),
              child: _ShelvesGrid(
                docs: docs,
                isOwnProfile: isOwnProfile,
              ),
            );
          },
        ),
        if (isOwnProfile)
          Positioned(
            right: 10,
            bottom: 10,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFFFF8B3D),
              foregroundColor: Colors.black,
              elevation: 10,
              shape: const CircleBorder(),
              onPressed: () => _showCreateShelfPopup(context, profileUid),
              child: const Icon(Icons.add_rounded, size: 32),
            ),
          ),
      ],
    );
  }
}

class _ShelvesGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool isOwnProfile;

  const _ShelvesGrid({
    required this.docs,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final count = width >= 1100
            ? 5
            : width >= 900
                ? 4
                : width >= 650
                    ? 3
                    : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 20,
            mainAxisSpacing: 30,
            childAspectRatio: 0.68,
          ),
          itemBuilder: (context, index) {
            return _ShelfBoardCard(
              shelfId: docs[index].id,
              data: docs[index].data(),
              isOwnProfile: isOwnProfile,
            );
          },
        );
      },
    );
  }
}

class _ShelfBoardCard extends StatelessWidget {
  final String shelfId;
  final Map<String, dynamic> data;
  final bool isOwnProfile;

  const _ShelfBoardCard({
    required this.shelfId,
    required this.data,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Untitled shelf').toString();
    final description = (data['description'] ?? '').toString().trim();
    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    final itemsCountRaw = data['itemsCount'];
    final itemsCount = itemsCountRaw is num ? itemsCountRaw.toInt() : 0;

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shelf screen will be added next.')),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => _shelfFallback(),
                      )
                    : _shelfFallback(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$itemsCount ${itemsCount == 1 ? 'item' : 'items'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.48),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.44),
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _shelfFallback() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF18181D),
      ),
      child: Center(
        child: Icon(
          Icons.grid_view_rounded,
          color: Colors.white.withOpacity(0.28),
          size: 36,
        ),
      ),
    );
  }
}

Future<void> _showCreateShelfPopup(
  BuildContext context,
  String profileUid,
) async {
  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.78),
    builder: (_) => _CreateShelfDialog(profileUid: profileUid),
  );
}

class _CreateShelfDialog extends StatefulWidget {
  final String profileUid;

  const _CreateShelfDialog({
    required this.profileUid,
  });

  @override
  State<_CreateShelfDialog> createState() => _CreateShelfDialogState();
}

class _CreateShelfDialogState extends State<_CreateShelfDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickShelfImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (!mounted) return;

    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = picked.name;
    });
  }

  Future<String> _uploadShelfImageAfterCreate(String shelfId) async {
  if (_selectedImageBytes == null) return '';

  final safeFileName =
      (_selectedImageName == null || _selectedImageName!.trim().isEmpty)
          ? 'cover.jpg'
          : _selectedImageName!.replaceAll(' ', '_');

  final ref = FirebaseStorage.instance
      .ref()
      .child('shelves')
      .child(widget.profileUid)
      .child(shelfId)
      .child(safeFileName);

  await ref.putData(
    _selectedImageBytes!,
    SettableMetadata(contentType: 'image/jpeg'),
  );

  return ref.getDownloadURL();
}

  // Future<String> _tryUploadShelfImage(String shelfId) async {
  //   if (_selectedImageBytes == null) return '';

  //   try {
  //     final safeFileName =
  //         (_selectedImageName == null || _selectedImageName!.trim().isEmpty)
  //             ? 'cover.jpg'
  //             : _selectedImageName!.replaceAll(' ', '_');

  //     final ref = FirebaseStorage.instance
  //         .ref()
  //         .child('shelves')
  //         .child(widget.profileUid)
  //         .child(shelfId)
  //         .child(safeFileName);

  //     await ref.putData(
  //       _selectedImageBytes!,
  //       SettableMetadata(contentType: 'image/jpeg'),
  //     );

  //     return await ref.getDownloadURL();
  //   } catch (_) {
  //     return '';
  //   }
  // }

  Future<void> _createShelf() async {
  final name = _nameController.text.trim();
  final description = _descriptionController.text.trim();
  final currentUid = FirebaseAuth.instance.currentUser?.uid;

  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shelf name is required.')),
    );
    return;
  }

  if (currentUid == null || currentUid != widget.profileUid) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You can only create shelves on your profile.')),
    );
    return;
  }

  setState(() => _saving = true);

  final shelfRef = FirebaseFirestore.instance
      .collection('users')
      .doc(widget.profileUid)
      .collection('shelves')
      .doc();

  try {
    await shelfRef.set({
      'name': name,
      'description': description,
      'imageUrl': '',
      'imageSource': 'empty',
      'itemIds': <String>[],
      'itemsCount': 0,
      'ownerId': widget.profileUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (_selectedImageBytes != null) {
      try {
        final imageUrl = await _uploadShelfImageAfterCreate(shelfRef.id)
            .timeout(const Duration(seconds: 12));

        if (imageUrl.isNotEmpty) {
          await shelfRef.update({
            'imageUrl': imageUrl,
            'imageSource': 'uploaded',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shelf created.')),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not create shelf: $e')),
    );
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 680;

    return Dialog(
      backgroundColor: const Color(0xFF101014),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Create shelf',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _saving ? null : () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                compact
                    ? Column(
                        children: [
                          Center(child: _ShelfCoverPicker()),
                          const SizedBox(height: 22),
                          _MinimalShelfField(
                            controller: _nameController,
                            label: 'Name',
                            hint: 'comfort rotation',
                          ),
                          const SizedBox(height: 14),
                          _MinimalShelfField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'The safe picks I always come back to',
                            maxLines: 4,
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShelfCoverPicker(),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              children: [
                                _MinimalShelfField(
                                  controller: _nameController,
                                  label: 'Name',
                                  hint: 'comfort rotation',
                                ),
                                const SizedBox(height: 14),
                                _MinimalShelfField(
                                  controller: _descriptionController,
                                  label: 'Description',
                                  hint: 'The safe picks I always come back to',
                                  maxLines: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _createShelf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8B3D),
                      disabledBackgroundColor:
                          const Color(0xFFFF8B3D).withOpacity(0.55),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Text(
                            'Create shelf',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ShelfCoverPicker() {
    return InkWell(
      onTap: _saving ? null : _pickShelfImage,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: 210,
        height: 210,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: _selectedImageBytes != null
              ? Image.memory(
                  _selectedImageBytes!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                )
              : Container(
                  color: const Color(0xFF1B1B21),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        color: Colors.white.withOpacity(0.72),
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Add cover',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _MinimalShelfField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _MinimalShelfField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.65),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          cursorColor: const Color(0xFFFF8B3D),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.30),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: const Color(0xFF1A1A20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.20)),
            ),
          ),
        ),
      ],
    );
  }
}
class _FollowButton extends StatefulWidget {
  final String targetUid;
  final String currentUid;
  final List<String> followers;
  final SocialService socialService;

  const _FollowButton({
    required this.targetUid,
    required this.currentUid,
    required this.followers,
    required this.socialService,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final isFollowing = widget.followers.contains(widget.currentUid);

    return InkWell(
      onTap: _loading
          ? null
          : () async {
              setState(() => _loading = true);

              try {
                await widget.socialService.toggleFollow(
                  targetUid: widget.targetUid,
                  isFollowing: isFollowing,
                );
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
        decoration: BoxDecoration(
          color: isFollowing
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFFF8B3D),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isFollowing
                ? Colors.white.withOpacity(0.13)
                : const Color(0xFFFF8B3D),
          ),
        ),
        child: Text(
          _loading
              ? '...'
              : isFollowing
                  ? 'Following'
                  : 'Follow',
          style: GoogleFonts.inter(
            color: isFollowing ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ProfileTopNav extends StatelessWidget {
  final VoidCallback onMenuTap;
  final bool isOwnProfile;

  const _ProfileTopNav({
    required this.onMenuTap,
    required this.isOwnProfile,
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
            if (isOwnProfile) ...[
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
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.58),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
class _FavoritesSection extends StatelessWidget {
  final String profileUid;

  const _FavoritesSection({
    required this.profileUid,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(profileUid)
        .collection('libraryItems')
        .where('isFavorite', isEqualTo: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'Could not load favorites',
              body: 'Check Firestore rules or item data.',
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'No favorites yet',
              body: 'Favorite items will appear here.',
            ),
          );
        }

        return _LibraryItemsGrid(docs: docs);
      },
    );
  }
}

class _SavedSection extends StatelessWidget {
  final String profileUid;

  const _SavedSection({
    required this.profileUid,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(profileUid)
        .collection('libraryItems')
        .where('isSaved', isEqualTo: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'Could not load saved items',
              body: 'Check Firestore rules or item data.',
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'No saved items',
              body: 'Saved items will appear here.',
            ),
          );
        }

        return _LibraryItemsGrid(docs: docs);
      },
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final String profileUid;

  const _ActivitySection({
    required this.profileUid,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(profileUid)
        .collection('activity')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'Could not load activity',
              body: 'Check Firestore rules or activity data.',
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _SectionSurface(
            child: _LargeInfoBlock(
              title: 'No activity yet',
              body: 'User activity will appear here.',
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            return _ActivityCard(data: doc.data());
          }).toList(),
        );
      },
    );
  }
}
class _LibraryItemsGrid extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const _LibraryItemsGrid({
    required this.docs,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final count = width >= 1200
            ? 6
            : width >= 1000
                ? 5
                : width >= 800
                    ? 4
                    : width >= 600
                        ? 3
                        : 2;

        final itemWidth = (width - ((count - 1) * 16)) / count;
        final itemHeight = itemWidth / 0.66 + 110;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 16,
            mainAxisSpacing: 32,
            childAspectRatio: itemWidth / itemHeight,
          ),
          itemBuilder: (context, index) {
            return _LibraryItemCard(data: docs[index].data());
          },
        );
      },
    );
  }
}

class _LibraryItemCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _LibraryItemCard({
    required this.data,
  });

  OnboardingMediaItem _toItem() {
    return OnboardingMediaItem(
      id: (data['itemId'] ?? '').toString(),
      title: (data['title'] ?? 'Untitled').toString(),
      domain: (data['domain'] ?? '').toString(),
      genres: ((data['genres'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      tags: ((data['tags'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      source: (data['source'] ?? 'library').toString(),
      description: (data['description'] ?? '').toString(),
    );
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
        return 'Item';
    }
  }

  IconData _domainIcon(String domain) {
    switch (domain) {
      case 'movies':
        return Icons.local_movies_rounded;
      case 'shows':
        return Icons.tv_rounded;
      case 'books':
        return Icons.menu_book_rounded;
      case 'games':
        return Icons.sports_esports_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  double _parseRating(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final item = _toItem();

    final rating = _parseRating(
      data['userRating'] ?? data['rating'] ?? data['latestRating'],
    );

    final review =
        (data['review'] ?? data['lastReview'] ?? data['latestReview'] ?? '')
            .toString()
            .trim();

    final status = (data['status'] ?? _defaultStatus(item.domain)).toString();

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
            Expanded(
              flex: 72,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: item.imageUrl.trim().isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => _posterFallback(),
                            )
                          : _posterFallback(),
                    ),
                  ),
                  Positioned(
                    left: 9,
                    top: 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.42),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _domainIcon(item.domain),
                                color: Colors.white,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _domainLabel(item.domain),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 7),
            _MiniStars(rating: rating),
            const SizedBox(height: 7),
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFFFF8B3D),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 44,
              child: Text(
                review.isEmpty ? 'No review yet.' : review,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: review.isEmpty
                      ? Colors.white.withOpacity(0.35)
                      : Colors.white.withOpacity(0.55),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white.withOpacity(0.06),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white54),
      ),
    );
  }
}

class _MiniStars extends StatelessWidget {
  final double rating;

  const _MiniStars({
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return Row(
        children: [
          Icon(
            Icons.star_border_rounded,
            color: Colors.white.withOpacity(0.42),
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            'No rating',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.50),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded,
            color: const Color(0xFFFF8B3D),
            size: 15,
          ),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.74),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ActivityCard({
    required this.data,
  });

  double _parseRating(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _activityLabel(String type) {
    switch (type) {
      case 'favorite':
      case 'favorited':
        return 'Favorited';
      case 'saved':
      case 'save':
        return 'Saved';
      case 'review':
      case 'reviewed':
        return 'Reviewed';
      case 'rating':
      case 'rated':
        return 'Rated';
      default:
        return 'Updated';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Untitled').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final type = (data['activityType'] ?? data['type'] ?? 'updated').toString();

    final rating = _parseRating(data['userRating'] ?? data['rating']);
    final review = (data['review'] ?? data['text'] ?? '').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 52,
                    height: 72,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => _activityImageFallback(),
                  )
                : _activityImageFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activityLabel(type).toUpperCase(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF8B3D),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (rating > 0) ...[
                  const SizedBox(height: 5),
                  _MiniStars(rating: rating),
                ],
                if (review.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    review,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
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
      child: const Icon(Icons.image, color: Colors.white38),
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
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(26),
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

  const _LargeInfoBlock({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}