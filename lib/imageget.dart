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

// ═══════════════════════════════════════════════════════════════
//  GALLERY PAGE
// ═══════════════════════════════════════════════════════════════
class ImageGalleryPage extends StatefulWidget {
  const ImageGalleryPage({super.key});

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  List<Map<String, dynamic>> _images    = [];
  bool                       _isLoading = true;
  String?                    _error;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    debugPrint('════════════════════════════════');
    debugPrint('🔄 _loadImages() START');
    setState(() { _isLoading = true; _error = null; });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      debugPrint('👤 User ID: ${user.id}');

      final data = await supabase
          .from('face_embeddings')
          .select('id, image_url, known_person_id, captured_at, known_persons(id, name, relationship)')
          .eq('user_id', user.id)
          .order('captured_at', ascending: false);

      debugPrint('📦 face_embeddings rows fetched: ${(data as List).length}');

      final List<Map<String, dynamic>> images = [];

      for (final row in data) {
        final personMap          = row['known_persons'] as Map<String, dynamic>?;
        final personName         = personMap?['name'] as String?;
        final personRelationship = personMap?['relationship'] as String?;
        final knownPersonId      = row['known_person_id']?.toString() ?? '';

        debugPrint('────────────────────────────────');
        debugPrint('🖼  Embedding ID   : ${row['id']}');
        debugPrint('🧑  personName     : $personName');
        debugPrint('💞  relationship   : $personRelationship');
        debugPrint('🔑  knownPersonId  : "$knownPersonId"');
        debugPrint('🗺  personMap      : $personMap');

        final isUnknown = personName == null ||
            personName.trim().isEmpty ||
            personName == 'Unassigned';

        debugPrint('❓  isUnknown      : $isUnknown');

        String? lastSummary;
        String? lastSeenAt;
        String? lastTranscript;

        if (knownPersonId.isNotEmpty) {
          debugPrint('🔍 Fetching interaction_summaries for knownPersonId=$knownPersonId');
          try {
            final summaryRows = await supabase
                .from('interaction_summaries')
                .select('last_summary, last_occurred_at')
                .eq('known_person_id', knownPersonId)
                .limit(1);

            debugPrint('📋 interaction_summaries rows returned: ${summaryRows.length}');

            if (summaryRows.isNotEmpty) {
              debugPrint('📋 Raw summary row: ${summaryRows[0]}');
              lastSummary = summaryRows[0]['last_summary'] as String?;
              lastSeenAt  = summaryRows[0]['last_occurred_at'] as String?;
              debugPrint('✅ lastSummary  : "$lastSummary"');
              debugPrint('✅ lastSeenAt   : "$lastSeenAt"');
            } else {
              debugPrint('⚠️  No rows in interaction_summaries for this person');
            }

            if (lastSummary == null || lastSummary.trim().isEmpty) {
              debugPrint('🔍 Summary empty — falling back to interaction_logs');
              final logRows = await supabase
                  .from('interaction_logs')
                  .select('transcript, occurred_at')
                  .eq('known_person_id', knownPersonId)
                  .order('occurred_at', ascending: false)
                  .limit(1);

              debugPrint('📋 interaction_logs rows returned: ${logRows.length}');

              if (logRows.isNotEmpty) {
                debugPrint('📋 Raw log row: ${logRows[0]}');
                lastTranscript = logRows[0]['transcript'] as String?;
                lastSeenAt     = logRows[0]['occurred_at'] as String?;
                debugPrint('✅ lastTranscript: "$lastTranscript"');
                debugPrint('✅ lastSeenAt    : "$lastSeenAt"');
              } else {
                debugPrint('⚠️  No rows in interaction_logs for this person either');
              }
            }
          } catch (e) {
            debugPrint('❌ Summary/log fetch EXCEPTION for $knownPersonId: $e');
          }
        } else {
          debugPrint('⛔ knownPersonId is empty — skipping summary fetch');
        }

        final finalConvo = (lastSummary?.isNotEmpty == true)
            ? lastSummary
            : (lastTranscript?.isNotEmpty == true)
            ? lastTranscript
            : null;

        debugPrint('💬 finalConvo going into map: "$finalConvo"');

        images.add({
          'id':                  row['id'].toString(),
          'image_url':           row['image_url'] as String,
          'known_person_id':     knownPersonId,
          'person_name':         isUnknown ? 'Unknown Person' : personName!,
          'person_relationship': isUnknown ? null : personRelationship,
          'is_unknown':          isUnknown,
          'captured_at':         row['captured_at'] ?? '',
          'last_summary':        lastSummary,
          'last_transcript':     lastTranscript,
          'last_seen_at':        lastSeenAt,
        });
      }

