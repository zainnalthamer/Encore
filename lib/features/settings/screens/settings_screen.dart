import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'change_password_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF8A2A);

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
                color: orange.withOpacity(0.055),
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(height: 118),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SettingsGroupLabel('Account'),
                          const SizedBox(height: 12),
                          _SettingsCard(
                            children: [
                              _SettingsTile(
                                icon: Icons.lock_outline_rounded,
                                title: 'Change password',
                                subtitle: 'Update your login password',
                                onTapBuilder: _openChangePassword,
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),
                          const _SettingsGroupLabel('Appearance'),
                          const SizedBox(height: 12),
                          const _SettingsCard(
                            children: [
                              _SettingsSwitchTile(
                                icon: Icons.dark_mode_outlined,
                                title: 'Dark mode',
                                subtitle: 'Light mode support will be added later',
                                value: true,
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),
                          const _SettingsGroupLabel('Notifications'),
                          const SizedBox(height: 12),
                          const _SettingsCard(
                            children: [
                              _SettingsSwitchTile(
                                icon: Icons.notifications_none_rounded,
                                title: 'Push notifications',
                                subtitle: 'Recommendation and activity alerts',
                                value: false,
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),
                          const _SettingsGroupLabel('Privacy'),
                          const SizedBox(height: 12),
                          const _SettingsCard(
                            children: [
                              _SettingsSwitchTile(
                                icon: Icons.visibility_outlined,
                                title: 'Public profile',
                                subtitle: 'Allow others to discover your profile',
                                value: true,
                              ),
                              _DividerLine(),
                              _SettingsSwitchTile(
                                icon: Icons.group_outlined,
                                title: 'Show followers',
                                subtitle: 'Display followers and following on profile',
                                value: true,
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),
                          const _SettingsGroupLabel('App'),
                          const SizedBox(height: 12),
                          _SettingsCard(
                            children: [
                              _SettingsTile(
                                icon: Icons.info_outline_rounded,
                                title: 'About Encore',
                                subtitle: 'Version, credits, and app details',
                                onTapBuilder: _showAboutPlaceholder,
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
            child: _SettingsTopNav(
              onHomeTap: () => Navigator.of(context).pop(),
              onDiscoverTap: () => Navigator.of(context).pop(),
              onProfileTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  static void _openChangePassword(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChangePasswordScreen(),
      ),
    );
  }

  static void _showAboutPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('About page will be added later.'),
      ),
    );
  }
}

class _SettingsTopNav extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onDiscoverTap;
  final VoidCallback onProfileTap;

  const _SettingsTopNav({
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

class _SettingsGroupLabel extends StatelessWidget {
  final String title;

  const _SettingsGroupLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withOpacity(0.055),
            ),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context)? onTapBuilder;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTapBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapBuilder == null ? null : () => onTapBuilder!(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            _IconBox(icon),
            const SizedBox(width: 14),
            Expanded(
              child: _TileText(title: title, subtitle: subtitle),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.42),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          _IconBox(icon),
          const SizedBox(width: 14),
          Expanded(
            child: _TileText(title: title, subtitle: subtitle),
          ),
          IgnorePointer(
            child: Switch(
              value: value,
              activeColor: const Color(0xFFFF8A2A),
              activeTrackColor: const Color(0xFFFF8A2A).withOpacity(0.35),
              inactiveThumbColor: Colors.white.withOpacity(0.78),
              inactiveTrackColor: Colors.white.withOpacity(0.18),
              onChanged: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _TileText extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TileText({
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
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.56),
            fontSize: 13.2,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      height: 1,
      color: Colors.white.withOpacity(0.05),
    );
  }
}