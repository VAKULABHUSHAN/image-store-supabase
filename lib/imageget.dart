import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';
import 'Auth/login.dart';
import 'main.dart';
import 'profile_page.dart';

class StoreImg extends StatelessWidget {
  const StoreImg({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PersonaLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const UploadPage(),
    );
  }
}

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedFile;
  bool _isIdentifying = false;
  String? _statusMessage;
  String? _userEmail;
  List<Map<String, dynamic>> _recognizedFaces = [];

  @override
  void initState() {
    super.initState();
    _getUser();
  }

  void _getUser() {
    final user = supabase.auth.currentUser;
    final metaUsername = user?.userMetadata?['username'] as String?;
    final rawEmail = user?.email;
    final display = metaUsername ??
        (rawEmail != null && rawEmail.endsWith('@persona-lens.local')
            ? rawEmail.split('@').first
            : rawEmail) ??
        'Guest';
    setState(() => _userEmail = display);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? xfile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (xfile == null) return;

      setState(() {
        _selectedFile = File(xfile.path);
        _statusMessage = null;
        _recognizedFaces = [];
      });

      _runFaceRecognition();
    } catch (e) {
      _showSnack('Failed to pick image: $e');
    }
  }

  Future<void> _runFaceRecognition() async {
    if (_selectedFile == null) return;

    setState(() {
      _isIdentifying = true;
      _statusMessage = 'Identifying face(s)…';
      _recognizedFaces = [];
    });

    try {
      // POST /recognize?wait=true
      final results = await ApiService.instance.recognizeFace(_selectedFile!, wait: true);

      setState(() {
        _isIdentifying = false;
        _recognizedFaces = results;
        if (results.isEmpty) {
          _statusMessage = 'No face found in this photo.';
        } else {
          _statusMessage = 'Identified ${results.length} face(s).';
        }
      });
    } catch (e) {
      setState(() {
        _isIdentifying = false;
        _statusMessage = 'Recognition error: $e';
      });
      _showSnack('Recognition failed: $e');
    }
  }

  Future<void> _openSavePersonSheet() async {
    if (_selectedFile == null) return;

    final nameController = TextEditingController();
    String selectedRelationship = 'Friend';
    bool isSaving = false;
    final relationships = [
      'Daughter',
      'Son',
      'Spouse',
      'Grandchild',
      'Sibling',
      'Friend',
      'Neighbor',
      'Caregiver',
      'Other'
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF14141E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add_rounded, color: Color(0xFFFFB238)),
                    const SizedBox(width: 10),
                    Text(
                      'Save Unknown Face',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter person\'s name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRelationship,
                  decoration: InputDecoration(
                    labelText: 'Relationship',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: relationships.map((rel) {
                    return DropdownMenuItem(value: rel, child: Text(rel));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedRelationship = val);
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Please enter a name first.')),
                                  );
                                  return;
                                }

                                setSheetState(() => isSaving = true);
                                try {
                                  // POST /person
                                  await ApiService.instance.createPersonWithFace(
                                    name: name,
                                    relationship: selectedRelationship,
                                    imageFile: _selectedFile!,
                                  );

                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    _showSnack('✅ Saved $name!');
                                    // Re-run face recognition to show updated name box
                                    _runFaceRecognition();
                                  }
                                } catch (e) {
                                  setSheetState(() => isSaving = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Failed to save person: $e')),
                                  );
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(isSaving ? 'Saving…' : 'Save Person'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _buildImageOverlay(BuildContext context) {
    if (_selectedFile == null) {
      return const _EmptyPreview();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerW = constraints.maxWidth;
        final containerH = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Image
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.file(
                _selectedFile!,
                fit: BoxFit.contain,
                width: containerW,
                height: containerH,
              ),
            ),

            // 2. Loading Spinner Overlay
            if (_isIdentifying)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF6C63FF)),
                      SizedBox(height: 12),
                      Text(
                        'Identifying face(s)…',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // 3. Face Bounding Boxes Overlay (§11.1)
            if (!_isIdentifying)
              ..._recognizedFaces.map((face) {
                final imgW = (face['image_width'] as num?)?.toDouble() ?? 1.0;
                final imgH = (face['image_height'] as num?)?.toDouble() ?? 1.0;
                final loc = (face['location'] as List?) ?? [0, 0, 0, 0];

                final top = (loc[0] as num).toDouble();
                final right = (loc[1] as num).toDouble();
                final bottom = (loc[2] as num).toDouble();
                final left = (loc[3] as num).toDouble();

                final confidence = (face['confidence'] as num?)?.toDouble() ?? 0.0;
                final name = (face['name'] as String?) ?? 'Unknown';
                final personId = face['person_id'] as String?;

                // Unknown face criteria (§11.1)
                final bool isUnknown = name == 'Unknown' || personId == null || confidence < 0.6;

                // Scale factor for BoxFit.contain
                final scale = math.min(containerW / imgW, containerH / imgH);
                final offsetX = (containerW - (imgW * scale)) / 2;
                final offsetY = (containerH - (imgH * scale)) / 2;

                final boxLeft = offsetX + (left * scale);
                final boxTop = offsetY + (top * scale);
                final boxW = (right - left) * scale;
                final boxH = (bottom - top) * scale;

                final boxColor = isUnknown ? const Color(0xFFFFB238) : const Color(0xFF3DFBD1);
                final labelText = isUnknown
                    ? 'Unmatched (${(confidence * 100).toStringAsFixed(0)}%)'
                    : '$name (${(confidence * 100).toStringAsFixed(0)}%)';

                return Positioned(
                  left: boxLeft.clamp(0, containerW - 10),
                  top: boxTop.clamp(0, containerH - 10),
                  width: boxW.clamp(10, containerW),
                  height: boxH.clamp(10, containerH),
                  child: GestureDetector(
                    onTap: () {
                      if (isUnknown) {
                        _openSavePersonSheet();
                      } else {
                        _showSnack('Recognized: $name (${(confidence * 100).toStringAsFixed(0)}%)');
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: boxColor,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -24,
                            left: -2,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: boxColor,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 4),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      labelText,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isUnknown) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.person_add_rounded, size: 12, color: Colors.black),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A24);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF1A1A24);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('PersonaLens Vision',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 1.2)),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
              return IconButton(
                icon: Icon(
                  mode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: iconColor,
                ),
                tooltip: mode == ThemeMode.dark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                onPressed: () {
                  themeNotifier.value =
                      mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.photo_library_rounded, color: iconColor),
            tooltip: 'View Gallery',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ImageGalleryPage())),
          ),
          IconButton(
            icon: Icon(Icons.person_rounded, color: iconColor),
            tooltip: 'View Profile',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileCard(
                email: _userEmail,
                onLogout: () async {
                  await supabase.auth.signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (r) => false,
                  );
                },
              ),
              const SizedBox(height: 20),

              // Main Photo Box with Bounding Box Overlay
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _selectedFile != null ? const Color(0xFF6C63FF) : Colors.white12,
                      width: 2,
                    ),
                  ),
                  child: _buildImageOverlay(context),
                ),
              ),

              const SizedBox(height: 20),

              // Status Message
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _statusMessage!.startsWith('No face') ? Colors.amberAccent : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Gallery & Camera Buttons
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_rounded,
                      label: 'Choose Photo',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Take Photo',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}



