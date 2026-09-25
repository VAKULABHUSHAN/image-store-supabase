import 'person_model.dart';
import 'memory_cue.dart';

enum RecognitionState {
  noFaceDetected,
  unknownFace,
  unnamedFace,
  knownFace,
}

class FaceRecognitionResult {
  final bool matched;
  final bool isKnown;
  final double? matchDistance;
  final PersonModel? person;
  final MemoryCue? memoryCue;

  const FaceRecognitionResult({
    required this.matched,
    required this.isKnown,
    this.matchDistance,
    this.person,
    this.memoryCue,
  });

  factory FaceRecognitionResult.fromJson(Map<String, dynamic> json) =>
      FaceRecognitionResult(
        matched:       (json['matched'] as bool?) ?? false,
        isKnown:       (json['is_known'] as bool?) ?? false,
        matchDistance: (json['match_distance'] as num?)?.toDouble(),
        person:        json['person'] != null
            ? PersonModel.fromJson(json['person'] as Map<String, dynamic>)
            : null,
        memoryCue:     json['memory_cue'] != null
            ? MemoryCue.fromJson(json['memory_cue'] as Map<String, dynamic>)
            : null,
      );

  RecognitionState get state {
    if (!matched) {
      if (matchDistance == null) return RecognitionState.noFaceDetected;
      return RecognitionState.unknownFace;
    }
    return isKnown ? RecognitionState.knownFace : RecognitionState.unnamedFace;
  }

  /// State machine helpers per FRONTEND_CONTEXT spec.
  bool get noFaceDetected => state == RecognitionState.noFaceDetected;
  bool get unknownFace    => state == RecognitionState.unknownFace;
  bool get needsIdentity  => state == RecognitionState.unnamedFace;
  bool get identified     => state == RecognitionState.knownFace;
}
