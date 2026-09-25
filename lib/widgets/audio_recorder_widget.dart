import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme.dart';
import '../providers/recognition_provider.dart';
import '../providers/interactions_provider.dart';

class AudioRecorderWidget extends ConsumerStatefulWidget {
  const AudioRecorderWidget({super.key});

  @override
  ConsumerState<AudioRecorderWidget> createState() =>
      _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends ConsumerState<AudioRecorderWidget>
    with SingleTickerProviderStateMixin {
  final _recorder  = AudioRecorder();
  bool _recording  = false;
  bool _processing = false;
  String? _recordPath;
  String? _transcript;
  String? _summary;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir  = await getTemporaryDirectory();
    _recordPath = '${dir.path}/interaction_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordPath!,
    );
    setState(() => _recording = true);
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (path == null) return;

    final recState = ref.read(recognitionProvider);
    final personId = recState.result?.person?.id;
    if (personId == null) return;

    setState(() => _processing = true);
    try {
      final bytes = await File(path).readAsBytes();
      final interaction = await ref
          .read(interactionsProvider.notifier)
          .postInteraction(personId: personId, audioBytes: bytes);

      setState(() {
        _transcript = interaction?.lastTranscript;
        _summary    = interaction?.lastSummary;
        _processing = false;
      });
    } catch (e) {
      setState(() => _processing = false);
      debugPrint('Audio upload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INTERACTION LOG', style: AppTheme.sectionLabel),
          const SizedBox(height: 8),

          // ── Mic button ───────────────────────────────────
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final borderColor = _recording
                  ? AppTheme.brandRed.withOpacity(
                      0.3 + _pulseCtrl.value * 0.2)
                  : AppTheme.border;

              return GestureDetector(
                onTap: _processing
                    ? null
                    : (_recording ? _stopRecording : _startRecording),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _recording
                        ? const Color(0xFFFFF5F5)
                        : AppTheme.surface,
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _recording ? '⏹' : '⏺',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _processing
                            ? 'Processing…'
                            : _recording
                                ? 'Stop Recording'
                                : 'Start Recording',
                        style: GoogleFonts.dmMono(
                          fontSize: 11,
                          letterSpacing: 0.7,
                          color: _recording
                              ? AppTheme.brandRed
                              : AppTheme.inkLight,
                        ),
                      ),
                      if (_processing) ...[
                        const Spacer(),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppTheme.inkFaint),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Transcript ───────────────────────────────────
          if (_transcript != null) ...[
            const SizedBox(height: 8),
            _LogBlock(tag: 'TRANSCRIPT', text: _transcript!),
          ],

          // ── Summary ──────────────────────────────────────
          if (_summary != null) ...[
            const SizedBox(height: 6),
            _LogBlock(tag: 'SUMMARY', text: _summary!),
          ],
        ],
      ),
    );
  }
}

class _LogBlock extends StatelessWidget {
  final String tag;
  final String text;
  const _LogBlock({required this.tag, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.borderLight),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tag, style: AppTheme.monoLabel),
            const SizedBox(height: 4),
            Text(
              text,
              style: GoogleFonts.dmMono(
                  fontSize: 10,
                  color: AppTheme.inkLight,
                  height: 1.6),
            ),
          ],
        ),
      );
}