class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.add_a_photo_outlined, size: 64, color: Colors.white24),
        SizedBox(height: 16),
        Text(
          'Select or take a photo',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        SizedBox(height: 8),
        Text(
          'Supports single-photo face identification',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String? email;
  final VoidCallback onLogout;

  const _ProfileCard({
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161620),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF6C63FF),
            radius: 20,
            child: Text(
              (email != null && email!.isNotEmpty) ? email![0].toUpperCase() : 'U',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Signed in as',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                Text(
                  email ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
            onPressed: onLogout,
            tooltip: 'Log out',
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF222230),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, color: const Color(0xFF6C63FF)),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: onTap,
    );
  }
}


// ═══════════════════════════════════════════════════════════════
//  GALLERY PAGE (Section 11.5 Implementation)
// ═══════════════════════════════════════════════════════════════

class ImageGalleryPage extends StatefulWidget {
  final String? personId;
  final String? personName;

  const ImageGalleryPage({
    super.key,
    this.personId,
    this.personName,
  });

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

enum GalleryFilter { all, unidentified, person }

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  List<Map<String, dynamic>> _images = [];
  bool _isLoading = true;
  String? _error;
  GalleryFilter _currentFilter = GalleryFilter.all;
  Map<String, String> _authHeaders = {};
  bool _isReidentifying = false;

  @override
  void initState() {
    super.initState();
    if (widget.personId != null && widget.personId!.isNotEmpty) {
      _currentFilter = GalleryFilter.person;
    }
    _initData();
  }

  Future<void> _initData() async {
    await _loadAuthHeaders();
    await _loadGallery();
  }

