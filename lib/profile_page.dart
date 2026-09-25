import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Auth/login.dart';
import 'imageget.dart';
import 'main.dart';
import 'people_and_history_page.dart';
import 'server_settings_dialog.dart';
import 'voice_enrollment_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  String _username = 'User';
  String _email = '';
  String _joinedDate = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    _user = supabase.auth.currentUser;
    if (_user != null) {
      final meta = _user!.userMetadata;
      final rawEmail = _user!.email ?? '';
      
      _username = (meta != null && meta['username'] != null)
          ? meta['username'].toString()
          : (rawEmail.endsWith('@imagestore.local')
              ? rawEmail.split('@').first
              : (rawEmail.contains('@') ? rawEmail.split('@').first : 'User'));

      _email = rawEmail;

      if (_user!.createdAt.isNotEmpty) {
        try {
          final dt = DateTime.parse(_user!.createdAt);
          _joinedDate = '${dt.day}/${dt.month}/${dt.year}';
        } catch (_) {
          _joinedDate = 'Recent';
        }
      } else {
        _joinedDate = 'Recent';
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out of PersonaLens?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A1A24);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF666677);
    final cardBg = isDark ? const Color(0xFF1A1A24) : Colors.white;
    final cardBorder = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: primaryTextColor),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
              return IconButton(
                icon: Icon(
                  mode == ThemeMode.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: primaryTextColor,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () {
                  themeNotifier.value = mode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // 👤 AVATAR & HEADER
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: isDark ? const Color(0xFF1A1A24) : const Color(0xFFE2E0FF),
                      child: Text(
                        _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _username,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Active Account',
                      style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 📋 ACCOUNT DETAILS CARD
            _buildSectionTitle('Account Details', secondaryTextColor),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  _buildTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Username',
                    value: _username,
                    primaryText: primaryTextColor,
                    subText: secondaryTextColor,
                  ),
                  Divider(height: 1, color: cardBorder),
                  _buildTile(
                    icon: Icons.email_outlined,
                    title: 'Account Identity / Email',
                    value: _email.isNotEmpty ? _email : 'Not set',
                    primaryText: primaryTextColor,
                    subText: secondaryTextColor,
                  ),
                  if (_joinedDate.isNotEmpty) ...[
                    Divider(height: 1, color: cardBorder),
                    _buildTile(
                      icon: Icons.calendar_today_rounded,
                      title: 'Member Since',
                      value: _joinedDate,
                      primaryText: primaryTextColor,
                      subText: secondaryTextColor,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ⚙️ PREFERENCES & SHORTCUTS
            _buildSectionTitle('Preferences & Shortcuts', secondaryTextColor),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, mode, _) {
                      final isDarkMode = mode == ThemeMode.dark;
                      return ListTile(
                        leading: Icon(
                          isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: const Color(0xFF6C63FF),
                        ),
                        title: Text('App Theme', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isDarkMode ? 'Dark Mode Active' : 'Light Mode Active',
                          style: TextStyle(color: secondaryTextColor, fontSize: 13),
                        ),
                        trailing: Switch(
                          value: isDarkMode,
                          activeColor: const Color(0xFF6C63FF),
                          onChanged: (val) {
                            themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                          },
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: cardBorder),
                  ListTile(
                    leading: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF6C63FF)),
                    title: Text('Voice Profile Enrollment', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                    subtitle: Text('Enroll host voice print for speaker identification', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                    trailing: Icon(Icons.chevron_right_rounded, color: secondaryTextColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VoiceEnrollmentScreen()),
                      );
                    },
                  ),
                  Divider(height: 1, color: cardBorder),
                  ListTile(
                    leading: const Icon(Icons.people_alt_rounded, color: Color(0xFF6C63FF)),
                    title: Text('People & Memory History', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                    subtitle: Text('View known people & past sessions', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                    trailing: Icon(Icons.chevron_right_rounded, color: secondaryTextColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PeopleAndHistoryPage()),
                      );
                    },
                  ),
                  Divider(height: 1, color: cardBorder),
                  ListTile(
                    leading: const Icon(Icons.dns_rounded, color: Color(0xFF6C63FF)),
                    title: Text('Server Settings', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                    subtitle: Text('Configure backend host IP & test health', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                    trailing: Icon(Icons.chevron_right_rounded, color: secondaryTextColor),
                    onTap: () => ServerSettingsDialog.show(context),
                  ),
                  Divider(height: 1, color: cardBorder),
                  ListTile(
                    leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF6C63FF)),
                    title: Text('My Image Gallery', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600)),
                    subtitle: Text('View & manage face embeddings', style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                    trailing: Icon(Icons.chevron_right_rounded, color: secondaryTextColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ImageGalleryPage()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 🚪 LOGOUT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.12),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Log Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'PersonaLens Memory Assistant v1.0.0',
              style: TextStyle(color: secondaryTextColor.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String value,
    required Color primaryText,
    required Color subText,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6C63FF)),
      title: Text(title, style: TextStyle(color: subText, fontSize: 12)),
      subtitle: Text(
        value,
        style: TextStyle(color: primaryText, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
