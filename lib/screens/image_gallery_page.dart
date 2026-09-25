/// image_gallery_page.dart
/// Full gallery of persons with their snapshots, logs, detail sheets, and
/// all specified function signatures.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/person_model.dart';
import '../models/interaction_model.dart';
import '../models/snapshot_upload_response.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Main Page
// ═════════════════════════════════════════════════════════════════════════════

class ImageGalleryPage extends StatefulWidget {
  const ImageGalleryPage({super.key});

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  List<PersonModel> _persons = [];
  bool _loading = true;
  String? _error;

  // Signed URL cache: person_id → url
  final Map<String, String> _signedUrls = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  // ── _loadImages ───────────────────────────────────────
  Future<void> _loadImages() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await ApiClient.get('/api/persons');
      final persons = (raw as List<dynamic>)
          .map((e) => PersonModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _persons = persons;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load gallery.'; _loading = false; });
    }
  }

  // ── _deleteImage ──────────────────────────────────────
  Future<void> _deleteImage(String personId) async {
    try {
      await ApiClient.delete('/api/persons/$personId');
      setState(() {
        _persons.removeWhere((p) => p.id == personId);
        _signedUrls.remove(personId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Person removed.',
                style: PLFonts.mono(size: 12, color: Colors.white)),
            backgroundColor: PLColors.textPrimary,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  // ── _confirmDelete ────────────────────────────────────
  Future<void> _confirmDelete(PersonModel person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PLColors.border),
        ),
        title: Text('DELETE PERSON',
            style: PLFonts.syne(size: 14, letterSpacing: 0.14)),
        content: Text(
          'Remove "${person.name ?? 'this person'}" and all their data? This cannot be undone.',
          style: PLFonts.mono(size: 12, color: PLColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: PLFonts.mono(color: PLColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PLColors.unknown,
              foregroundColor: Colors.white,
            ),
            child: Text('DELETE',
                style: PLFonts.mono(
                    size: 12, weight: FontWeight.w500, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteImage(person.id);
  }

  // ── _showAddPersonDialog ──────────────────────────────
  Future<void> _showAddPersonDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddPersonDialog(
        onSaved: (person) {
          setState(() => _persons.insert(0, person));
        },
      ),
    );
  }

  // ── _saveNewPerson (called internally via dialog) ─────
  /// Exposed so tests / dialog can call it directly.
  Future<PersonModel?> _saveNewPerson({
    required String name,
    String? relationship,
    File? imageFile,
  }) async {
    try {
      // 1. Create person record
      final raw = await ApiClient.postJson('/api/persons', {
        'name':         name.isEmpty ? null : name,
        'relationship': relationship,
        'embedding':    <double>[],
        'image_url':    null,
        'is_known':     name.isNotEmpty,
      });
      final person = PersonModel.fromJson(raw as Map<String, dynamic>);

      // 2. Optionally upload snapshot
      if (imageFile != null) {
        final bytes   = await imageFile.readAsBytes();
        final imgFile = http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename:    'snapshot.jpg',
          contentType: MediaType('image', 'jpeg'),
        );
        final snapRaw = await ApiClient.uploadMultipart(
          '/api/persons/${person.id}/snapshot',
          [imgFile],
        );
        final snap = SnapshotUploadResponse.fromJson(
            snapRaw as Map<String, dynamic>);
        if (snap.signedUrl != null) {
          _signedUrls[person.id] = snap.signedUrl!;
        }
      }

      return person;
    } on ApiException {
      return null;
    }
  }

  // ── _openDetailSheet ──────────────────────────────────
  Future<void> _openDetialSheet(PersonModel person) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonDetailSheet(
        person:    person,
        signedUrl: _signedUrls[person.id],
        onDeleted: () {
          setState(() {
            _persons.removeWhere((p) => p.id == person.id);
            _signedUrls.remove(person.id);
          });
        },
        onUpdated: (updated) {
          setState(() {
            final idx = _persons.indexWhere((p) => p.id == updated.id);
            if (idx >= 0) _persons[idx] = updated;
          });
        },
      ),
    );
  }

  // ── _fullscreenImage ──────────────────────────────────
  void _fullscreenImage(BuildContext context, String signedUrl) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImageView(url: signedUrl),
      ),
    );
  }

  // ── _buildBody ────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 40, color: PLColors.textFaint),
            const SizedBox(height: 12),
            Text(_error!,
                style:
                    PLFonts.mono(size: 12, color: PLColors.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadImages,
                child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_persons.isEmpty) {
      return _EmptyPreview(onAdd: _showAddPersonDialog);
    }
    return RefreshIndicator(
      onRefresh: _loadImages,
      color: PLColors.known,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   2,
          crossAxisSpacing: 12,
          mainAxisSpacing:  12,
          childAspectRatio: 0.78,
        ),
        itemCount: _persons.length,
        itemBuilder: (ctx, i) => _GalleryTile(
          person:    _persons[i],
          signedUrl: _signedUrls[_persons[i].id],
          onTap:     () => _openDetialSheet(_persons[i]),
          onDelete:  () => _confirmDelete(_persons[i]),
          onImageTap: _signedUrls[_persons[i].id] != null
              ? () => _fullscreenImage(ctx, _signedUrls[_persons[i].id]!)
              : null,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLColors.shell,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => context.go('/upload'),
        ),
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
            Text('GALLERY',
                style: PLFonts.syne(size: 13, letterSpacing: 0.16)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: PLColors.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: PLColors.border),
              ),
              child: Text('${_persons.length}',
                  style: PLFonts.mono(
                      size: 10,
                      color: PLColors.textMuted)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadImages,
            color: PLColors.textMuted,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined, size: 20),
            onPressed: _showAddPersonDialog,
            color: PLColors.textPrimary,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _GalleryTile (gallery tile widget)
