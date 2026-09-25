import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/face_recognition_result.dart';
import '../models/person_model.dart';
import '../models/snapshot_upload_response.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  // ── State ─────────────────────────────────────────────
  String? _userId;
  File?   _pickedImage;
  bool    _recognizing  = false;
  bool    _uploading    = false;
  String? _statusMsg;
  FaceRecognitionResult? _recognitionResult;
  PersonModel? _resolvedPerson;
  String? _previewSignedUrl;

  @override
  void initState() {
    super.initState();
    _getUser();
  }

  // ── _getUser ──────────────────────────────────────────
  Future<void> _getUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }
    setState(() => _userId = user.id);
  }

  // ── _pickImage ────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (xfile == null) return;
    setState(() {
      _pickedImage        = File(xfile.path);
      _recognitionResult  = null;
      _resolvedPerson     = null;
      _previewSignedUrl   = null;
      _statusMsg          = null;
    });
  }

  // ── _recognizeFace ────────────────────────────────────
  Future<void> _recognizeFace() async {
    if (_pickedImage == null) return;
    setState(() { _recognizing = true; _statusMsg = 'Recognizing face…'; });
    try {
      final bytes = await _pickedImage!.readAsBytes();
      final file  = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename:    'face.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      final raw    = await ApiClient.uploadMultipart('/api/face/recognize', [file]);
      final result = FaceRecognitionResult.fromJson(raw as Map<String, dynamic>);
      setState(() => _recognitionResult = result);
      await _resolvePersonFromRecognition(result);
    } on ApiException catch (e) {
      setState(() => _statusMsg = e.message);
    } catch (e) {
      setState(() => _statusMsg = 'Recognition failed: $e');
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }

  // ── _resolvePersonFromRecognition ─────────────────────
  Future<void> _resolvePersonFromRecognition(FaceRecognitionResult result) async {
    if (result.noFaceDetected) {
      setState(() => _statusMsg = 'No face detected in image.');
      return;
    }
    if (result.identified && result.person != null) {
      setState(() {
        _resolvedPerson = result.person;
        _statusMsg      = 'Identified: ${result.person!.name ?? 'Known person'}';
      });
      return;
    }
    if (result.needsIdentity && result.person != null) {
      setState(() {
        _resolvedPerson = result.person;
        _statusMsg      = 'Face matched — identity needed.';
      });
      if (mounted) await _showRecognitionDialog(result);
      return;
    }
    if (result.unknownFace) {
      setState(() => _statusMsg = 'Unknown face — you can save as new person.');
      if (mounted) await _showRecognitionDialog(result);
    }
  }

  // ── _showRecognitionDialog ────────────────────────────
  Future<void> _showRecognitionDialog(FaceRecognitionResult result) async {
    final nameCtrl         = TextEditingController();
    final relationshipCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PLColors.border),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: PLColors.unknown,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  result.needsIdentity ? 'WHO IS THIS?' : 'NEW FACE',
                  style: PLFonts.syne(
                    size: 14,
                    letterSpacing: 0.14,
                    color: PLColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.needsIdentity
                  ? 'This face is in the system but not yet named. Add their details.'
                  : 'An unidentified person was detected. Register them?',
              style: PLFonts.mono(size: 11, color: PLColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text('NAME', style: PLFonts.mono(size: 9, letterSpacing: 0.16, color: PLColors.textLight)),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              style: PLFonts.mono(color: PLColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Enter name…'),
            ),
            const SizedBox(height: 12),
            Text('RELATIONSHIP', style: PLFonts.mono(size: 9, letterSpacing: 0.16, color: PLColors.textLight)),
            const SizedBox(height: 6),
            TextField(
              controller: relationshipCtrl,
              style: PLFonts.mono(color: PLColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Friend, colleague…'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Skip', style: PLFonts.mono(color: PLColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (result.needsIdentity && result.person != null) {
                // Confirm existing unnamed person
                await _confirmPerson(
                  result.person!.id,
                  nameCtrl.text.trim(),
                  relationshipCtrl.text.trim().isEmpty
                      ? null
                      : relationshipCtrl.text.trim(),
                );
              } else {
                // Create new person + save snapshot
                final defaultId = await _resolveDefaultKnowPersonId();
                await _uploadAndSave(
                  nameCtrl.text.trim(),
                  relationshipCtrl.text.trim().isEmpty
                      ? null
                      : relationshipCtrl.text.trim(),
                  existingPersonId: defaultId,
                );
              }
            },
            child: Text(
              'SAVE',
              style: PLFonts.mono(
                  size: 12, weight: FontWeight.w500, color: Colors.white),
            ),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    relationshipCtrl.dispose();
  }

  // ── _confirmPerson (confirm unnamed match) ────────────
  Future<void> _confirmPerson(
      String personId, String name, String? relationship) async {
    if (name.isEmpty) return;
    setState(() { _uploading = true; _statusMsg = 'Saving identity…'; });
    try {
      final raw = await ApiClient.patchJson(
        '/api/persons/$personId/confirm',
        {'name': name, 'relationship': relationship},
      );
      final person = PersonModel.fromJson(raw as Map<String, dynamic>);
      setState(() {
        _resolvedPerson = person;
        _statusMsg      = 'Identity saved: $name';
      });
    } on ApiException catch (e) {
      setState(() => _statusMsg = e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── _uploadAndSave ────────────────────────────────────
  Future<void> _uploadAndSave(
    String name,
    String? relationship, {
    String? existingPersonId,
  }) async {
    if (_pickedImage == null) return;
    setState(() { _uploading = true; _statusMsg = 'Saving person…'; });
    try {
      String personId = existingPersonId ?? '';

      if (personId.isEmpty) {
        // Create new person record
        final raw = await ApiClient.postJson('/api/persons', {
          'name':         name.isEmpty ? null : name,
          'relationship': relationship,
          'embedding':    <double>[], // backend will compute from snapshot
          'image_url':    null,
          'is_known':     name.isNotEmpty,
        });
        personId = (raw as Map<String, dynamic>)['id'] as String;
        final person = PersonModel.fromJson(raw);
        setState(() => _resolvedPerson = person);
      }

      // Upload snapshot — backend computes embedding
      final bytes = await _pickedImage!.readAsBytes();
      final imgFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename:    'snapshot.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      final snapRaw = await ApiClient.uploadMultipart(
        '/api/persons/$personId/snapshot',
        [imgFile],
      );
      final snap = SnapshotUploadResponse.fromJson(
          snapRaw as Map<String, dynamic>);
      setState(() {
        _previewSignedUrl = snap.signedUrl;
        _statusMsg        = 'Saved! ${name.isNotEmpty ? name : 'Person'} registered.';
      });
    } on ApiException catch (e) {
      setState(() => _statusMsg = e.message);
    } catch (e) {
      setState(() => _statusMsg = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── _resolveDefaultKnowPersonId ───────────────────────
  /// Returns null — triggers creating a brand-new person in _uploadAndSave.
  /// Override this if you want to link to a default/unknown person record.
  Future<String?> _resolveDefaultKnowPersonId() async => null;

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLColors.shell,
      appBar: AppBar(
        backgroundColor: PLColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: PLColors.live,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text('PERSONALENS',
                style: PLFonts.syne(size: 13, letterSpacing: 0.16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/gallery'),
            child: Text('Gallery →',
                style: PLFonts.mono(size: 11, color: PLColors.textMuted)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) context.go('/login');
            },
            child: Text('Sign Out',
                style: PLFonts.mono(size: 11, color: PLColors.textMuted)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image preview ─────────────────────────
            _ImagePreview(
              pickedImage:     _pickedImage,
              previewSignedUrl: _previewSignedUrl,
              onPick:          _pickImage,
            ),
            const SizedBox(height: 20),

            // ── Status ────────────────────────────────
            if (_statusMsg != null) _StatusCard(message: _statusMsg!),
            const SizedBox(height: 12),

            // ── Recognition result card ───────────────
            if (_recognitionResult != null && _resolvedPerson != null)
              _PersonResultCard(person: _resolvedPerson!),
            if (_recognitionResult != null && _resolvedPerson != null)
              const SizedBox(height: 16),

            // ── Action buttons ────────────────────────
            Row(
              children: [
                Expanded(
                  child: _PLOutlineButton(
                    label: 'PICK IMAGE',
                    icon: Icons.photo_library_outlined,
                    onPressed: (_recognizing || _uploading) ? null : _pickImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_pickedImage == null ||
                            _recognizing ||
                            _uploading)
                        ? null
                        : _recognizeFace,
                    icon: (_recognizing || _uploading)
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.face_retouching_natural, size: 16),
                    label: Text(
                      _recognizing
                          ? 'SCANNING…'
                          : _uploading
                              ? 'SAVING…'
                              : 'RECOGNIZE',
                      style: PLFonts.mono(
                          size: 11,
                          weight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0.1),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Stats section ─────────────────────────
            if (_userId != null) _StatsStrip(userId: _userId!),
          ],
        ),
      ),
    );
  }
}

// ── _ImagePreview ─────────────────────────────────────────────────────────────
class _ImagePreview extends StatelessWidget {
  final File? pickedImage;
  final String? previewSignedUrl;
  final VoidCallback onPick;

  const _ImagePreview({
    required this.pickedImage,
    required this.previewSignedUrl,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          color: PLColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PLColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: pickedImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(pickedImage!, fit: BoxFit.cover),
                  if (previewSignedUrl != null)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: PLColors.knownBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: PLColors.live.withOpacity(0.3)),
                        ),
                        child: Text(
                          '✓ SAVED',
                          style: PLFonts.mono(
                              size: 9,
                              letterSpacing: 0.14,
                              color: PLColors.knownText),
                        ),
                      ),
                    ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 40, color: PLColors.textFaint),
                  const SizedBox(height: 12),
                  Text('TAP TO SELECT IMAGE',
                      style: PLFonts.mono(
                          size: 10,
                          letterSpacing: 0.14,
                          color: PLColors.textFaint)),
                ],
              ),
      ),
    );
  }
}

// ── _StatusCard ───────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final String message;
  const _StatusCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: PLColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PLColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 14, color: PLColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: PLFonts.mono(size: 11, color: PLColors.textMuted)),
            ),
          ],
        ),
      );
}