  Future<void> _loadAuthHeaders() async {
    final headers = await ApiService.instance.getAuthHeaders();
    if (mounted) {
      setState(() => _authHeaders = headers);
    }
  }

  Future<void> _loadGallery() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiService.instance.getGallery(
        limit: 50,
        offset: 0,
        personId: _currentFilter == GalleryFilter.person ? widget.personId : null,
        unidentified: _currentFilter == GalleryFilter.unidentified ? true : null,
      );

      final List rawList = res['images'] ?? [];
      final List<Map<String, dynamic>> parsedImages = rawList.cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _images = parsedImages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runReidentify() async {
    setState(() => _isReidentifying = true);
    try {
      final res = await ApiService.instance.reidentifyGalleryFaces();
      final checked = res['checked'] ?? 0;
      final matched = res['matched'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Re-identification complete: Checked $checked faces, matched $matched.'),
            backgroundColor: const Color(0xFF6C63FF),
          ),
        );
      }
      await _loadGallery();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Re-identification error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isReidentifying = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
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
            const Text(
              'Add Photo to Gallery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF6C63FF)),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6C63FF)),
              title: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? xfile = await picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null) return;

    final File imageFile = File(xfile.path);
    final String? caption = await _promptCaptionDialog();

    if (!mounted) return;
    _showUploadingDialog();