      debugPrint('════════════════════════════════');
      debugPrint('✅ _loadImages() DONE — ${images.length} cards built');
      setState(() => _images = images);
    } catch (e) {
      debugPrint('❌ LOAD ERROR: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteImage(String id, String imageUrl) async {
    try {
      try {
        final uri      = Uri.parse(imageUrl);
        final segments = uri.pathSegments;
        final facesIdx = segments.indexOf('faces');
        final filePath = facesIdx != -1
            ? segments.sublist(facesIdx + 1).join('/')
            : segments.last;
        await supabase.storage.from('faces').remove([filePath]);
      } catch (storageErr) {
        debugPrint('Storage remove skipped/failed: $storageErr');
      }

      await supabase.from('face_embeddings').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Image deleted')));
      await _loadImages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  void _confirmDelete(String id, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12)),
        title: const Text('Delete Image?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { Navigator.pop(context); _deleteImage(id, imageUrl); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPersonDialog(String embeddingId) async {
    final nameCtrl         = TextEditingController();
    final relationshipCtrl = TextEditingController();
    final formKey          = GlobalKey<FormState>();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _AddPersonDialog(
          formKey:          formKey,
          nameCtrl:         nameCtrl,
          relationshipCtrl: relationshipCtrl,
          onSave: (name, relationship) async {
            await _saveNewPerson(embeddingId: embeddingId, name: name, relationship: relationship);
            await _loadImages();
          },
        ),
      );
    } finally {
      nameCtrl.dispose();
      relationshipCtrl.dispose();
    }
  }

  Future<void> _saveNewPerson({
    required String embeddingId,
    required String name,
    required String relationship,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final patientRows = await supabase
        .from('patients')
        .select('id')
        .eq('full_name', 'Default Patient')
        .limit(1);

    late String patientId;
    if (patientRows.isEmpty) {
      final ins = await supabase
          .from('patients')
          .insert({'full_name': 'Default Patient'})
          .select('id')
          .single();
      patientId = ins['id'] as String;
    } else {
      patientId = patientRows[0]['id'] as String;
    }

    final newPerson = await supabase
        .from('known_persons')
        .insert({
      'patient_id':   patientId,
      'name':         name,
      'relationship': relationship.isEmpty ? 'unknown' : relationship,
      'user_id':      user.id,
    })
        .select('id')
        .single();

    final newPersonId = newPerson['id'] as String;

    await supabase
        .from('face_embeddings')
        .update({'known_person_id': newPersonId})
        .eq('id', embeddingId)
        .eq('user_id', user.id);
  }

  void _openDetailSheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PersonDetailSheet(item: item),
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
        title: Text('My Gallery',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
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
            icon: Icon(Icons.refresh_rounded, color: iconColor),
            onPressed: _loadImages,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF6C63FF)),
            SizedBox(height: 16),
            Text('Loading your gallery…', style: TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadImages,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
              ),
            ],
          ),
        ),
      );
    }

    if (_images.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_album_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('No images yet.\nUpload your first one!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF1A1A24),
      onRefresh: _loadImages,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          itemCount: _images.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   2,
            crossAxisSpacing: 12,
            mainAxisSpacing:  12,
            childAspectRatio: 0.52,
          ),
          itemBuilder: (context, index) {
            final item         = _images[index];
            final url          = item['image_url'] as String;
            final id           = item['id'] as String;
            final name         = item['person_name'] as String;
            final isUnknown    = item['is_unknown'] as bool;
            final relationship = item['person_relationship'] as String?;
            final rawSummary   = item['last_summary'] as String?;
            final rawTranscript= item['last_transcript'] as String?;
            final lastSeenAt   = item['last_seen_at'] as String?;

            final lastConvo = (rawSummary?.isNotEmpty == true)
                ? rawSummary
                : (rawTranscript?.isNotEmpty == true)
                ? rawTranscript
                : null;

            // ── Per-tile render log ──
            debugPrint('🃏 Tile[$index] name=$name | summary="$rawSummary" | transcript="$rawTranscript" | lastConvo="$lastConvo"');

            return _GalleryTile(
              url:          url,
              personName:   name,
              relationship: relationship,
              isUnknown:    isUnknown,
              lastConvo:    lastConvo,
              lastSeenAt:   lastSeenAt,
              onDelete:     () => _confirmDelete(id, url),
              onTap:        () => _openDetailSheet(item),
              onAddPerson:  isUnknown ? () => _showAddPersonDialog(id) : null,
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  GALLERY TILE
// ═══════════════════════════════════════════════════════════════
class _GalleryTile extends StatelessWidget {
  final String        url;
  final String        personName;
  final String?       relationship;
  final bool          isUnknown;
  final String?       lastConvo;
  final String?       lastSeenAt;
  final VoidCallback  onDelete;
  final VoidCallback  onTap;
  final VoidCallback? onAddPerson;

  const _GalleryTile({
    required this.url,
    required this.personName,
    required this.isUnknown,
    required this.onDelete,
    required this.onTap,
    this.relationship,
    this.lastConvo,
    this.lastSeenAt,
    this.onAddPerson,
  });

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24) return '${diff.inHours}h ago';
      if (diff.inDays    < 7)  return '${diff.inDays}d ago';
      return '${dt.day} ${_month(dt.month)}';
    } catch (_) { return ''; }
  }

  String _month(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  @override
  Widget build(BuildContext context) {
    final hasConvo = lastConvo != null && lastConvo!.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnknown ? Colors.orangeAccent.withOpacity(0.4) : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFF0F0F14),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF0F0F14),
                        child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 32),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.delete_rounded, size: 16, color: Colors.redAccent),
                      ),
                    ),
                  ),
                  if (lastSeenAt != null)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text(_formatTime(lastSeenAt),
                            style: const TextStyle(color: Colors.white70, fontSize: 9)),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isUnknown ? Icons.help_outline_rounded : Icons.person_rounded,
                          size: 13,
                          color: isUnknown ? Colors.orangeAccent : const Color(0xFF6C63FF),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(personName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUnknown ? Colors.orangeAccent : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    ),
                    if (!isUnknown && relationship != null && relationship!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.people_rounded, size: 11, color: Colors.white38),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(relationship!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ),
                    ],
                    if (hasConvo) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFF6C63FF)),
                                SizedBox(width: 4),
                                Text('Last summary',
                                    style: TextStyle(
                                        color: Color(0xFF6C63FF),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(lastConvo!,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 10, height: 1.4)),
                          ],
                        ),
                      ),
                    ] else if (!isUnknown) ...[
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 10, color: Colors.white24),
                          SizedBox(width: 4),
                          Text('No conversations yet',
                              style: TextStyle(color: Colors.white24, fontSize: 10)),
                        ],
                      ),
                    ],
  const SizedBox(height: 6),
                    if (isUnknown && onAddPerson != null)
                      GestureDetector(
                        onTap: onAddPerson,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add_alt_1_rounded, size: 11, color: Color(0xFF6C63FF)),
                              SizedBox(width: 4),
                              Text('Add Person',
                                  style: TextStyle(
                                      color: Color(0xFF6C63FF), fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PERSON DETAIL BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════
class _PersonDetailSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  const _PersonDetailSheet({required this.item});

  @override
  State<_PersonDetailSheet> createState() => _PersonDetailSheetState();
}

class _PersonDetailSheetState extends State<_PersonDetailSheet> {
  List<Map<String, dynamic>> _logs      = [];
  bool                       _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final knownPersonId = widget.item['known_person_id'] as String;
    debugPrint('📜 _loadLogs() — knownPersonId="$knownPersonId"');

    if (knownPersonId.isEmpty) {
      debugPrint('⛔ _loadLogs() — knownPersonId is empty, skipping');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final rows = await supabase
          .from('interaction_logs')
          .select('transcript, occurred_at')
          .eq('known_person_id', knownPersonId)
          .order('occurred_at', ascending: false)
          .limit(20);

      debugPrint('📜 interaction_logs rows: ${rows.length}');
      for (final r in rows as List) {
        debugPrint('   → occurred_at=${r['occurred_at']} | transcript="${r['transcript']}"');
      }

      setState(() {
        _logs = (rows).map((r) => r as Map<String, dynamic>).toList();
      });
    } catch (e) {
      debugPrint('❌ Log fetch error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatFull(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day} ${_month(dt.month)} ${dt.year}  •  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  String _month(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  @override
  Widget build(BuildContext context) {
    final name         = widget.item['person_name']        as String;
    final isUnknown    = widget.item['is_unknown']          as bool;
    final imageUrl     = widget.item['image_url']           as String;
    final lastSummary  = widget.item['last_summary']        as String?;
    final relationship = widget.item['person_relationship'] as String?;

    debugPrint('🪟 _PersonDetailSheet build — name=$name | lastSummary="$lastSummary"');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:     0.4,
      maxChildSize:     0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56, height: 56,
                        color: const Color(0xFF0F0F14),
                        child: const Icon(Icons.person, color: Colors.white24),
                      )),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: isUnknown ? Colors.orangeAccent : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      if (!isUnknown && relationship != null && relationship.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.people_rounded, size: 12, color: Color(0xFF6C63FF)),
                            const SizedBox(width: 4),
                            Text(relationship,
                                style: const TextStyle(
                                    color: Color(0xFF6C63FF), fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text('${_logs.length} interaction${_logs.length == 1 ? '' : 's'} recorded',
                          style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (lastSummary != null && lastSummary.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 13, color: Color(0xFF6C63FF)),
                        SizedBox(width: 6),
                        Text('AI Summary',
                            style: TextStyle(
                                color: Color(0xFF6C63FF), fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(lastSummary,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Conversation History',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _logs.isEmpty
                ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.white24),
                  SizedBox(height: 10),
                  Text('No conversations recorded yet',
                      style: TextStyle(color: Colors.white38, fontSize: 14)),
                ],
              ),
            )
                : ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: _logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final log        = _logs[i];
                final transcript = log['transcript'] as String?;
                final occurredAt = log['occurred_at'] as String?;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 11, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(_formatFull(occurredAt),
                              style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                      if (transcript != null && transcript.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 6),
                        Text(transcript,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12, height: 1.5)),
                      ] else ...[
                        const SizedBox(height: 6),
                        const Text('No transcript recorded',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  FULLSCREEN IMAGE VIEWER
// ═══════════════════════════════════════════════════════════════
class _FullscreenImage extends StatelessWidget {
  final String url;
  const _FullscreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════
class _ProfileCard extends StatelessWidget {
  final String?      email;
  final VoidCallback onLogout;

  const _ProfileCard({required this.email, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1A24) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A24);
    final subText = isDark ? Colors.white38 : const Color(0xFF777788);
    final cardBorder = isDark ? Colors.white12 : Colors.black12;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF6C63FF),
              child: Text(
                (email != null && email!.isNotEmpty) ? email![0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logged in as', style: TextStyle(color: subText, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(email ?? 'Loading…',
                      style: TextStyle(color: primaryText, fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              onPressed: onLogout,
              icon: Icon(Icons.logout, color: isDark ? Colors.redAccent : Colors.red),
              tooltip: 'Logout',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_rounded, size: 64, color: Colors.white24),
        SizedBox(height: 12),
        Text('Tap to select an image', style: TextStyle(color: Colors.white38, fontSize: 15)),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  const _SourceButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: const BorderSide(color: Colors.white12),
        backgroundColor: const Color(0xFF1A1A24),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ADD PERSON DIALOG
// ═══════════════════════════════════════════════════════════════
class _AddPersonDialog extends StatefulWidget {
  final GlobalKey<FormState>    formKey;
  final TextEditingController   nameCtrl;
  final TextEditingController   relationshipCtrl;
  final Future<void> Function(String name, String relationship) onSave;

  const _AddPersonDialog({
    required this.formKey,
    required this.nameCtrl,
    required this.relationshipCtrl,
    required this.onSave,
  });

  @override
  State<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<_AddPersonDialog> {
  bool    _isSaving = false;
  String? _errorMsg;

  Future<void> _handleSave() async {
    if (!widget.formKey.currentState!.validate()) return;

    setState(() { _isSaving = true; _errorMsg = null; });

    try {
      await widget.onSave(
        widget.nameCtrl.text.trim(),
        widget.relationshipCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSaving = false; _errorMsg = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6C63FF), size: 22),
          SizedBox(width: 10),
          Text('Add Person', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: widget.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: widget.nameCtrl,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.next,
                decoration: _buildInputDecoration('Full name', Icons.badge_rounded),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: widget.relationshipCtrl,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleSave(),
                decoration: _buildInputDecoration('Relationship  (e.g. Friend, Parent)', Icons.people_rounded),
              ),
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMsg!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: const Color(0xFF0F0F14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }
}