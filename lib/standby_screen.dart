import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api_service.dart';
import 'live_caption_service.dart';
import 'main.dart';
import 'name_prompt_dialog.dart';
import 'session_result_sheet.dart';
import 'wav_encoder.dart';

enum SessionState { idle, starting, recording, processing }

class StandbyScreen extends StatefulWidget {
  final VoidCallback? onExit;

  const StandbyScreen({super.key, this.onExit});

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();

  // Audio Recorder & Live Captions
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSubscription;
  final LiveCaptionService _captionService = LiveCaptionService();
  StreamSubscription<CaptionLine>? _finalCaptionSub;
  StreamSubscription<String>? _partialCaptionSub;

  SessionState _sessionState = SessionState.idle;
  bool _isMuted = false;
  double _audioLevel = 0.05; // 0.0 to 1.0

  // Active Session details
  String? _currentSessionId;
  DateTime? _recordingStartTime;
  DateTime? _lastSoundTime;
  Timer? _uiTimer;
  Timer? _pollTimer;
  int _secondsRecorded = 0;
  int _silenceRemaining = 15;

  // Audio Buffers
  final BytesBuilder _frameBuffer = BytesBuilder();
  final BytesBuilder _fullSessionPcm = BytesBuilder();

  // Captions Display
  final List<CaptionLine> _finalCaptions = [];
  String _partialCaption = '';

