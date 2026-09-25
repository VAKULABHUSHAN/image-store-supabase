import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../models/face_recognition_result.dart';
import '../providers/persons_provider.dart';

class UnknownPersonDialog extends ConsumerStatefulWidget {
  final FaceRecognitionResult result;
  const UnknownPersonDialog({super.key, required this.result});

  @override
  ConsumerState<UnknownPersonDialog> createState() =>
      _UnknownPersonDialogState();
}

class _UnknownPersonDialogState extends ConsumerState<UnknownPersonDialog>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  bool _dismissed = false;
  bool _loading   = false;
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPerson() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiClient.postJson('/api/persons', {
        'name': _nameCtrl.text.trim(),
        'relationship': null,
        'embedding': <double>[],
        'image_url': null,
        'is_known': true,
      });
      await ref.read(personsProvider.notifier).refresh();
      if (mounted) setState(() => _dismissed = true);
    } catch (e) {
      debugPrint('Add person error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final isUnnamed = widget.result.state == RecognitionState.unnamedFace;
    final title = isUnnamed ? 'Who is this?' : 'New Face Detected';

    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: Container(
        width: 308,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────
            Row(
              children: [
                AnimatedBuilder(
                  animation: _dotCtrl,
                  builder: (_, __) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.brandRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandRed.withOpacity(0.35),
                          blurRadius: 3 + _dotCtrl.value * 5,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.syne(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _dismissed = true),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('✕',
                        style: GoogleFonts.dmMono(
                            fontSize: 11, color: AppTheme.inkFaint)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              isUnnamed
                  ? 'This face is in the database but unnamed. Enter a name to identify them.'
                  : '1 unidentified person in frame. Enter a name to register them.',
              style: GoogleFonts.dmMono(
                  fontSize: 11, color: AppTheme.inkLight, height: 1.55),
            ),

            const SizedBox(height: 12),

            // ── Input row ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: GoogleFonts.dmMono(
                        fontSize: 12, color: AppTheme.ink),
                    decoration: const InputDecoration(
                      hintText: 'Enter name…',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                    ),
                    onSubmitted: (_) => _addPerson(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _loading ? null : _addPerson,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.ink,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white),
                          )
                        : Text(
                            'ADD',
                            style: GoogleFonts.dmMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                              color: Colors.white,
                            ),
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
