/// store_image_page.dart
/// Purpose: Dedicated screen to attach a new snapshot to an existing person.
/// Flow: pick image → upload to /api/persons/:id/snapshot → show signed URL.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/person_model.dart';
import '../models/snapshot_upload_response.dart';

class StoreImagePage extends StatefulWidget {
  /// The person whose snapshot we are updating.
  final String personId;

  const StoreImagePage({super.key, required this.personId});

  @override
  State<StoreImagePage> createState() => _StoreImagePageState();
}

class _StoreImagePageState extends State<StoreImagePage> {
  PersonModel? _person;
  File?        _pickedFile;
  String?      _signedUrl;
  bool         _loadingPerson = true;
  bool         _uploading     = false;
  String?      _error;
  String?      _successMsg;

  @override
  void initState() {
    super.initState();
    _loadPerson();
  }

  // ── Load person ───────────────────────────────────────
  Future<void> _loadPerson() async {
    try {
      final raw = await ApiClient.get('/api/persons/${widget.personId}');
      setState(() {
        _person        = PersonModel.fromJson(raw as Map<String, dynamic>);
        _loadingPerson = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loadingPerson = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load person.'; _loadingPerson = false; });
    }
  }

  // ── Pick image ────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (xfile == null) return;
    setState(() {
      _pickedFile  = File(xfile.path);
      _signedUrl   = null;
      _error       = null;
      _successMsg  = null;
    });
  }

  // ── Upload snapshot ───────────────────────────────────
  Future<void> _uploadSnapshot() async {
    if (_pickedFile == null) return;
    setState(() { _uploading = true; _error = null; _successMsg = null; });
    try {
      final bytes   = await _pickedFile!.readAsBytes();
      final imgFile = http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename:    'snapshot.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      final raw  = await ApiClient.uploadMultipart(
        '/api/persons/${widget.personId}/snapshot',
        [imgFile],
      );
      final snap = SnapshotUploadResponse.fromJson(
          raw as Map<String, dynamic>);
      setState(() {
        _signedUrl  = snap.signedUrl;
        _successMsg = 'Snapshot saved successfully.';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLColors.shell,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _person != null
              ? 'SNAPSHOT — ${(_person!.name ?? 'PERSON').toUpperCase()}'
              : 'STORE IMAGE',
          style: PLFonts.syne(size: 13, letterSpacing: 0.14),
        ),
      ),
      body: _loadingPerson
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Person info banner
                  if (_person != null) _PersonBanner(person: _person!),
                  const SizedBox(height: 20),

                  // Image preview area
                  _ImageBox(
                    file:       _pickedFile,
                    signedUrl:  _signedUrl,
                    onTap:      _pickImage,
                  ),
                  const SizedBox(height: 16),

                  // Feedback
                  if (_error != null) _FeedbackBanner(message: _error!, isError: true),
                  if (_successMsg != null) _FeedbackBanner(message: _successMsg!, isError: false),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickImage,
                          icon: const Icon(Icons.photo_library_outlined, size: 15),
                          label: Text('SELECT',
                              style: PLFonts.mono(
                                  size: 11,
                                  letterSpacing: 0.1,
                                  color: PLColors.textSecondary)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: PLColors.border),
                            backgroundColor: PLColors.surface,
                            foregroundColor: PLColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_pickedFile == null || _uploading)
                              ? null
                              : _uploadSnapshot,
                          icon: _uploading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload_outlined, size: 16),
                          label: Text(
                            _uploading ? 'UPLOADING…' : 'SAVE SNAPSHOT',
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
                ],
              ),
            ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PersonBanner extends StatelessWidget {
  final PersonModel person;
  const _PersonBanner({required this.person});

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
            radius: 18,
            backgroundColor: colors.bg,
            child: Text(
              (person.name ?? '?')[0].toUpperCase(),
              style: PLFonts.syne(size: 15, color: colors.fg),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.name ?? 'Unnamed',
                  style: PLFonts.syne(size: 14)),
              if (person.relationship != null)
                Text(person.relationship!,
                    style: PLFonts.mono(
                        size: 10, color: PLColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  final File? file;
  final String? signedUrl;
  final VoidCallback onTap;

  const _ImageBox({required this.file, required this.signedUrl, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 240,
          decoration: BoxDecoration(
            color: PLColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PLColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: file != null
              ? Image.file(file!, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 40, color: PLColors.textFaint),
                    const SizedBox(height: 12),
                    Text('TAP TO SELECT',
                        style: PLFonts.mono(
                            size: 10,
                            letterSpacing: 0.14,
                            color: PLColors.textFaint)),
                  ],
                ),
        ),
      );
}

class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isError ? PLColors.unknownBg : PLColors.knownBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isError
                ? PLColors.unknown.withOpacity(0.2)
                : PLColors.live.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 14,
              color: isError ? PLColors.unknown : PLColors.live,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: PLFonts.mono(
                  size: 11,
                  color: isError ? PLColors.unknown : PLColors.knownText,
                ),
              ),
            ),
          ],
        ),
      );
}
