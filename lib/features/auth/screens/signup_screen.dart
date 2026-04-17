import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/auth_background.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _bioController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  bool _isLoading = false;
  bool _uploadingAvatar = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _avatarUrl;
  bool _isUploadedAvatar = false;

  @override
  void initState() {
    super.initState();
    _setInitialDiceBearAvatar();
  }

  void _setInitialDiceBearAvatar() {
    final seed = 'encore_${Random().nextInt(99999999)}';
    _avatarUrl = _buildDiceBearFromSeed(seed);
  }

  String _buildDiceBearFromSeed(String seed) {
    final safe = Uri.encodeComponent(
      seed.trim().isEmpty ? 'encore_user' : seed,
    );
    return 'https://api.dicebear.com/9.x/identicon/png?seed=$safe&size=128';
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isLoading || _uploadingAvatar) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      final url = await _cloudinaryService.uploadAvatar(picked);

      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _isUploadedAvatar = true;
      });
    } catch (e) {
      _showSnackBar('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _signUp() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final bio = _bioController.text.trim();

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw Exception('User creation failed.');
      }

      final finalAvatar = (_avatarUrl?.trim().isNotEmpty ?? false)
          ? _avatarUrl!
          : _buildDiceBearFromSeed(username);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'username': username,
        'email': email,
        'bio': bio,
        'avatarUrl': finalAvatar,
        'photoUrl': finalAvatar,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'authProvider': 'password',
        'favoriteItemIds': {
          'movies': [],
          'shows': [],
          'books': [],
          'games': [],
        },
        'derivedPreferences': {
          'favoriteDomains': [],
          'topGenres': [],
          'topTags': [],
        },
        'onboardingCompleted': false,
      });

      await user.updateDisplayName(name);
      await user.updatePhotoURL(finalAvatar);

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Account created');
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' => 'This email is already in use.',
        'invalid-email' => 'Invalid email.',
        'weak-password' => 'Password is too weak (minimum 6 characters).',
        _ => e.message ?? 'Signup failed.',
      };
      _showSnackBar(msg);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      UserCredential cred;

      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        cred = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        await GoogleSignIn.instance.signOut();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;

        final firebaseCredential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        cred = await FirebaseAuth.instance.signInWithCredential(
          firebaseCredential,
        );
      }

      final user = cred.user;
      if (user == null) {
        throw Exception('Google sign-in failed.');
      }

      final fallbackUsername =
          (user.email ?? 'encore_user').split('@').first.trim();

      final chosenUsername = _usernameController.text.trim().isNotEmpty
          ? _usernameController.text.trim()
          : fallbackUsername;

      final chosenName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (user.displayName ?? fallbackUsername);

      final chosenAvatar = (_avatarUrl?.trim().isNotEmpty ?? false)
          ? _avatarUrl!
          : (user.photoURL?.trim().isNotEmpty ?? false)
              ? user.photoURL!
              : _buildDiceBearFromSeed(chosenUsername);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': chosenName,
        'username': chosenUsername,
        'email': user.email ?? '',
        'bio': _bioController.text.trim(),
        'avatarUrl': chosenAvatar,
        'photoUrl': chosenAvatar,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'authProvider': 'google',
        'favoriteItemIds': {
          'movies': [],
          'shows': [],
          'books': [],
          'games': [],
        },
        'derivedPreferences': {
          'favoriteDomains': [],
          'topGenres': [],
          'topTags': [],
        },
        'onboardingCompleted': false,
      }, SetOptions(merge: true));

      await user.updateDisplayName(chosenName);
      await user.updatePhotoURL(chosenAvatar);

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Signed up with Google');
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Google sign-in failed.');
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF111111),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      fontSize: 25,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: -0.8,
      height: 1.0,
    );

    final subtitleStyle = GoogleFonts.inter(
      fontSize: 12.8,
      fontWeight: FontWeight.w400,
      color: Colors.white.withOpacity(0.78),
      height: 1.3,
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AuthBackground.getBackground(),
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.black.withOpacity(0.35),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.45),
                  Colors.black.withOpacity(0.82),
                  Colors.black.withOpacity(0.95),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/icon.png',
                        height: 50,
                        width: 50,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your account',
                        style: titleStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap the avatar if you want to upload your own.',
                        style: subtitleStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.14),
                                width: 1,
                              ),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: _pickAndUploadAvatar,
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundColor:
                                              Colors.white.withOpacity(0.10),
                                          backgroundImage: _avatarUrl != null
                                              ? NetworkImage(_avatarUrl!)
                                              : null,
                                          child: _avatarUrl == null
                                              ? const Icon(
                                                  Icons.person_outline,
                                                  color: Colors.white70,
                                                  size: 24,
                                                )
                                              : null,
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: _uploadingAvatar
                                                ? const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.black,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.edit,
                                                    size: 12,
                                                    color: Colors.black,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _isUploadedAvatar
                                        ? 'Custom photo selected'
                                        : 'Tap avatar to upload',
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ModernAuthField(
                                          controller: _nameController,
                                          hintText: 'Name',
                                          prefixIcon: Icons.badge_outlined,
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                                  ? 'Required'
                                                  : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _ModernAuthField(
                                          controller: _usernameController,
                                          hintText: 'Username',
                                          prefixIcon:
                                              Icons.alternate_email_rounded,
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Required';
                                            }
                                            if (v.contains(' ')) {
                                              return 'No spaces';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  _ModernAuthField(
                                    controller: _emailController,
                                    hintText: 'Email',
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icons.mail_outline_rounded,
                                    validator: (v) =>
                                        (v == null || !v.contains('@'))
                                            ? 'Invalid email'
                                            : null,
                                  ),
                                  const SizedBox(height: 8),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ModernAuthField(
                                          controller: _passwordController,
                                          hintText: 'Password',
                                          obscureText: _obscurePassword,
                                          prefixIcon: Icons.lock_outline_rounded,
                                          validator: (v) =>
                                              (v == null || v.length < 6)
                                                  ? 'Min 6'
                                                  : null,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _ModernAuthField(
                                          controller:
                                              _confirmPasswordController,
                                          hintText: 'Confirm',
                                          obscureText:
                                              _obscureConfirmPassword,
                                          prefixIcon:
                                              Icons.lock_reset_outlined,
                                          validator: (v) {
                                            if (v == null || v.isEmpty) {
                                              return 'Required';
                                            }
                                            if (v != _passwordController.text) {
                                              return 'No match';
                                            }
                                            return null;
                                          },
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  _ModernAuthField(
                                    controller: _bioController,
                                    hintText: 'Bio (optional)',
                                    prefixIcon: Icons.notes_rounded,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 10),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
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
                                        onPressed: _isLoading ? null : _signUp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.black,
                                                ),
                                              )
                                            : Text(
                                                'Create Account',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: Colors.white.withOpacity(0.16),
                                          thickness: 1,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          'or',
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Colors.white.withOpacity(0.16),
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: OutlinedButton(
                                      onPressed:
                                          _isLoading ? null : _signUpWithGoogle,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.06),
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color:
                                              Colors.white.withOpacity(0.16),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'G',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Continue with Google',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Sign in',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernAuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final String? Function(String?)? validator;

  const _ModernAuthField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      validator: validator,
      cursorColor: Colors.white,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: Colors.white60,
          fontSize: 12.8,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: GoogleFonts.inter(
          color: const Color(0xFFFFB4B4),
          fontSize: 10,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.white70, size: 17)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.055),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.45),
            width: 1.1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFFB4B4)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFFB4B4),
            width: 1.1,
          ),
        ),
      ),
    );
  }
}