// ═════════════════════════════════════════════════════════════════════════════

class _GalleryTile extends StatelessWidget {
  final PersonModel person;
  final String?     signedUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onImageTap;

  const _GalleryTile({
    required this.person,
    required this.onTap,
    required this.onDelete,
    this.signedUrl,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = getAvatarColorsRecord(person.name);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: PLColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PLColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image area
            Expanded(
              child: GestureDetector(
                onTap: onImageTap,
                child: signedUrl != null
                    ? Image.network(
                        signedUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _AvatarPlaceholder(name: person.name),
                      )
                    : _AvatarPlaceholder(name: person.name),
              ),
            ),

            // Info bar
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          person.name ?? 'Unknown',
                          style: PLFonts.syne(
                              size: 12,
                              color: PLColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: person.isKnown
                              ? PLColors.knownBg
                              : PLColors.unknownBg,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          person.isKnown ? 'ID' : 'NEW',
                          style: PLFonts.mono(
                            size: 7,
                            letterSpacing: 0.1,
                            color: person.isKnown
                                ? PLColors.knownText
                                : PLColors.unknownText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (person.relationship != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      person.relationship!,
                      style: PLFonts.mono(
                          size: 9, color: PLColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onTap,
                          child: Text(
                            'VIEW →',
                            style: PLFonts.mono(
                                size: 9,
                                letterSpacing: 0.12,
                                color: PLColors.textMuted),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Icon(Icons.delete_outline,
                            size: 14, color: PLColors.textFaint),
                      ),
                    ],
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

class _AvatarPlaceholder extends StatelessWidget {
  final String? name;
  const _AvatarPlaceholder({this.name});

  @override
  Widget build(BuildContext context) {
    final colors = getAvatarColorsRecord(name);
    return Container(
      color: colors.bg,
      child: Center(
        child: Text(
          (name ?? '?')[0].toUpperCase(),
          style: PLFonts.syne(
              size: 48, weight: FontWeight.w700, color: colors.fg),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _PersonDetailSheet  +  _loadLogs
// ═════════════════════════════════════════════════════════════════════════════

class _PersonDetailSheet extends StatefulWidget {
  final PersonModel      person;
  final String?          signedUrl;
  final VoidCallback     onDeleted;
  final ValueChanged<PersonModel> onUpdated;

  const _PersonDetailSheet({
    required this.person,
    required this.onDeleted,
    required this.onUpdated,
    this.signedUrl,
  });

  @override
  State<_PersonDetailSheet> createState() => _PersonDetailSheetState();
}

class _PersonDetailSheetState extends State<_PersonDetailSheet> {
  InteractionModel? _interaction;
  bool _loadingLogs = true;
  bool _deleting    = false;

  @override
  void initState() {
    super.initState();
    _loadlogs();
  }

  // ── _loadlogs ─────────────────────────────────────────
  Future<void> _loadlogs() async {
    setState(() => _loadingLogs = true);
    try {
      final raw = await ApiClient.get(
          '/api/interactions/${widget.person.id}');
      setState(() {
        _interaction = InteractionModel.fromJson(
            raw as Map<String, dynamic>);
        _loadingLogs = false;
      });
    } on ApiException catch (e) {
      // 404 = no interaction yet — show empty state
      if (e.statusCode == 404) {
        setState(() { _interaction = null; _loadingLogs = false; });
      } else {
        setState(() => _loadingLogs = false);
      }
    } catch (_) {
      setState(() => _loadingLogs = false);
    }
  }

  Future<void> _deletePerson() async {
    setState(() => _deleting = true);
    try {
      await ApiClient.delete('/api/persons/${widget.person.id}');
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDeleted();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize:     0.95,
      minChildSize:     0.4,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: PLColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
              top:   BorderSide(color: PLColors.border),
              left:  BorderSide(color: PLColors.border),
              right: BorderSide(color: PLColors.border)),
        ),
        child: CustomScrollView(
          controller: controller,
          slivers: [
            // Handle
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 16),
                  decoration: BoxDecoration(
                    color: PLColors.textFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Profile card
            SliverToBoxAdapter(
              child: _ProfileCard(
                person:    widget.person,
                signedUrl: widget.signedUrl,
                onDelete:  _deletePerson,
                deleting:  _deleting,
                onFullscreen: widget.signedUrl != null
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) =>
                                _FullscreenImageView(url: widget.signedUrl!),
                          ),
                        );
                      }
                    : null,
              ),
            ),

            // Interaction logs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'INTERACTION LOG',
                  style: PLFonts.mono(
                      size: 9,
                      letterSpacing: 0.18,
                      color: PLColors.textLight),
                ),
              ),
            ),

            if (_loadingLogs)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else if (_interaction == null)
              SliverToBoxAdapter(
                child: _LogEmpty(),
              )
            else
              SliverToBoxAdapter(
                child: _LogCards(interaction: _interaction!),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _ProfileCard
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  final PersonModel      person;
  final String?          signedUrl;
  final VoidCallback     onDelete;
  final bool             deleting;
  final VoidCallback?    onFullscreen;

  const _ProfileCard({
    required this.person,
    required this.onDelete,
    required this.deleting,
    this.signedUrl,
    this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = getAvatarColorsRecord(person.name);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: PLColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PLColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar / photo
            GestureDetector(
              onTap: onFullscreen,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 64,
                  color: colors.bg,
                  child: signedUrl != null
                      ? Image.network(signedUrl!, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            (person.name ?? '?')[0].toUpperCase(),
                            style: PLFonts.syne(
                                size: 28, color: colors.fg),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name ?? 'Unnamed',
                      style: PLFonts.syne(size: 16)),
                  if (person.relationship != null) ...[
                    const SizedBox(height: 2),
                    Text(person.relationship!,
                        style: PLFonts.mono(
                            size: 11, color: PLColors.textMuted)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Badge(
                        label: person.isKnown ? 'IDENTIFIED' : 'UNKNOWN',
                        bg: person.isKnown
                            ? PLColors.knownBg
                            : PLColors.unknownBg,
                        fg: person.isKnown
                            ? PLColors.knownText
                            : PLColors.unknownText,
                      ),
                      const SizedBox(width: 6),
                      _Badge(
                        label: person.isActive ? 'ACTIVE' : 'INACTIVE',
                        bg: PLColors.card,
                        fg: PLColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Delete button
            deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: PLColors.textFaint),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  bg;
  final Color  fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: PLFonts.mono(size: 8, letterSpacing: 0.12, color: fg)),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// Log widgets
// ═════════════════════════════════════════════════════════════════════════════

class _LogEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 32, color: PLColors.textFaint),
            const SizedBox(height: 10),
            Text('No interactions yet',
                style: PLFonts.mono(
                    size: 12, color: PLColors.textFaint)),
          ],
        ),
      );
}

class _LogCards extends StatelessWidget {
  final InteractionModel interaction;
  const _LogCards({required this.interaction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            if (interaction.firstSummary != null)
              _LogEntry(
                tag:  'FIRST',
                date: interaction.firstOccurredAt,
                text: interaction.firstSummary!,
              ),
            if (interaction.lastSummary != null) ...[
              const SizedBox(height: 10),
              _LogEntry(
                tag:  'LAST',
                date: interaction.lastOccurredAt,
                text: interaction.lastSummary!,
              ),
            ],
          ],
        ),
      );
}

class _LogEntry extends StatelessWidget {
  final String    tag;
  final DateTime? date;
  final String    text;
  const _LogEntry({required this.tag, required this.text, this.date});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PLColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PLColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tag,
                    style: PLFonts.mono(
                        size: 8,
                        letterSpacing: 0.16,
                        color: PLColors.textFaint)),
                const Spacer(),
                if (date != null)
                  Text(
                    '${date!.day}/${date!.month}/${date!.year}',
                    style: PLFonts.mono(
                        size: 9, color: PLColors.textFaint),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(text,
                style: PLFonts.mono(
                    size: 11, color: PLColors.textSecondary)),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// _FullscreenImageView
// ═════════════════════════════════════════════════════════════════════════════

class _FullscreenImageView extends StatelessWidget {
  final String url;
  const _FullscreenImageView({required this.url});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white38,
                size: 60,
              ),
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// _EmptyPreview
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyPreview extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyPreview({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('◎',
                style: TextStyle(
                    fontSize: 52, color: PLColors.textFaint)),
            const SizedBox(height: 14),
            Text('No people in gallery',
                style: PLFonts.syne(
                    size: 14, color: PLColors.textFaint)),
            const SizedBox(height: 6),
            Text('Add someone to get started',
                style: PLFonts.mono(
                    size: 11, color: PLColors.textFaint)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: Text('ADD PERSON',
                  style: PLFonts.mono(
                      size: 12,
                      weight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: 0.1)),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14)),
            ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// _AddPersonDialog  +  _AddPersonDialogState
// ═════════════════════════════════════════════════════════════════════════════

class _AddPersonDialog extends StatefulWidget {
  final ValueChanged<PersonModel> onSaved;
  const _AddPersonDialog({required this.onSaved});

  @override
  State<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<_AddPersonDialog> {
  final _nameCtrl         = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  final _formKey          = GlobalKey<FormState>();

  File?  _imageFile;
  bool   _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relationshipCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) {
      setState(() => _imageFile = File(xfile.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      // Create person
      final raw = await ApiClient.postJson('/api/persons', {
        'name':         _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        'relationship': _relationshipCtrl.text.trim().isEmpty
            ? null
            : _relationshipCtrl.text.trim(),
        'embedding':    <double>[],
        'image_url':    null,
        'is_known':     _nameCtrl.text.trim().isNotEmpty,
      });
      PersonModel person =
          PersonModel.fromJson(raw as Map<String, dynamic>);

      // Optionally upload snapshot
      if (_imageFile != null) {
        final bytes   = await _imageFile!.readAsBytes();
        final imgFile = http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename:    'snapshot.jpg',
          contentType: MediaType('image', 'jpeg'),
        );
        await ApiClient.uploadMultipart(
          '/api/persons/${person.id}/snapshot',
          [imgFile],
        );
      }

      widget.onSaved(person);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Failed to save person.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PLColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: PLColors.border),
      ),
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
          Text('ADD PERSON',
              style: PLFonts.syne(
                  size: 14, letterSpacing: 0.14)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: PLColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PLColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                size: 24, color: PLColors.textFaint),
                            const SizedBox(height: 6),
                            Text('Optional photo',
                                style: PLFonts.mono(
                                    size: 9, color: PLColors.textFaint)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // Name
              Text('NAME',
                  style: PLFonts.mono(
                      size: 9,
                      letterSpacing: 0.16,
                      color: PLColors.textLight)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                style: PLFonts.mono(color: PLColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Enter name…'),
              ),
              const SizedBox(height: 12),

              // Relationship
              Text('RELATIONSHIP',
                  style: PLFonts.mono(
                      size: 9,
                      letterSpacing: 0.16,
                      color: PLColors.textLight)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _relationshipCtrl,
                style: PLFonts.mono(color: PLColors.textPrimary),
                decoration: const InputDecoration(
                    hintText: 'Friend, colleague…'),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PLColors.unknownBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: PLFonts.mono(
                          size: 11, color: PLColors.unknown)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: PLFonts.mono(color: PLColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('SAVE',
                  style: PLFonts.mono(
                      size: 12,
                      weight: FontWeight.w500,
                      color: Colors.white)),
        ),
      ],
    );
  }
}
