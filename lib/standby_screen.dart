import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';

enum VoiceState { idle, listening, speaking }

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

  VoiceState _voiceState = VoiceState.idle;
  bool _isMuted = false;
  double _audioLevel = 0.2; // 0.0 to 1.0

  // Live transcript lines
  final List<Map<String, dynamic>> _transcriptHistory = [];
  String _currentSpokenText = '';
  Timer? _speechSimulationTimer;
  Timer? _levelTimer;

  // Sample phrases for voice assistant demo
  final List<String> _samplePhrases = [
    "Hello PersonaLens, can you identify the person in front of me?",
    "Log a memory about meeting Alex today at the coffee shop.",
    "Show me interactions from last Tuesday with Sarah.",
    "Remind me of John's preferences and past conversation details.",
    "Add audio note: Discussed the new project roadmap and deliverables.",
  ];

  int _phraseIndex = 0;

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
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _startSimulatedAudioLevels();
    _startSimulatedSpeechStream();
  }

  @override
  void dispose() {
    _speechSimulationTimer?.cancel();
    _levelTimer?.cancel();
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

  void _startSimulatedAudioLevels() {
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      if (_isMuted) {
        setState(() {
          _audioLevel = 0.05;
          _voiceState = VoiceState.idle;
        });
        return;
      }

      final random = math.Random();
      if (_voiceState == VoiceState.speaking) {
        setState(() {
          _audioLevel = 0.4 + random.nextDouble() * 0.6; // High levels
        });
      } else if (_voiceState == VoiceState.listening) {
        setState(() {
          _audioLevel = 0.15 + random.nextDouble() * 0.25; // Moderate levels
        });
      } else {
        setState(() {
          _audioLevel = 0.05 + random.nextDouble() * 0.1; // Low idle pulse
        });
      }
    });
  }

  void _startSimulatedSpeechStream() {
    // Periodically simulate user speaking phrases
    _speechSimulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _isMuted) return;

      _simulateSpeechPhrase(_samplePhrases[_phraseIndex]);
      _phraseIndex = (_phraseIndex + 1) % _samplePhrases.length;
    });
  }

  void _simulateSpeechPhrase(String phrase) async {
    if (_isMuted) return;

    setState(() {
      _voiceState = VoiceState.listening;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _isMuted) return;

    setState(() {
      _voiceState = VoiceState.speaking;
      _currentSpokenText = '';
    });

    final words = phrase.split(' ');
    for (int i = 0; i < words.length; i++) {
      await Future.delayed(Duration(milliseconds: 250 + math.Random().nextInt(150)));
      if (!mounted || _isMuted) return;

      setState(() {
        _currentSpokenText += (i == 0 ? '' : ' ') + words[i];
      });
      _scrollToBottom();
    }

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Push finished phrase into history
    if (_currentSpokenText.isNotEmpty) {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      setState(() {
        _transcriptHistory.add({
          'text': _currentSpokenText,
          'time': timeStr,
        });
        _currentSpokenText = '';
        _voiceState = VoiceState.idle;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _voiceState = VoiceState.idle;
        _currentSpokenText = '';
      }
    });
  }

  void _handleManualTrigger() {
    if (_voiceState == VoiceState.idle) {
      _simulateSpeechPhrase(_samplePhrases[math.Random().nextInt(_samplePhrases.length)]);
    }
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

                    // Theme & Mute Controls
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

              // 🎙️ MAIN LANDSCAPE CONTENT (AVATAR LEFT | TRANSCRIPTION RIGHT)
              Expanded(
                child: Row(
                  children: [
                    // 🔴 LEFT: PERSON AVATAR & RADIAL WAVEFORM
                    Expanded(
                      flex: 4,
                      child: GestureDetector(
                        onTap: _handleManualTrigger,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: RadialWaveformPainter(
                                  progress: _waveController.value,
                                  audioLevel: _audioLevel,
                                  isDark: isDark,
                                  voiceState: _voiceState,
                                ),
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF6C63FF).withOpacity(0.4 * _audioLevel + 0.2),
                                          blurRadius: 30 * _audioLevel + 15,
                                          spreadRadius: 8 * _audioLevel + 2,
                                        ),
                                      ],
                                    ),
                                    child: const CircleAvatar(
                                      backgroundColor: Colors.transparent,
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 48,
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

                    // 📄 RIGHT: LIVE TRANSCRIPTION STREAM
                    Expanded(
                      flex: 6,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(0, 10, 20, 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.white.withOpacity(0.7),
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
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _voiceState == VoiceState.speaking
                                        ? const Color(0xFFFF6584)
                                        : (_voiceState == VoiceState.listening
                                            ? const Color(0xFF00E5FF)
                                            : Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'LIVE TRANSCRIPTION',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Transcription text list
                            Expanded(
                              child: ListView(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 20),
                                children: [
                                  // Past history
                                  ..._transcriptHistory.map((item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['time'] ?? '',
                                              style: TextStyle(
                                                color: secondaryText.withOpacity(0.5),
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item['text'] ?? '',
                                              style: TextStyle(
                                                color: primaryText.withOpacity(0.65),
                                                fontSize: 17,
                                                height: 1.4,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),

                                  // Active live spoken text
                                  if (_currentSpokenText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, bottom: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFF6C63FF),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Speaking now...',
                                                style: TextStyle(
                                                  color: const Color(0xFF6C63FF),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _currentSpokenText,
                                            style: const TextStyle(
                                              color: Color(0xFF6C63FF),
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (_transcriptHistory.isEmpty)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 40),
                                        child: Text(
                                          _isMuted
                                              ? 'Microphone is muted. Tap mic icon to enable.'
                                              : 'Listening for speech...\nSpeak naturally to see live transcription.',
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

    if (_isMuted) {
      label = 'STANDBY • MUTED';
      color = Colors.grey;
      icon = Icons.mic_off_rounded;
    } else if (_voiceState == VoiceState.speaking) {
      label = 'TRANSCRIBING LIVE';
      color = const Color(0xFFFF6584);
      icon = Icons.graphic_eq_rounded;
    } else if (_voiceState == VoiceState.listening) {
      label = 'LISTENING...';
      color = const Color(0xFF00E5FF);
      icon = Icons.hearing_rounded;
    } else {
      label = 'STANDBY • READY';
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
  final VoiceState voiceState;

  RadialWaveformPainter({
    required this.progress,
    required this.audioLevel,
    required this.isDark,
    required this.voiceState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 55.0;
    final numBars = 36;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < numBars; i++) {
      final angle = (i * 360 / numBars) * (math.pi / 180);
      final phaseShift = (i / numBars) * 2 * math.pi;

      // Dynamic bar height based on amplitude and sine animation
      final wave = math.sin(progress * 2 * math.pi + phaseShift);
      final barLength = 10 + (audioLevel * 45 * (0.5 + 0.5 * wave));

      final innerPoint = Offset(
        center.dx + baseRadius * math.cos(angle),
        center.dy + baseRadius * math.sin(angle),
      );

      final outerPoint = Offset(
        center.dx + (baseRadius + barLength) * math.cos(angle),
        center.dy + (baseRadius + barLength) * math.sin(angle),
      );

      // Color palette based on voice state
      Color barColor;
      if (voiceState == VoiceState.speaking) {
        barColor = Color.lerp(
          const Color(0xFF6C63FF),
          const Color(0xFFFF6584),
          (i % 3) / 2.0,
        )!;
      } else if (voiceState == VoiceState.listening) {
        barColor = Color.lerp(
          const Color(0xFF00E5FF),
          const Color(0xFF6C63FF),
          (i % 3) / 2.0,
        )!;
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
        oldDelegate.voiceState != voiceState ||
        oldDelegate.isDark != isDark;
  }
}
