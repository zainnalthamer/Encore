import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _updatePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (user == null || email == null) {
      _showMessage('No signed-in user found.');
      return;
    }

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Fill in all fields.');
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('New password must be at least 6 characters.');
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('New passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      if (!mounted) return;
      _showMessage('Password updated.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showMessage('Current password is incorrect.');
      } else if (e.code == 'weak-password') {
        _showMessage('New password is too weak.');
      } else if (e.code == 'requires-recent-login') {
        _showMessage('Please log in again first.');
      } else {
        _showMessage('Failed to update password.');
      }
    } catch (_) {
      _showMessage('Something went wrong.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: const Color(0xFF050507)),
          ),
          Positioned(
            top: -140,
            right: -90,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF8A2A).withOpacity(0.055),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(height: 132),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Change password',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Choose a new password for your Encore account.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.56),
                              fontSize: 14.5,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 34),
                          _PasswordLineField(
                            controller: _currentPasswordController,
                            hint: 'Current password',
                            obscureText: _hideCurrent,
                            onToggle: () {
                              setState(() => _hideCurrent = !_hideCurrent);
                            },
                          ),
                          const SizedBox(height: 20),
                          _PasswordLineField(
                            controller: _newPasswordController,
                            hint: 'New password',
                            obscureText: _hideNew,
                            onToggle: () {
                              setState(() => _hideNew = !_hideNew);
                            },
                          ),
                          const SizedBox(height: 20),
                          _PasswordLineField(
                            controller: _confirmPasswordController,
                            hint: 'Confirm new password',
                            obscureText: _hideConfirm,
                            onToggle: () {
                              setState(() => _hideConfirm = !_hideConfirm);
                            },
                          ),
                          const SizedBox(height: 34),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 150,
                                child: OutlinedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.10),
                                    ),
                                    backgroundColor:
                                        Colors.white.withOpacity(0.025),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 180,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _updatePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF8A2A),
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          'Update',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                          ),
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PasswordTopNav(
              onHomeTap: () => Navigator.of(context).pop(),
              onDiscoverTap: () => Navigator.of(context).pop(),
              onProfileTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordTopNav extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onDiscoverTap;
  final VoidCallback onProfileTap;

  const _PasswordTopNav({
    required this.onHomeTap,
    required this.onDiscoverTap,
    required this.onProfileTap,
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
            Colors.black.withOpacity(0.92),
            Colors.black.withOpacity(0.66),
            Colors.black.withOpacity(0.22),
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
            _NavTextButton(label: 'Home', onTap: onHomeTap),
            const SizedBox(width: 24),
            _NavTextButton(label: 'Discover', onTap: onDiscoverTap),
            const SizedBox(width: 24),
            _NavTextButton(label: 'Profile', onTap: onProfileTap),
          ],
        ),
      ),
    );
  }
}

class _NavTextButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _NavTextButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_NavTextButton> createState() => _NavTextButtonState();
}

class _NavTextButtonState extends State<_NavTextButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 140),
          style: GoogleFonts.inter(
            color: _hovered ? Colors.white : Colors.white.withOpacity(0.72),
            fontSize: 14.5,
            fontWeight: _hovered ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _PasswordLineField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final VoidCallback onToggle;

  const _PasswordLineField({
    required this.controller,
    required this.hint,
    required this.obscureText,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      cursorColor: const Color(0xFFFF8A2A),
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: Colors.white38,
          fontSize: 15,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.white.withOpacity(0.48),
            size: 20,
          ),
        ),
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: 16,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFFFF8A2A),
            width: 1.3,
          ),
        ),
      ),
    );
  }
}