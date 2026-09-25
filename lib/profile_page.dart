import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Auth/login.dart';
import 'api_service.dart';
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

  Map<String, dynamic>? _hostProfile;
  bool _isEnrollingFace = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchHostProfile();
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

  Future<void> _fetchHostProfile() async {
    try {
      final host = await ApiService.instance.getHost();
      if (mounted) {
        setState(() {
          _hostProfile = host;
        });
      }
    } catch (_) {}
  }

  Future<void> _editDisplayName() async {
    final currentName = _hostProfile?['name'] as String? ?? _username;
    final textCtrl = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161622),
        title: const Text('Edit Shown Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Harshi',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    try {
      final updated = await ApiService.instance.updateHostName(newName);
      if (mounted && updated != null) {
        setState(() => _hostProfile = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Display name updated to "$newName"'),
            backgroundColor: const Color(0xFF6C63FF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickAndEnrollHostFace({required bool replace}) async {
    final ImagePicker picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF16161E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replace ? 'Replace Profile Photo' : 'Add Profile Photo',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_front_rounded, color: Color(0xFF6C63FF)),
              title: const Text('Take Photo (Front Camera)', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF6C63FF)),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? xfile = await picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );

    if (xfile == null) return;

    setState(() => _isEnrollingFace = true);

    try {
      final updated = await ApiService.instance.enrollHostFace(File(xfile.path), replace: replace);
      if (mounted) {
        setState(() {
          _hostProfile = updated;
          _isEnrollingFace = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host face photo updated successfully!'),
            backgroundColor: Color(0xFF6C63FF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEnrollingFace = false);
        final errStr = e.toString();
        if (errStr.contains('No face found') || errStr.contains('400')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF161622),
              title: const Row(
                children: [
                  Icon(Icons.face_retouching_off_rounded, color: Colors.orangeAccent),
                  SizedBox(width: 10),
                  Text('No Face Found', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: const Text(
                'No clear face was detected in that photo. Please take or pick a clearer photo with good lighting.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Face enrollment error: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _deleteHostFace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        title: const Text('Remove Host Face Photos?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete your registered face photos from your profile. Face recognition will no longer label you as "You".',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ApiService.instance.deleteHostFace();
    if (mounted) {
      if (success) {
        await _fetchHostProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host face photos removed.'),
            backgroundColor: Color(0xFF6C63FF),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove face photos.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSetUpYouWizard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SetUpYouWizardSheet(
        username: _hostProfile?['username'] ?? _username,
        voiceEnrolled: _hostProfile?['voice_enrolled'] == true,
        faceEnrolled: _hostProfile?['face_enrolled'] == true,
        onComplete: _fetchHostProfile,
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to log out of PersonaLens?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
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

    final displayName = _hostProfile?['name'] as String? ?? _username;
    final hostUsername = _hostProfile?['username'] as String? ?? _username;
    final photoB64 = _hostProfile?['photo_b64'] as String?;
    final bool voiceEnrolled = _hostProfile?['voice_enrolled'] == true;
    final bool faceEnrolled = _hostProfile?['face_enrolled'] == true;
    final int faceCount = _hostProfile?['face_count'] as int? ?? 0;

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
                  mode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: primaryTextColor,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () {
                  themeNotifier.value = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                },
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHostProfile,
        color: const Color(0xFF6C63FF),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // 👤 AVATAR & HOST HEADER
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
                      child: photoB64 != null && photoB64.isNotEmpty
                          ? ClipOval(
                              child: Image.memory(
                                base64Decode(photoB64),
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => _buildFallbackAvatar(displayName),
                              ),
                            )
                          : _buildFallbackAvatar(displayName),
                    ),
                    const SizedBox(height: 14),

                    // Display Name & Edit Pencil
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6C63FF)),
                          tooltip: 'Edit display name',
                          onPressed: _editDisplayName,
                        ),
                      ],
                    ),

                    Text(
                      'Signed in as @$hostUsername',
                      style: TextStyle(color: secondaryTextColor, fontSize: 13),
                    ),

                    const SizedBox(height: 8),

                    // Active Account Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Host Account ("You")',
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

              const SizedBox(height: 24),

              // 🌟 SECTION 6: HOST ENROLLMENT STATUS (VOICE & FACE)
              _buildSectionTitle('Voice & Face Enrollment', secondaryTextColor),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Voice Enrollment Tile
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: voiceEnrolled
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          child: Icon(
                            voiceEnrolled ? Icons.check_circle_rounded : Icons.mic_off_rounded,
                            color: voiceEnrolled ? Colors.greenAccent : Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voice Print',
                                style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor, fontSize: 15),
                              ),
                              Text(
                                voiceEnrolled ? 'Enrolled (Voice ID active)' : 'Not enrolled',
                                style: TextStyle(
                                  color: voiceEnrolled ? Colors.greenAccent : Colors.orangeAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF222234),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.mic_rounded, size: 16, color: Color(0xFF6C63FF)),
                          label: Text(voiceEnrolled ? 'Re-enroll' : 'Enroll'),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const VoiceEnrollmentScreen()),
                            );
                            _fetchHostProfile();
                          },
                        ),
                      ],
                    ),

                    const Divider(height: 24, color: Colors.white12),

                    // Face Enrollment Tile
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: faceEnrolled
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          child: Icon(
                            faceEnrolled ? Icons.face_rounded : Icons.face_retouching_off_rounded,
                            color: faceEnrolled ? Colors.greenAccent : Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Face Print ("You")',
                                style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor, fontSize: 15),
                              ),
                              Text(
                                faceEnrolled ? 'Enrolled ($faceCount photo(s))' : 'Not enrolled',
                                style: TextStyle(
                                  color: faceEnrolled ? Colors.greenAccent : Colors.orangeAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Face Enrollment Actions
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isEnrollingFace
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(faceEnrolled ? Icons.add_a_photo_rounded : Icons.camera_front_rounded, size: 16),
                            label: Text(faceEnrolled ? 'Add Photo' : 'Enroll Face'),
                            onPressed: _isEnrollingFace
                                ? null
                                : () => _pickAndEnrollHostFace(replace: false),
                          ),
                        ),
                        if (faceEnrolled) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF6C63FF)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF6C63FF)),
                              label: const Text('Replace', style: TextStyle(color: Color(0xFF6C63FF))),
                              onPressed: _isEnrollingFace
                                  ? null
                                  : () => _pickAndEnrollHostFace(replace: true),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            tooltip: 'Delete Face Photos',
                            onPressed: _deleteHostFace,
                          ),
                        ],
                      ],
                    ),

                    // First-run Setup Wizard trigger banner if not fully enrolled
                    if (!voiceEnrolled || !faceEnrolled) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C63FF), size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Set up voice and face for seamless recognition everywhere.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: _showSetUpYouWizard,
                              child: const Text('Setup Wizard', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 📋 ACCOUNT DETAILS CARD
              _buildSectionTitle('Account Details', secondaryTextColor),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  children: [
                    _buildTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Username',
                      value: hostUsername,
                      primaryText: primaryTextColor,
                      subText: secondaryTextColor,
                    ),
                    Divider(height: 1, color: cardBorder),
                    _buildTile(
                      icon: Icons.badge_outlined,
                      title: 'Display Name',
                      value: displayName,
                      primaryText: primaryTextColor,
                      subText: secondaryTextColor,
                    ),
                    Divider(height: 1, color: cardBorder),
                    _buildTile(
                      icon: Icons.email_outlined,
                      title: 'Account Email',
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
                            activeThumbColor: const Color(0xFF6C63FF),
                            onChanged: (val) {
                              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                            },
                          ),
                        );
                      },
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
                    backgroundColor: Colors.red.withValues(alpha: 0.12),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
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
                style: TextStyle(color: secondaryTextColor.withValues(alpha: 0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String name) {
    return CircleAvatar(
      radius: 46,
      backgroundColor: const Color(0xFF1E1E2C),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6C63FF),
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

// ═══════════════════════════════════════════════════════════════
//  "SET UP YOU" FIRST-RUN WIZARD SHEET
// ═══════════════════════════════════════════════════════════════

class _SetUpYouWizardSheet extends StatefulWidget {
  final String username;
  final bool voiceEnrolled;
  final bool faceEnrolled;
  final VoidCallback onComplete;

  const _SetUpYouWizardSheet({
    required this.username,
    required this.voiceEnrolled,
    required this.faceEnrolled,
    required this.onComplete,
  });

  @override
  State<_SetUpYouWizardSheet> createState() => _SetUpYouWizardSheetState();
}

class _SetUpYouWizardSheetState extends State<_SetUpYouWizardSheet> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C63FF)),
              const SizedBox(width: 10),
              Text(
                'Set up You (@${widget.username})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          if (_currentStep == 0) ...[
            const Text(
              'Welcome to PersonaLens! Let\'s set up your host voice and face print so the assistant recognizes you everywhere.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(
                widget.voiceEnrolled ? Icons.check_circle_rounded : Icons.mic_rounded,
                color: widget.voiceEnrolled ? Colors.greenAccent : const Color(0xFF6C63FF),
              ),
              title: const Text('Step 1: Voice Print', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(
                widget.voiceEnrolled ? 'Voice enrolled' : 'Record ~5 seconds of your voice',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            ListTile(
              leading: Icon(
                widget.faceEnrolled ? Icons.check_circle_rounded : Icons.camera_front_rounded,
                color: widget.faceEnrolled ? Colors.greenAccent : const Color(0xFF6C63FF),
              ),
              title: const Text('Step 2: Face Print', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(
                widget.faceEnrolled ? 'Face photo enrolled' : 'Take a front camera photo',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip for now', style: TextStyle(color: Colors.white54)),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                    onPressed: () => setState(() => _currentStep = 1),
                    child: const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ] else if (_currentStep == 1) ...[
            const Text(
              'Step 1: Record your voice print so live session captions label your speaker lines with your username.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Open Voice Enrollment'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoiceEnrollmentScreen()),
                );
                widget.onComplete();
                if (mounted) setState(() => _currentStep = 2);
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: const Text('Next Step (Face Print)', style: TextStyle(color: Colors.white70)),
            ),
          ] else ...[
            const Text(
              'Step 2: Take or pick a face photo so face recognition shows you as "You".',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.camera_front_rounded),
              label: const Text('Enroll Face Photo'),
              onPressed: () {
                Navigator.pop(context);
                widget.onComplete();
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ],
      ),
    );
  }
}
