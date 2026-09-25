import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/face_recognition_result.dart' as frm;
import '../providers/recognition_provider.dart';
import '../widgets/memory_overlay_widget.dart';
import '../widgets/unknown_person_dialog.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  bool _debouncing  = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _initialized = true);
      _startLoop();
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _startLoop() {
    _debounce = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (_debouncing || !mounted) return;
      _debouncing = true;
      try {
        final xFile = await _controller!.takePicture();
        final bytes = await xFile.readAsBytes();
        await ref.read(recognitionProvider.notifier).recognize(bytes);
      } catch (e) {
        debugPrint('Frame capture error: $e');
      } finally {
        _debouncing = false;
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller?.dispose();
    ref.read(recognitionProvider.notifier).reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recState = ref.watch(recognitionProvider);
    final result   = recState.result;

    final isUnknown = result != null &&
        (result.state == frm.RecognitionState.unknownFace ||
         result.state == frm.RecognitionState.unnamedFace);
    final isKnown   = result?.state == frm.RecognitionState.knownFace;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ────────────────────────────────
          if (_initialized)
            CameraPreview(_controller!)
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),

          // ── Top bar ───────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/dashboard'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back,
                              color: Colors.white.withOpacity(0.8),
                              size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'DASHBOARD',
                            style: GoogleFonts.dmMono(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _LiveDot(),
                      const SizedBox(width: 7),
                      Text(
                        'LIVE RECOGNITION',
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Face bounding box overlay ──────────────────────
          if (result != null && result.matched)
            _FaceBoundingBox(isUnknown: isUnknown),

          // ── Memory overlay ────────────────────────────────
          if (isKnown && result?.memoryCue != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: MemoryOverlayWidget(cue: result!.memoryCue!),
            ),

          // ── Unknown face popup ────────────────────────────
          if (isUnknown && result != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: UnknownPersonDialog(result: result),
            ),

          // ── Processing indicator ──────────────────────────
          if (recState.isProcessing)
            const Positioned(
              top: 100,
              right: 16,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: AppTheme.brandGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandGreen.withOpacity(0.4),
                blurRadius: 3 + _ctrl.value * 5,
              ),
            ],
          ),
        ),
      );
}

class _FaceBoundingBox extends StatelessWidget {
  final bool isUnknown;
  const _FaceBoundingBox({required this.isUnknown});

  @override
  Widget build(BuildContext context) {
    final color = isUnknown ? AppTheme.brandRed : AppTheme.brandBlue;
    return Center(
      child: Container(
        width: 200,
        height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.8), width: 2),
          borderRadius: BorderRadius.circular(4),
          color: color.withOpacity(0.04),
        ),
      ),
    );
  }
}