  @override
  void initState() {
    super.initState();

    // 🔄 Force Landscape orientation for Standby mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _initMicStream();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _pollTimer?.cancel();
    _micSubscription?.cancel();
    _finalCaptionSub?.cancel();
    _partialCaptionSub?.cancel();
    _audioRecorder.dispose();
    _captionService.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();

    // 🔄 Restore Portrait and Edge-to-Edge UI on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  /// 🎙️ Initialize Continuous Mic Streaming (16kHz PCM 16-bit Mono)
  Future<void> _initMicStream() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone access blocked.')),
          );
        }
        return;
      }

      final micStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _micSubscription = micStream.listen(_onMicPcmChunk);
    } catch (e) {
      print('Failed to start mic stream: $e');
    }
  }

  /// 📊 Handle raw incoming 16kHz PCM audio bytes from device microphone
  void _onMicPcmChunk(Uint8List chunk) {
    if (_isMuted || !mounted) return;

    // Calculate RMS volume level
    final rms = _calculateRms(chunk);
    final normalizedLevel = (rms * 8.0).clamp(0.05, 1.0);

    setState(() {
      _audioLevel = normalizedLevel;
    });

    // 1. Standby State: Phone listening only (nothing sent to server)
    if (_sessionState == SessionState.idle) {
      if (rms > 0.015) {
        // Speech detected! Start session with FastAPI backend host
        _startSession();
      }
      return;
    }

    // 2. Recording State: Streaming 100ms frames (~3200 bytes) over WebSocket to backend
    if (_sessionState == SessionState.recording) {
      _fullSessionPcm.add(chunk);
      _frameBuffer.add(chunk);

      // Track last sound timestamp for silence detector
      if (rms > 0.015) {
        _lastSoundTime = DateTime.now();
      }

      // Re-chunk into ~100ms (3200 bytes) frames for WebSocket streaming
      while (_frameBuffer.length >= 3200) {
        final frame = _frameBuffer.takeBytes();
        if (frame.length > 3200) {
          final toSend = frame.sublist(0, 3200);
          final remainder = frame.sublist(3200);
          _frameBuffer.add(remainder);
          _captionService.sendAudioChunk(toSend);
        } else {
          _captionService.sendAudioChunk(frame);
        }
      }
    }
  }

  /// 📐 Calculate RMS (Root Mean Square) volume level of 16-bit PCM audio samples
  double _calculateRms(Uint8List bytes) {
    if (bytes.isEmpty) return 0.0;
    final byteData = ByteData.sublistView(bytes);
    final sampleCount = bytes.length ~/ 2;
    if (sampleCount == 0) return 0.0;

    double sumSquares = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      final norm = sample / 32768.0;
      sumSquares += norm * norm;
    }
    return math.sqrt(sumSquares / sampleCount);
  }

  /// 🚀 Start a new session on FastAPI backend host (`POST /session/start` + WebSocket)
  Future<void> _startSession() async {
    if (_sessionState != SessionState.idle) return;

    setState(() {
      _sessionState = SessionState.starting;
      _finalCaptions.clear();
      _partialCaption = '';
      _frameBuffer.clear();
      _fullSessionPcm.clear();
    });

    final res = await ApiService.instance.startSession('audio');
    if (res == null || !res.containsKey('id')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start backend session.')),
        );
        setState(() {
          _sessionState = SessionState.idle;
        });
      }
      return;
    }

    _currentSessionId = res['id'].toString();

    // Setup Live Caption subscriptions
    _finalCaptionSub?.cancel();
    _partialCaptionSub?.cancel();

    _finalCaptionSub = _captionService.finalCaptions.listen((line) {
      if (mounted) {
        setState(() {
          _finalCaptions.add(line);
          _partialCaption = '';
        });
        _scrollToBottom();
      }
    });

    _partialCaptionSub = _captionService.partialCaption.listen((partial) {
      if (mounted) {
        setState(() {
          _partialCaption = partial;
        });
        _scrollToBottom();
      }
    });

    // Connect WebSocket
    final connected = await _captionService.connect(sessionId: _currentSessionId!);
    print('WebSocket live caption connection status: $connected');

    _recordingStartTime = DateTime.now();
    _lastSoundTime = DateTime.now();
    _secondsRecorded = 0;
    _silenceRemaining = 15;

    if (mounted) {
      setState(() {
        _sessionState = SessionState.recording;
      });
    }

    // Start 1-second UI & Silence timer
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _sessionState != SessionState.recording) return;

      final now = DateTime.now();
      final elapsed = now.difference(_recordingStartTime!).inSeconds;
      final silentFor = now.difference(_lastSoundTime!).inSeconds;
      final remaining = (15 - silentFor).clamp(0, 15);

      setState(() {
        _secondsRecorded = elapsed;
        _silenceRemaining = remaining;
      });

      // Auto-end session after 15 seconds of continuous silence
      if (silentFor >= 15) {
        _endSession();
      }
    });
  }

  /// ⏹️ End current session on backend (`POST /session/{id}/end` + poll result)
  Future<void> _endSession() async {
    if (_sessionState != SessionState.recording && _sessionState != SessionState.starting) return;

    _uiTimer?.cancel();
    final sessionId = _currentSessionId;
    setState(() {
      _sessionState = SessionState.processing;
    });

    // Send stop event on WebSocket channel
    await _captionService.stop();

    File? fallbackAudioFile;
    // Fallback: If WebSocket didn't receive PCM, prepare WAV upload
    if (!_captionService.isReady && _fullSessionPcm.length > 0) {
      try {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/session_$sessionId.wav');
        final wavData = pcm16ToWav(_fullSessionPcm.takeBytes());
        await file.writeAsBytes(wavData);
        fallbackAudioFile = file;
      } catch (e) {
        print('WAV fallback error: $e');
      }
    }

    if (sessionId != null) {
      // POST /session/{id}/end
      await ApiService.instance.endSession(sessionId, audioFile: fallbackAudioFile);

      // Poll GET /session/{id} until processing finishes
      _pollSessionResult(sessionId);
    } else {
      setState(() {
        _sessionState = SessionState.idle;
      });
    }
  }

  /// 🔄 Poll `GET /session/{id}` every second until state is `resolved` or `ended`
  void _pollSessionResult(String sessionId) {
    _pollTimer?.cancel();
    int pollAttempts = 0;

    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      pollAttempts++;
      if (pollAttempts > 300) { // 5 minutes timeout
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Processing timed out.')),
          );
          setState(() {
            _sessionState = SessionState.idle;
          });
        }
        return;
      }

      final result = await ApiService.instance.getSession(sessionId);
      if (result != null && mounted) {
        final status = result['status'] as String?;
        if (status == 'resolved' || status == 'ended') {
          timer.cancel();
          setState(() {
            _sessionState = SessionState.idle;
          });

          // Show session result sheet
          SessionResultSheet.show(
            context,
            result,
            onDismiss: () {
              if (result['needs_naming'] == true) {
                NamePromptDialog.show(context, sessionId: sessionId);
              }
            },
          );
        } else if (status == 'failed') {
          timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Session failed: ${result['error'] ?? 'Unknown error'}')),
            );
            setState(() {
              _sessionState = SessionState.idle;
            });
          }
        }
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        if (_sessionState == SessionState.recording) {
          _endSession();
        } else {
          _sessionState = SessionState.idle;
        }
        _audioLevel = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const [Color(0xFF090A10), Color(0xFF10121D), Color(0xFF141728)]
        : const [Color(0xFFEAEAFA), Color(0xFFF2F2FE), Color(0xFFF8F8FF)];

    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A28);
    final secondaryText = isDark ? Colors.white60 : const Color(0xFF666680);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🔝 TOP STATUS BAR & CONTROLS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back / Exit button
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryText),
                      tooltip: 'Exit Standby',
                      onPressed: () {
                        if (widget.onExit != null) {
                          widget.onExit!();
                        } else {
                          Navigator.maybePop(context);
                        }
                      },
                    ),

                    // State Indicator Pill
                    _buildStateBadge(),

                    // Theme, Manual Record/Stop & Mute Controls
                    Row(
                      children: [
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeNotifier,
                          builder: (context, mode, _) {
                            return IconButton(
                              icon: Icon(
                                mode == ThemeMode.dark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                color: primaryText,
                              ),
                              tooltip: 'Toggle Theme',
                              onPressed: () {
                                themeNotifier.value = mode == ThemeMode.dark
                                    ? ThemeMode.light
                                    : ThemeMode.dark;
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            color: _isMuted ? Colors.redAccent : const Color(0xFF6C63FF),
                          ),
                          tooltip: _isMuted ? 'Unmute Mic' : 'Mute Mic',
                          onPressed: _toggleMute,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 🎙️ MAIN LANDSCAPE CONTENT (AVATAR LEFT | LIVE CAPTIONS RIGHT)
              Expanded(
                child: Row(
                  children: [
                    // 🔴 LEFT: PERSON AVATAR & RADIAL WAVEFORM VISUALIZER
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            if (_sessionState == SessionState.idle) {
                              _startSession();
                            } else if (_sessionState == SessionState.recording) {
                              _endSession();
                            }
                          },
                          child: AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: RadialWaveformPainter(
                                  progress: _waveController.value,
                                  audioLevel: _audioLevel,
                                  isDark: isDark,
                                  sessionState: _sessionState,
                                ),
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  alignment: Alignment.center,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: _sessionState == SessionState.recording
                                            ? const [Color(0xFFFF4757), Color(0xFFFF6B81)]
                                            : const [Color(0xFF6C63FF), Color(0xFFFF6584)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_sessionState == SessionState.recording
                                                  ? Colors.redAccent
                                                  : const Color(0xFF6C63FF))
                                              .withOpacity(0.4 * _audioLevel + 0.2),
                                          blurRadius: 35 * _audioLevel + 15,
                                          spreadRadius: 10 * _audioLevel + 2,
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.transparent,
                                      child: Icon(
                                        _sessionState == SessionState.recording
                                            ? Icons.stop_rounded
                                            : Icons.person_rounded,
                                        size: 52,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // 📄 RIGHT: LIVE CAPTIONS STREAM (FROM FASTAPI BACKEND)
                    Expanded(
                      flex: 6,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(0, 10, 20, 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header label
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _sessionState == SessionState.recording
                                            ? const Color(0xFFFF4757)
                                            : (_sessionState == SessionState.processing
                                                ? const Color(0xFF3DFBD1)
                                                : Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'LIVE CAPTIONS (FASTAPI WHISPER)',
                                      style: TextStyle(
                                        color: secondaryText,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _sessionState == SessionState.recording
                                      ? 'STREAMING ⚡'
                                      : 'SERVER STANDBY',
                                  style: TextStyle(
                                    color: _sessionState == SessionState.recording
                                        ? Colors.green
                                        : secondaryText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Captions Stream List
                            Expanded(
                              child: ListView(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 20),
                                children: [
                                  // Finished captions (attributed by speaker)
                                  ..._finalCaptions.map((caption) {
                                    final isHost = caption.speaker == 'host';
                                    final dotColor = isHost
                                        ? const Color(0xFF3DFBD1)
                                        : const Color(0xFFFFB238);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 6, right: 10),
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: dotColor,
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  caption.speaker.toUpperCase(),
                                                  style: TextStyle(
                                                    color: dotColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  caption.text,
                                                  style: TextStyle(
                                                    color: primaryText,
                                                    fontSize: 16,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  // Utterance in progress (Partial caption)
                                  if (_partialCaption.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, bottom: 10),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 6, right: 10),
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF6C63FF),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              _partialCaption,
                                              style: TextStyle(
                                                color: primaryText.withOpacity(0.9),
                                                fontSize: 17,
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.w500,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  if (_finalCaptions.isEmpty && _partialCaption.isEmpty)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 40),
                                        child: Text(
                                          _isMuted
                                              ? 'Microphone is muted. Tap mic icon to unmute.'
                                              : (_sessionState == SessionState.recording
                                                  ? 'Listening & streaming audio to backend host...\nCaptions will appear here live.'
                                                  : 'Standby mode: Listening locally...\nStart speaking or tap avatar to initiate a voice session.'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: secondaryText,
                                            fontSize: 15,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateBadge() {
    String label;
    Color color;
    IconData icon;

    final String minStr = (_secondsRecorded ~/ 60).toString().padLeft(2, '0');
    final String secStr = (_secondsRecorded % 60).toString().padLeft(2, '0');

    if (_isMuted) {
      label = 'STANDBY • MUTED';
      color = Colors.grey;
      icon = Icons.mic_off_rounded;
    } else if (_sessionState == SessionState.processing) {
      label = 'Processing…';
      color = const Color(0xFF3DFBD1);
      icon = Icons.hourglass_top_rounded;
    } else if (_sessionState == SessionState.recording) {
      if (_silenceRemaining <= 10) {
        label = 'Rec $minStr:$secStr · Silence · ending in ${_silenceRemaining}s';
        color = const Color(0xFFFFB238);
        icon = Icons.timer_rounded;
      } else {
        label = 'Rec $minStr:$secStr · Listening';
        color = const Color(0xFFFF4757);
        icon = Icons.graphic_eq_rounded;
      }
    } else if (_sessionState == SessionState.starting) {
      label = 'Connecting…';
      color = const Color(0xFF6C63FF);
      icon = Icons.sync_rounded;
    } else {
      label = 'Standby · voice only';
      color = const Color(0xFF6C63FF);
      icon = Icons.settings_voice_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// 🎨 CUSTOM PAINTER FOR DYNAMIC RADIAL AUDIO WAVEFORM BARS
class RadialWaveformPainter extends CustomPainter {
  final double progress;
  final double audioLevel;
  final bool isDark;
  final SessionState sessionState;

  RadialWaveformPainter({
    required this.progress,
    required this.audioLevel,
    required this.isDark,
    required this.sessionState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 58.0;
    final numBars = 36;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < numBars; i++) {
      final angle = (i * 360 / numBars) * (math.pi / 180);
      final phaseShift = (i / numBars) * 2 * math.pi;

      final wave = math.sin(progress * 2 * math.pi + phaseShift);
      final barLength = 10 + (audioLevel * 50 * (0.5 + 0.5 * wave));

      final innerPoint = Offset(
        center.dx + baseRadius * math.cos(angle),
        center.dy + baseRadius * math.sin(angle),
      );

      final outerPoint = Offset(
        center.dx + (baseRadius + barLength) * math.cos(angle),
        center.dy + (baseRadius + barLength) * math.sin(angle),
      );

      Color barColor;
      if (sessionState == SessionState.recording) {
        barColor = Color.lerp(
          const Color(0xFFFF4757),
          const Color(0xFFFFB238),
          (i % 3) / 2.0,
        )!;
      } else if (sessionState == SessionState.processing) {
        barColor = const Color(0xFF3DFBD1);
      } else {
        barColor = (isDark ? Colors.white24 : Colors.black12);
      }

      paint.color = barColor.withOpacity(0.6 + 0.4 * wave.abs());
      paint.strokeWidth = 3.5;

      canvas.drawLine(innerPoint, outerPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RadialWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.sessionState != sessionState ||
        oldDelegate.isDark != isDark;
  }
}

