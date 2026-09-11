import 'dart:ui';

import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;

  String _selectedLanguage = 'English';
  String _selectedTheme = 'System';

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _editProfile() {
    _showMessage('Edit profile will be connected next.');
  }

  void _logout() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Color(0xFF68798F), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF7184A4),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showMessage('Logout will be connected later.');
              },
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFE25563),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _SettingsBackground(),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildProfileCard()),
                SliverToBoxAdapter(
                  child: _buildSection(
                    title: 'Account',
                    children: [
                      _SettingsTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Edit Profile',
                        subtitle: 'Update your personal information',
                        onTap: _editProfile,
                      ),
                      _SettingsTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Password & Security',
                        subtitle: 'Manage your password and security',
                        onTap: () {
                          _showMessage(
                            'Password & Security will be connected next.',
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.fingerprint_rounded,
                        title: 'Biometric Login',
                        subtitle: 'Use fingerprint or face unlock',
                        trailing: Switch(
                          value: _biometricEnabled,
                          activeTrackColor: const Color(
                            0xFF1769FF,
                          ).withValues(alpha: 0.55),
                          activeThumbColor: const Color(0xFF1769FF),
                          onChanged: (value) {
                            setState(() {
                              _biometricEnabled = value;
                            });
                          },
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSection(
                    title: 'Preferences',
                    children: [
                      _SettingsTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        subtitle: 'Manage app notifications',
                        trailing: Switch(
                          value: _notificationsEnabled,
                          activeTrackColor: const Color(
                            0xFF1769FF,
                          ).withValues(alpha: 0.55),
                          activeThumbColor: const Color(0xFF1769FF),
                          onChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value;
                            });
                          },
                        ),
                        onTap: () {},
                      ),
                      _SettingsTile(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        subtitle: 'Choose your app theme',
                        trailing: _ValueChip(value: _selectedTheme),
                        onTap: _showThemePicker,
                      ),
                      _SettingsTile(
                        icon: Icons.language_rounded,
                        title: 'Language',
                        subtitle: 'Choose your preferred language',
                        trailing: _ValueChip(value: _selectedLanguage),
                        onTap: _showLanguagePicker,
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSection(
                    title: 'Storage',
                    children: [
                      _SettingsTile(
                        icon: Icons.storage_outlined,
                        title: 'Storage & Files',
                        subtitle: 'Manage your saved documents',
                        onTap: () {
                          _showMessage(
                            'Storage screen will be connected next.',
                          );
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Clear Temporary Files',
                        subtitle: 'Remove cached temporary data',
                        onTap: () {
                          _showMessage('Temporary files cleared.');
                        },
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSection(
                    title: 'Support',
                    children: [
                      _SettingsTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        subtitle: 'Get help with PDF Super App',
                        onTap: () {
                          _showMessage('Help & Support will be added next.');
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'Read our privacy policy',
                        onTap: () {
                          _showMessage('Privacy Policy will be added next.');
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'Read terms and conditions',
                        onTap: () {
                          _showMessage('Terms will be added next.');
                        },
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: _buildLogoutButton()),
                const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your app preferences',
                  style: TextStyle(color: Color(0xFF7184A4), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5A98FF),
                  Color(0xFF1769FF),
                  Color(0xFF0958E8),
                ],
              ),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1769FF).withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.50),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laiba Khan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'laiba@example.com',
                        style: TextStyle(
                          color: Color(0xFFEAF3FF),
                          fontSize: 11.5,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Free Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _editProfile,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.17),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 19,
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

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 9),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF7184A4),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                child: Column(children: children),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: GestureDetector(
        onTap: _logout,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFF4B9BE)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFE25563), size: 20),
              SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFE25563),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePicker() {
    final themes = ['System', 'Light', 'Dark'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SelectionSheet(
          title: 'Choose Theme',
          values: themes,
          selectedValue: _selectedTheme,
          onSelected: (value) {
            setState(() {
              _selectedTheme = value;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showLanguagePicker() {
    final languages = ['English', 'Urdu', 'Arabic', 'French'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SelectionSheet(
          title: 'Choose Language',
          values: languages,
          selectedValue: _selectedLanguage,
          onSelected: (value) {
            setState(() {
              _selectedLanguage = value;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFF1769FF), size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF243653),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8090A6),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8293AA),
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String value;

  const _ValueChip({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0FF),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF1769FF),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectionSheet extends StatelessWidget {
  final String title;
  final List<String> values;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _SelectionSheet({
    required this.title,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF10255C),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...values.map((value) {
              final selected = value == selectedValue;

              return ListTile(
                onTap: () => onSelected(value),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? const Color(0xFF1769FF)
                      : const Color(0xFF90A0B6),
                ),
                title: Text(
                  value,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF1769FF)
                        : const Color(0xFF334663),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.40),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              ),
              child: Icon(icon, color: const Color(0xFF17345F), size: 19),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsBackground extends StatelessWidget {
  const _SettingsBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _BlurCircle(
              size: 300,
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.27),
            ),
          ),
          Positioned(
            top: 350,
            left: -120,
            child: _BlurCircle(
              size: 250,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            child: _BlurCircle(
              size: 270,
              color: const Color(0xFF94C5FF).withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
