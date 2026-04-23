import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/tmdb_image_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final TmdbImageService _tmdbImageService = TmdbImageService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingHeader = false;
  bool _isLoadingBackdrops = false;
  bool _hasChanges = false;

  String _photoUrl = '';
  String _headerUrl = '';
  String _initialPhotoUrl = '';
  String _initialHeaderUrl = '';
  String _initialName = '';
  String _initialBio = '';

  List<String> _tmdbBackdrops = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _nameController.addListener(_updateDirtyState);
    _bioController.addListener(_updateDirtyState);
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      _initialName = (data['displayName'] ?? data['name'] ?? '').toString();
      _initialBio = (data['bio'] ?? '').toString();
      _initialPhotoUrl = (data['photoUrl'] ?? '').toString();
      _initialHeaderUrl = (data['headerImageUrl'] ?? '').toString();

      _nameController.text = _initialName;
      _bioController.text = _initialBio;
      _photoUrl = _initialPhotoUrl;
      _headerUrl = _initialHeaderUrl;
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _updateDirtyState();
      await _loadTmdbBackdrops();
    }
  }

  Future<void> _loadTmdbBackdrops() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBackdrops = true;
    });

    try {
      final items = await _tmdbImageService.getHeaderBackdrops();
      if (!mounted) return;
      setState(() {
        _tmdbBackdrops = items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tmdbBackdrops = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingBackdrops = false;
      });
    }
  }

  void _updateDirtyState() {
    final changed = _nameController.text.trim() != _initialName.trim() ||
        _bioController.text.trim() != _initialBio.trim() ||
        _photoUrl.trim() != _initialPhotoUrl.trim() ||
        _headerUrl.trim() != _initialHeaderUrl.trim();

    if (changed != _hasChanges && mounted) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final url = await _cloudinaryService.uploadAvatar(file);
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
      });
      _updateDirtyState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
      });
    }
  }

  Future<void> _pickHeaderUpload() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() {
      _isUploadingHeader = true;
    });

    try {
      final url = await _cloudinaryService.uploadHeaderImage(file);
      if (!mounted) return;
      setState(() {
        _headerUrl = url;
      });
      _updateDirtyState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Header upload failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingHeader = false;
      });
    }
  }

  Future<void> _openHeaderPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF09090D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      'Cover photos',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _pickHeaderUpload();
                      },
                      child: Text(
                        'Upload',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingBackdrops)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else if (_tmdbBackdrops.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Could not load TMDB covers.',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tmdbBackdrops.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final url = _tmdbBackdrops[index];
                        final selected = url == _headerUrl;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _headerUrl = url;
                            });
                            _updateDirtyState();
                            Navigator.of(context).pop();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 250,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? Colors.white.withOpacity(0.35)
                                    : Colors.white.withOpacity(0.06),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _authService.updateProfile(
        uid: uid,
        name: _nameController.text,
        bio: _bioController.text,
        photoUrl: _photoUrl,
        headerImageUrl: _headerUrl,
      );

      _initialName = _nameController.text.trim();
      _initialBio = _bioController.text.trim();
      _initialPhotoUrl = _photoUrl.trim();
      _initialHeaderUrl = _headerUrl.trim();

      if (!mounted) return;
      setState(() {
        _hasChanges = false;
      });

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _confirmLeave() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B0B10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Unsaved changes',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Save your changes before leaving?',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.72),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'close'),
              child: Text(
                'Close',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == 'save') {
      await _save();
    }
  }

  Future<void> _handleNavTap() async {
    await _confirmLeave();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF050507),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Stack(
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
                      height: 280,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_headerUrl.isNotEmpty)
                            Image.network(
                              _headerUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _headerFallback(),
                            )
                          else
                            _headerFallback(),
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.42),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _EditProfileTopNav(
                              onNavTap: _handleNavTap,
                            ),
                          ),
                          Positioned(
                            top: 82,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _isUploadingHeader ? null : _openHeaderPicker,
                                child: _HeaderChip(
                                  loading: _isUploadingHeader,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -34,
                      child: Center(
                        child: GestureDetector(
                          onTap: _isUploadingAvatar ? null : _pickAvatar,
                          child: Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF121217),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.30),
                                  blurRadius: 24,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipOval(
                                  child: _photoUrl.isNotEmpty
                                      ? Image.network(
                                          _photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _avatarFallback(_nameController.text),
                                        )
                                      : _avatarFallback(_nameController.text),
                                ),
                                if (_isUploadingAvatar)
                                  const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                else
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.78),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.10),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.photo_camera_outlined,
                                        color: Colors.white,
                                        size: 16,
                                      ),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 74, 24, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          _ModernField(
                            controller: _nameController,
                            hint: 'Name',
                            maxLines: 1,
                          ),
                          const SizedBox(height: 14),
                          _ModernField(
                            controller: _bioController,
                            hint: 'Bio',
                            maxLines: 4,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 168,
                                child: _GhostActionButton(
                                  label: 'Cancel',
                                  onTap: _isSaving ? null : _confirmLeave,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 168,
                                child: _PrimaryActionButton(
                                  label: _isSaving ? 'Saving...' : 'Save',
                                  onTap:
                                      (_isSaving || !_hasChanges) ? null : _save,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateDirtyState);
    _bioController.removeListener(_updateDirtyState);
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
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
    final name = displayName.trim();
    final first = name.isNotEmpty ? name[0].toUpperCase() : 'U';

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

class _EditProfileTopNav extends StatelessWidget {
  final VoidCallback onNavTap;

  const _EditProfileTopNav({
    required this.onNavTap,
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
            _EditTopTextButton(label: 'Home', onTap: onNavTap),
            const SizedBox(width: 24),
            _EditTopTextButton(label: 'Discover', onTap: onNavTap),
            const SizedBox(width: 24),
            _EditTopTextButton(label: 'Profile', onTap: onNavTap),
          ],
        ),
      ),
    );
  }
}

class _EditTopTextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _EditTopTextButton({
    required this.label,
    required this.onTap,
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
            color: Colors.white.withOpacity(0.78),
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final bool loading;

  const _HeaderChip({
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.34),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.image_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Change cover photo',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ModernField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _ModernField({
    required this.controller,
    required this.hint,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines,
      cursorColor: Colors.white,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.55,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.white38,
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.18),
          ),
        ),
      ),
    );
  }
}

class _GhostActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _GhostActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: Colors.white.withOpacity(0.08),
        ),
        backgroundColor: Colors.white.withOpacity(0.02),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    );
  }
}