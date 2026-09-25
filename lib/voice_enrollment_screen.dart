import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api_service.dart';

class VoiceEnrollmentScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const VoiceEnrollmentScreen({super.key, this.onCompleted});

  @override
  State<VoiceEnrollmentScreen> createState() => _VoiceEnrollmentScreenState();
}

class _VoiceEnrollmentScreenState extends State<VoiceEnrollmentScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isEnrolled = false;
  int _secondsRecorded = 0;
  Timer? _timer;
  String? _recordedPath;

  final String _sampleText =
      "Please read aloud:\n\"Hello PersonaLens, this is my voice. I am enrolling my voice so you can distinguish me from others during our conversations.\"";

  @override
  void initState() {
    super.initState();
    _checkVoiceStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _checkVoiceStatus() async {
    final status = await ApiService.instance.getVoiceStatus();
    if (mounted) {
      setState(() {
        _isEnrolled = status;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required for voice enrollment.')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      _recordedPath = '${dir.path}/voice_enroll_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
        path: _recordedPath!,
      );

      setState(() {
        _isRecording = true;
        _secondsRecorded = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() {
            _secondsRecorded++;
          });
        }
      });
    } catch (e) {
      print('Start recording error: $e');
    }
  }

  Future<void> _stopRecordingAndEnroll() async {
    _timer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path == null || _secondsRecorded < 5) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please record for at least 5 seconds.')),
        );
        return;
      }

      setState(() {
        _isUploading = true;
      });

      final success = await ApiService.instance.enrollVoice(File(path));
      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _isEnrolled = success;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Voice enrollment successful!')),
        );
        if (widget.onCompleted != null) {
          widget.onCompleted!();
        } else {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice enrollment failed. Please try again.')),
        );
      }
    } catch (e) {
      print('Stop recording error: $e');
      setState(() {
        _isRecording = false;
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A28);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF666680);
    final cardBg = isDark ? const Color(0xFF1A1A24) : Colors.white;
    final cardBorder = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Voice Enrollment', style: TextStyle(color: primaryText, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: primaryText),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Voice Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isEnrolled ? Colors.green.withOpacity(0.12) : const Color(0xFF6C63FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isEnrolled ? Colors.green.withOpacity(0.3) : const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isEnrolled ? Icons.check_circle_rounded : Icons.record_voice_over_rounded,
                      color: _isEnrolled ? Colors.green : const Color(0xFF6C63FF),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isEnrolled ? 'Voice Profile Enrolled' : 'Voice Profile Not Enrolled',
                        style: TextStyle(
                          color: _isEnrolled ? Colors.green : const Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Instructions Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Read Aloud Sample Text', style: TextStyle(color: secondaryText, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      _sampleText,
                      style: TextStyle(color: primaryText, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Timer / Status text
              if (_isRecording)
                Center(
                  child: Column(
                    children: [
                      Text(
                        '00:${_secondsRecorded.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _secondsRecorded < 5 ? 'Keep reading... (at least 5s)' : 'Ready to submit',
                        style: TextStyle(color: secondaryText, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Record & Submit Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.redAccent : const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isUploading
                      ? null
                      : (_isRecording ? _stopRecordingAndEnroll : _startRecording),
                  icon: _isUploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                  label: Text(
                    _isUploading
                        ? 'Enrolling Voice...'
                        : (_isRecording ? 'Stop & Enroll Voice' : 'Start Voice Enrollment'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
