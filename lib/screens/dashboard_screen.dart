import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../models/face_recognition_result.dart' as frm;
import '../providers/recognition_provider.dart';
import '../widgets/person_card_widget.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/unknown_person_dialog.dart';
import '../widgets/memory_overlay_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _cameraActive = false;
  Timer? _clock;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    if (mounted) setState(() => _time = '$h:$m:$s');
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final recState = ref.watch(recognitionProvider);
    final result   = recState.result;

    final knownCount   = result != null && result.matched && result.isKnown ? 1 : 0;
    final unknownCount = result != null &&
            (result.state == frm.RecognitionState.unknownFace ||
             result.state == frm.RecognitionState.unnamedFace)
        ? 1
        : 0;
    final inFrame = result != null && result.matched ? 1 : 0;

    final isUnknown = unknownCount > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Main layout: camera area + sidebar ──────────
          Row(
            children: [
              // ── Camera area placeholder ──────────────────
              Expanded(
                child: Stack(
                  children: [
                    // Camera feed (go to CameraScreen for live)
                    Container(
                      color: const Color(0xFF0A0A0A),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_outlined,
                                color: Colors.white.withOpacity(0.15),
                                size: 56),
                            const SizedBox(height: 16),
                            Text(
                              'TAP CAMERA TO START RECOGNITION',
                              style: GoogleFonts.dmMono(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.2),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: () => context.go('/camera'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.white.withOpacity(0.2)),
                                foregroundColor:
                                    Colors.white.withOpacity(0.5),
                                textStyle: GoogleFonts.dmMono(
                                    fontSize: 10, letterSpacing: 1.4),
                              ),
                              child: const Text('OPEN CAMERA'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Status bar ──────────────────────────
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _StatusBar(
                          cameraActive: _cameraActive,
                          faceCount: inFrame,
                          time: _time),
                    ),

                    // ── Memory overlay when face known ───────
                    if (result?.state == frm.RecognitionState.knownFace &&
                        result?.memoryCue != null)
                      Positioned(
                        bottom: 24,
                        left: 24,
                        child: MemoryOverlayWidget(cue: result!.memoryCue!),
                      ),
                  ],
                ),
              ),

              // ── Sidebar ──────────────────────────────────
              _Sidebar(
                time: _time,
                inFrame: inFrame,
                knownCount: knownCount,
                unknownCount: unknownCount,
                result: result,
                onSignOut: _signOut,
                onNav: (path) => context.go(path),
              ),
            ],
          ),

          // ── Unknown face popup ───────────────────────────
          if (isUnknown && result != null)
            Positioned(
              bottom: 24,
              left: 24,
              child: UnknownPersonDialog(result: result),
            ),
        ],
      ),
    );
  }
}

// ── Status Bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final bool cameraActive;
  final int faceCount;
  final String time;

  const _StatusBar({
    required this.cameraActive,
    required this.faceCount,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(0.06))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatusDot(active: cameraActive),
          const SizedBox(width: 7),
          Text(
            cameraActive ? 'LIVE' : 'OFFLINE',
            style: AppTheme.monoLabel,
          ),
          const SizedBox(width: 12),
          Text('|',
              style: AppTheme.monoLabel
                  .copyWith(color: AppTheme.inkGhost, fontSize: 12)),
          const SizedBox(width: 12),
          Text(
            '$faceCount FACE${faceCount != 1 ? 'S' : ''} DETECTED',
            style: AppTheme.monoLabel,
          ),
          const Spacer(),
          Text(time,
              style: AppTheme.monoLabel
                  .copyWith(letterSpacing: 0.6, fontSize: 10)),
        ],
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  final bool active;
  const _StatusDot({required this.active});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppTheme.brandGreen : AppTheme.inkGhost;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final blur = widget.active ? (3 + _ctrl.value * 4) : 0.0;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: widget.active
                ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: blur)]
                : null,
          ),
        );
      },
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final String time;
  final int inFrame;
  final int knownCount;
  final int unknownCount;
  final frm.FaceRecognitionResult? result;
  final VoidCallback onSignOut;
  final void Function(String) onNav;

  const _Sidebar({
    required this.time,
    required this.inFrame,
    required this.knownCount,
    required this.unknownCount,
    required this.result,
    required this.onSignOut,
    required this.onNav,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              children: [
                _PulseDot(active: inFrame > 0),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('PERSONALENS', style: AppTheme.brandText),
                ),
                // Nav buttons
                _IconBtn(
                  icon: Icons.people_outline,
                  onTap: () => onNav('/persons'),
                  tooltip: 'Persons',
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.videocam_outlined,
                  onTap: () => onNav('/camera'),
                  tooltip: 'Camera',
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.logout,
                  onTap: onSignOut,
                  tooltip: 'Sign out',
                ),
              ],
            ),
          ),

          // ── Stats strip ───────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceAlt,
              border: Border(
                  bottom: BorderSide(color: AppTheme.borderLight)),
            ),
            child: Row(
              children: [
                _StatCell(value: inFrame.toString(),    label: 'IN FRAME'),
                _Divider(),
                _StatCell(value: knownCount.toString(), label: 'IDENTIFIED'),
                _Divider(),
                _StatCell(value: unknownCount.toString(), label: 'UNKNOWN'),
              ],
            ),
          ),

          // ── Detected people label ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text('DETECTED PEOPLE', style: AppTheme.sectionLabel),
          ),

          // ── Face cards ────────────────────────────────────
          Expanded(
            child: result != null && result!.matched && result!.person != null
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                    children: [
                      PersonCardWidget(
                        person: result!.person!,
                        isUnknown: result!.state == frm.RecognitionState.unknownFace ||
                            result!.state == frm.RecognitionState.unnamedFace,
                        confidence: result!.matchDistance != null
                            ? (1 - result!.matchDistance!).clamp(0.0, 1.0)
                            : null,
                        memoryCue: result!.memoryCue,
                      ),
                    ],
                  )
                : _EmptyState(),
          ),

          // ── Interaction log ───────────────────────────────
          const AudioRecorderWidget(),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final bool active;
  const _PulseDot({required this.active});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppTheme.brandGreen : AppTheme.inkGhost;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final blur = widget.active ? (3 + _ctrl.value * 5) : 0.0;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: widget.active
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: blur)]
                : null,
          ),
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 15, color: AppTheme.inkFaint),
          ),
        ),
      );
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: AppTheme.statNum),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.sectionLabel),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: AppTheme.border,
      );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('◎',
                style: TextStyle(fontSize: 26, color: AppTheme.inkGhost)),
            const SizedBox(height: 8),
            Text('No faces in frame', style: AppTheme.monoSmall),
          ],
        ),
      );
}
