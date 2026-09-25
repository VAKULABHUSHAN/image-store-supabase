import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'main.dart';

class CaptionLine {
  final String text;
  final String speaker; // 'host', 'other', or person's name
  final double? start;
  final double? end;

  CaptionLine({
    required this.text,
    required this.speaker,
    this.start,
    this.end,
  });
}

class LiveCaptionService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _isReady = false;

  final StreamController<CaptionLine> _finalCaptionsController =
      StreamController<CaptionLine>.broadcast();
  final StreamController<String> _partialCaptionController =
      StreamController<String>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  Stream<CaptionLine> get finalCaptions => _finalCaptionsController.stream;
  Stream<String> get partialCaption => _partialCaptionController.stream;
  Stream<String> get errorStream => _errorController.stream;
  bool get isReady => _isReady;

  Future<bool> connect({required String sessionId}) async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null || token.isEmpty) {
        _errorController.add("No active auth token.");
        return false;
      }

      final wsUri = Uri.parse(backendWsUrl);
      _channel = WebSocketChannel.connect(wsUri);
      _isReady = false;

      final completer = Completer<bool>();

      _sub = _channel!.stream.listen(
        (data) {
          if (data is String) {
            try {
              final msg = jsonDecode(data) as Map<String, dynamic>;
              final type = msg['type'] as String?;

              if (type == 'ready') {
                _isReady = true;
                if (!completer.isCompleted) completer.complete(true);
              } else if (type == 'partial') {
                final text = msg['text'] as String? ?? '';
                _partialCaptionController.add(text);
              } else if (type == 'final') {
                final text = msg['text'] as String? ?? '';
                final speaker = msg['speaker'] as String? ?? 'other';
                final start = (msg['start'] as num?)?.toDouble();
                final end = (msg['end'] as num?)?.toDouble();

                _finalCaptionsController.add(CaptionLine(
                  text: text,
                  speaker: speaker,
                  start: start,
                  end: end,
                ));
              } else if (type == 'error') {
                final err = msg['message'] as String? ?? 'WebSocket Error';
                _errorController.add(err);
                if (!completer.isCompleted) completer.complete(false);
              }
            } catch (e) {
              print('Live caption parse error: $e');
            }
          }
        },
        onError: (error) {
          print('WebSocket channel error: $error');
          _errorController.add(error.toString());
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          _isReady = false;
        },
      );

      // Send initial start event
      final startMessage = jsonEncode({
        'type': 'start',
        'token': token,
        'session_id': sessionId,
      });
      _channel!.sink.add(startMessage);

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    } catch (e) {
      print('WebSocket connection error: $e');
      return false;
    }
  }

  void sendAudioChunk(Uint8List pcmChunk) {
    if (_channel != null && _isReady) {
      _channel!.sink.add(pcmChunk);
    }
  }

  Future<void> stop() async {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({'type': 'stop'}));
        await Future.delayed(const Duration(milliseconds: 300));
        await _channel!.sink.close();
      } catch (_) {}
    }
    _sub?.cancel();
    _isReady = false;
  }

  void dispose() {
    stop();
    _finalCaptionsController.close();
    _partialCaptionController.close();
    _errorController.close();
  }
}
