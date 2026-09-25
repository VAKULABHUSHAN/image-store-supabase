import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/api_client.dart';
import '../models/face_recognition_result.dart';

class RecognitionState {
  final FaceRecognitionResult? result;
  final bool isProcessing;
  final String? error;

  const RecognitionState({
    this.result,
    this.isProcessing = false,
    this.error,
  });

  RecognitionState copyWith({
    FaceRecognitionResult? result,
    bool? isProcessing,
    String? error,
  }) =>
      RecognitionState(
        result: result ?? this.result,
        isProcessing: isProcessing ?? this.isProcessing,
        error: error ?? this.error,
      );
}

class RecognitionNotifier extends StateNotifier<RecognitionState> {
  RecognitionNotifier() : super(const RecognitionState());

  Future<void> recognize(List<int> imageBytes) async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final file = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'frame.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      final data = await ApiClient.uploadMultipart(
        '/api/face/recognize',
        [file],
      ) as Map<String, dynamic>;
      final result = FaceRecognitionResult.fromJson(data);
      state = state.copyWith(result: result, isProcessing: false);
    } catch (e) {
      state = state.copyWith(
          isProcessing: false, error: e.toString());
    }
  }

  void reset() => state = const RecognitionState();
}

final recognitionProvider =
    StateNotifierProvider<RecognitionNotifier, RecognitionState>(
  (ref) => RecognitionNotifier(),
);