    try {
      final newImg = await ApiService.instance.uploadToGallery(imageFile, caption: caption);
      if (mounted) {
        Navigator.pop(context); // dismiss upload dialog
        if (newImg != null) {
          final faceCount = (newImg['faces'] as List?)?.length ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo uploaded successfully! Found $faceCount face(s).'),
              backgroundColor: const Color(0xFF6C63FF),
            ),
          );
          _loadGallery();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<String?> _promptCaptionDialog() async {
    String caption = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        title: const Text('Add Caption (Optional)', style: TextStyle(color: Colors.white)),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Oval Office meeting',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
          ),
          onChanged: (val) => caption = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () => Navigator.pop(ctx, caption.trim()),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  void _showUploadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        content: Row(
          children: const [
            CircularProgressIndicator(color: Color(0xFF6C63FF)),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Uploading image & detecting faces…',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSearchByFace() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;

    if (!mounted) return;
    _showSearchingDialog();

    try {
      final results = await ApiService.instance.searchGalleryByFace(File(xfile.path));
      if (mounted) {
        Navigator.pop(context); // close searching dialog
        _showSearchResultsSheet(results);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showSearchingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        content: Row(
          children: const [
            CircularProgressIndicator(color: Color(0xFF6C63FF)),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Matching face against stored photos…',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchResultsSheet(List<Map<String, dynamic>> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 10),
                  Text(
                    'Search Results (${results.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching photos found in gallery',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: results.length,
                      itemBuilder: (ctx, index) {
                        return _GalleryTile(
                          image: results[index],
                          authHeaders: _authHeaders,
                          onTap: () {
                            Navigator.pop(ctx);
                            _openImageDetail(results[index]);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImageDetail(Map<String, dynamic> image) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GalleryImageDetailSheet(
        imageId: image['id'].toString(),
        initialImage: image,
        authHeaders: _authHeaders,
        onRefreshRequired: _loadGallery,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121A),
        elevation: 0,
        title: Text(
          widget.personName != null ? 'Photos of ${widget.personName}' : 'Gallery',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white70),
            tooltip: 'Search gallery by face photo',
            onPressed: _pickAndSearchByFace,
          ),
          IconButton(
            icon: _isReidentifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.white70),
            tooltip: 'Re-identify faces',
            onPressed: _isReidentifying ? null : _runReidentify,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C63FF),
        elevation: 4,
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text('Add Photo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: _pickAndUploadImage,
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF12121A),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All Photos',
                    isSelected: _currentFilter == GalleryFilter.all,
                    onSelected: () {
                      setState(() => _currentFilter = GalleryFilter.all);
                      _loadGallery();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Who is this? (Unidentified)',
                    icon: Icons.help_outline_rounded,
                    isSelected: _currentFilter == GalleryFilter.unidentified,
                    onSelected: () {
                      setState(() => _currentFilter = GalleryFilter.unidentified);
                      _loadGallery();
                    },
                  ),
                  if (widget.personId != null) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: widget.personName ?? 'Selected Person',
                      icon: Icons.person_rounded,
                      isSelected: _currentFilter == GalleryFilter.person,
                      onSelected: () {
                        setState(() => _currentFilter = GalleryFilter.person);
                        _loadGallery();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Main Gallery Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            Text('Error: $_error', style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 16),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                              onPressed: _loadGallery,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _images.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.photo_library_outlined, color: Colors.white24, size: 64),
                                const SizedBox(height: 16),
                                Text(
                                  _currentFilter == GalleryFilter.unidentified
                                      ? 'No unidentified faces queue!'
                                      : 'No photos in gallery yet',
                                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap "Add Photo" to upload images and save face embeddings',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF6C63FF),
                            onRefresh: _loadGallery,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.82,
                              ),
                              itemCount: _images.length,
                              itemBuilder: (context, index) {
                                return _GalleryTile(
                                  image: _images[index],
                                  authHeaders: _authHeaders,
                                  onTap: () => _openImageDetail(_images[index]),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      showCheckmark: false,
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF6C63FF),
            )
          : null,
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      backgroundColor: const Color(0xFF1C1C26),
      selectedColor: const Color(0xFF6C63FF),
      side: BorderSide(
        color: isSelected ? const Color(0xFF6C63FF) : Colors.white12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final Map<String, dynamic> image;
  final Map<String, String> authHeaders;
  final VoidCallback onTap;

  const _GalleryTile({
    required this.image,
    required this.authHeaders,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rawThumbUrl = image['thumb_url'] as String? ?? image['image_url'] as String? ?? '';
    final fullThumbUrl = rawThumbUrl.startsWith('http')
        ? rawThumbUrl
        : '${ApiService.instance.baseUrl}$rawThumbUrl';

    final List faces = (image['faces'] as List?) ?? [];
    final bool hasUnidentified = faces.any((f) => f['person_id'] == null);
    final String? caption = image['caption'] as String?;

    // Collect face names
    final faceNames = faces
        .map((f) => (f['person_name'] as String?) ?? 'Unidentified')
        .where((n) => n.isNotEmpty)
        .take(2)
        .join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnidentified ? Colors.orangeAccent.withOpacity(0.5) : Colors.white12,
            width: hasUnidentified ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            fullThumbUrl.isNotEmpty
                ? Image.network(
                    fullThumbUrl,
                    headers: authHeaders.isNotEmpty ? authHeaders : null,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      color: const Color(0xFF1E1E28),
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 36),
                      ),
                    ),
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFF1E1E28),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: const Color(0xFF1E1E28),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_rounded, color: Colors.white24),
                    ),
                  ),

            // Gradient bottom overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Top Badge: "Who is this?"
            if (hasUnidentified)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.help_outline_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Who is this?',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Face Count Badge (Top Right)
            if (faces.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.face_rounded, color: Colors.white70, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '${faces.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Text Info
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null && caption.isNotEmpty)
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  if (faceNames.isNotEmpty)
                    Text(
                      faceNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnidentified ? Colors.orangeAccent : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  GALLERY IMAGE DETAIL SHEET (Section 11.5 Detail & Face Assign)
// ═══════════════════════════════════════════════════════════════

class _GalleryImageDetailSheet extends StatefulWidget {
  final String imageId;
  final Map<String, dynamic>? initialImage;
  final Map<String, String> authHeaders;
  final VoidCallback onRefreshRequired;

  const _GalleryImageDetailSheet({
    required this.imageId,
    this.initialImage,
    required this.authHeaders,
    required this.onRefreshRequired,
  });

  @override
  State<_GalleryImageDetailSheet> createState() => _GalleryImageDetailSheetState();
}

class _GalleryImageDetailSheetState extends State<_GalleryImageDetailSheet> {
  Map<String, dynamic>? _image;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final detail = await ApiService.instance.getGalleryImageDetail(widget.imageId);
      if (detail != null && mounted) {
        setState(() {
          _image = detail;
          _isLoading = false;
        });
      } else if (_image != null && mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteImage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        title: const Text('Delete Photo?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete the stored image file and its face embeddings from the server.',
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

    setState(() => _isDeleting = true);
    try {
      final success = await ApiService.instance.deleteGalleryImage(widget.imageId);
      if (mounted) {
        Navigator.pop(context); // close sheet
        widget.onRefreshRequired();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Photo deleted' : 'Failed to delete photo'),
            backgroundColor: success ? const Color(0xFF6C63FF) : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _openAssignDialog(Map<String, dynamic> face) {
    showDialog(
      context: context,
      builder: (ctx) => _AssignFaceDialog(
        faceId: face['id'].toString(),
        currentName: face['person_name'] as String?,
        onSuccess: () async {
          await _fetchDetail();
          widget.onRefreshRequired();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final rawImageUrl = img?['image_url'] as String? ?? '';
    final fullImageUrl = rawImageUrl.startsWith('http')
        ? rawImageUrl
        : '${ApiService.instance.baseUrl}$rawImageUrl';

    final List faces = (img?['faces'] as List?) ?? [];
    final int imgWidth = img?['width'] as int? ?? 1;
    final int imgHeight = img?['height'] as int? ?? 1;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F16),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // Sheet Header Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Action bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      img?['caption'] != null && (img!['caption'] as String).isNotEmpty
                          ? img['caption']
                          : 'Photo Detail',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                          )
                        : const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    tooltip: 'Delete Photo',
                    onPressed: _isDeleting ? null : _deleteImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Image with Dynamic Bounding Box Overlay
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: const Color(0xFF161622),
                        child: LayoutBuilder(
                          builder: (ctx, constraints) {
                            final double renderWidth = constraints.maxWidth;
                            final double renderHeight = renderWidth * (imgHeight / imgWidth);

                            return SizedBox(
                              width: renderWidth,
                              height: renderHeight,
                              child: Stack(
                                children: [
                                  // Base full image
                                  if (fullImageUrl.isNotEmpty)
                                    Image.network(
                                      fullImageUrl,
                                      headers: widget.authHeaders.isNotEmpty ? widget.authHeaders : null,
                                      width: renderWidth,
                                      height: renderHeight,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => const Center(
                                        child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
                                      ),
                                    ),

                                  // Bounding Boxes Overlay
                                  ...faces.map((f) {
                                    final List loc = f['location'] as List? ?? [0, 0, 0, 0];
                                    if (loc.length < 4) return const SizedBox.shrink();

                                    final double topPx = (loc[0] as num).toDouble();
                                    final double rightPx = (loc[1] as num).toDouble();
                                    final double bottomPx = (loc[2] as num).toDouble();
                                    final double leftPx = (loc[3] as num).toDouble();

                                    final double scaleX = renderWidth / imgWidth;
                                    final double scaleY = renderHeight / imgHeight;

                                    final double top = topPx * scaleY;
                                    final double left = leftPx * scaleX;
                                    final double width = (rightPx - leftPx) * scaleX;
                                    final double height = (bottomPx - topPx) * scaleY;

                                    final bool isUnidentified = f['person_id'] == null;
                                    final String name = f['person_name'] as String? ?? 'Who is this?';

                                    return Positioned(
                                      top: top,
                                      left: left,
                                      width: width,
                                      height: height,
                                      child: GestureDetector(
                                        onTap: () => _openAssignDialog(Map<String, dynamic>.from(f)),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isUnidentified ? Colors.orangeAccent : const Color(0xFF6C63FF),
                                              width: 2.0,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                            color: (isUnidentified ? Colors.orange : const Color(0xFF6C63FF))
                                                .withOpacity(0.15),
                                          ),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned(
                                                top: -22,
                                                left: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isUnidentified ? Colors.orange.shade900 : const Color(0xFF6C63FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Detected Faces Section Header
                    Row(
                      children: [
                        const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF6C63FF)),
                        const SizedBox(width: 8),
                        Text(
                          'Detected Faces (${faces.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (faces.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161622),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No faces detected in this photo.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      Column(
                        children: faces.map((f) {
                          final map = Map<String, dynamic>.from(f);
                          final bool isUnidentified = map['person_id'] == null;
                          final String name = map['person_name'] as String? ?? 'Unidentified Face';
                          final double confidence = ((map['confidence'] as num?)?.toDouble() ?? 0.0) * 100;
                          final String source = map['source'] as String? ?? 'cloud';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161622),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isUnidentified ? Colors.orangeAccent.withOpacity(0.5) : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isUnidentified ? Colors.orange.shade900 : const Color(0xFF6C63FF),
                                  child: Icon(
                                    isUnidentified ? Icons.help_outline_rounded : Icons.person_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isUnidentified ? Colors.orangeAccent : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Confidence: ${confidence.toStringAsFixed(1)}% • Source: $source',
                                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isUnidentified ? Colors.orange.shade800 : const Color(0xFF1F1F30),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: Icon(
                                    isUnidentified ? Icons.edit_rounded : Icons.swap_horiz_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    isUnidentified ? 'Who is this?' : 'Reassign',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _openAssignDialog(map),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 20),

                    // Metadata Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Image Info',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Dimensions: ${imgWidth}x${imgHeight} px',
                                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              Text(
                                'Size: ${((img?['byte_size'] as int? ?? 0) / 1024).toStringAsFixed(1)} KB',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                          if (img?['created_at'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Uploaded: ${img!['created_at']}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ASSIGN FACE DIALOG (Assign identity + optional enroll)
// ═══════════════════════════════════════════════════════════════

class _AssignFaceDialog extends StatefulWidget {
  final String faceId;
  final String? currentName;
  final VoidCallback onSuccess;

  const _AssignFaceDialog({
    required this.faceId,
    this.currentName,
    required this.onSuccess,
  });

  @override
  State<_AssignFaceDialog> createState() => _AssignFaceDialogState();
}

class _AssignFaceDialogState extends State<_AssignFaceDialog> {
  List<Map<String, dynamic>> _knownPeople = [];
  bool _isLoadingPeople = true;
  String? _selectedPersonId;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _relCtrl = TextEditingController();
  bool _isNewPersonMode = false;
  bool _enroll = true;
  bool _isSaving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchPeople();
  }

  Future<void> _fetchPeople() async {
    try {
      final list = await ApiService.instance.getPeople();
      if (mounted) {
        setState(() {
          _knownPeople = list;
          _isLoadingPeople = false;
          if (_knownPeople.isNotEmpty) {
            _selectedPersonId = _knownPeople.first['id']?.toString();
          } else {
            _isNewPersonMode = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPeople = false;
          _isNewPersonMode = true;
        });
      }
    }
  }

  Future<void> _submitAssign() async {
    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    try {
      if (_isNewPersonMode) {
        final name = _nameCtrl.text.trim();
        if (name.isEmpty) {
          throw Exception('Please enter a name for this person.');
        }
        await ApiService.instance.assignGalleryFace(
          faceId: widget.faceId,
          name: name,
          relationship: _relCtrl.text.trim().isNotEmpty ? _relCtrl.text.trim() : null,
          enroll: _enroll,
        );
      } else {
        if (_selectedPersonId == null || _selectedPersonId!.isEmpty) {
          throw Exception('Please select a person.');
        }
        await ApiService.instance.assignGalleryFace(
          faceId: widget.faceId,
          personId: _selectedPersonId,
          enroll: _enroll,
        );
      }

      // Reidentify after face assignment as specified in §11.5
      final reidRes = await ApiService.instance.reidentifyGalleryFaces();
      final matched = reidRes['matched'] ?? 0;

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Face assigned successfully! Re-identified $matched other photos.'),
            backgroundColor: const Color(0xFF6C63FF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161622),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6C63FF)),
          SizedBox(width: 10),
          Text('Who is this face?', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Mode Selector: Existing vs New Person
            if (!_isLoadingPeople && _knownPeople.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Someone I know'),
                      selected: !_isNewPersonMode,
                      onSelected: (val) {
                        if (val) setState(() => _isNewPersonMode = false);
                      },
                      selectedColor: const Color(0xFF6C63FF),
                      backgroundColor: const Color(0xFF222230),
                      labelStyle: TextStyle(
                        color: !_isNewPersonMode ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('New Person'),
                      selected: _isNewPersonMode,
                      onSelected: (val) {
                        if (val) setState(() => _isNewPersonMode = true);
                      },
                      selectedColor: const Color(0xFF6C63FF),
                      backgroundColor: const Color(0xFF222230),
                      labelStyle: TextStyle(
                        color: _isNewPersonMode ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_isLoadingPeople)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                ),
              )
            else if (!_isNewPersonMode) ...[
              const Text('Select Person:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPersonId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1A26),
                    items: _knownPeople.map((p) {
                      final name = p['name'] as String? ?? 'Unknown';
                      final rel = p['relationship'] as String?;
                      return DropdownMenuItem<String>(
                        value: p['id'].toString(),
                        child: Text(
                          rel != null && rel.isNotEmpty ? '$name ($rel)' : name,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedPersonId = val),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Person Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'e.g. Olive',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F0F16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _relCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Relationship (Optional)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'e.g. Sister, Colleague',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F0F16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Enroll switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF6C63FF),
              title: const Text('Add to Recognition Photos', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text(
                'Helps live recognition identify this person everywhere.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              value: _enroll,
              onChanged: (val) => setState(() => _enroll = val),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMsg!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : _submitAssign,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save & Assign'),
        ),
      ],
    );
  }
}