// ── _PersonResultCard ─────────────────────────────────────────────────────────
class _PersonResultCard extends StatelessWidget {
  final PersonModel person;
  const _PersonResultCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final colors = getAvatarColorsRecord(person.name);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PLColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PLColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.bg,
            child: Text(
              (person.name ?? '?')[0].toUpperCase(),
              style: PLFonts.syne(size: 16, color: colors.fg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name ?? 'Unnamed',
                  style: PLFonts.syne(size: 14),
                ),
                if (person.relationship != null)
                  Text(
                    person.relationship!,
                    style: PLFonts.mono(
                        size: 10, color: PLColors.textMuted),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: person.isKnown
                  ? PLColors.knownBg
                  : PLColors.unknownBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              person.isKnown ? 'ID' : 'NEW',
              style: PLFonts.mono(
                size: 8,
                letterSpacing: 0.12,
                color: person.isKnown
                    ? PLColors.knownText
                    : PLColors.unknownText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _PLOutlineButton ──────────────────────────────────────────────────────────
class _PLOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PLOutlineButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          style: PLFonts.mono(
              size: 11,
              letterSpacing: 0.1,
              color: PLColors.textSecondary),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: PLColors.border),
          backgroundColor: PLColors.surface,
          foregroundColor: PLColors.textSecondary,
        ),
      );
}

// ── _StatsStrip ───────────────────────────────────────────────────────────────
class _StatsStrip extends StatefulWidget {
  final String userId;
  const _StatsStrip({required this.userId});

  @override
  State<_StatsStrip> createState() => _StatsStripState();
}

class _StatsStripState extends State<_StatsStrip> {
  int _total   = 0;
  int _known   = 0;
  int _unknown = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await ApiClient.get('/api/persons');
      final list = (raw as List<dynamic>)
          .map((e) => PersonModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _total   = list.length;
        _known   = list.where((p) => p.isKnown).length;
        _unknown = list.where((p) => !p.isKnown).length;
        _loaded  = true;
      });
    } catch (_) {
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: PLColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PLColors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _StatCell(value: _total,   label: 'TOTAL'),
          _Divider(),
          _StatCell(value: _known,   label: 'IDENTIFIED'),
          _Divider(),
          _StatCell(value: _unknown, label: 'UNKNOWN'),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final int value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text('$value',
                style: PLFonts.syne(size: 24, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: PLFonts.mono(
                    size: 8,
                    letterSpacing: 0.16,
                    color: PLColors.textLight)),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 32,
        color: PLColors.border,
      );
}
