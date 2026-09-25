import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/api_client.dart';
import '../models/interaction_model.dart';

class InteractionsNotifier
    extends AsyncNotifier<Map<String, InteractionModel>> {
  @override
  Future<Map<String, InteractionModel>> build() async => {};

  Future<InteractionModel?> fetchForPerson(String personId) async {
    try {
      final data = await ApiClient.get('/api/interactions/$personId');
      if (data == null) return null;
      final model =
          InteractionModel.fromJson(data as Map<String, dynamic>);
      final current = Map<String, InteractionModel>.from(
          state.valueOrNull ?? {});
      current[personId] = model;
      state = AsyncValue.data(current);
      return model;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null; // empty state, not error
      rethrow;
    }
  }

  Future<InteractionModel?> postInteraction({
    required String personId,
    required List<int> audioBytes,
    String? language,
  }) async {
    final file = http.MultipartFile.fromBytes(
      'audio_file',
      audioBytes,
      filename: 'recording.m4a',
      contentType: MediaType('audio', 'm4a'),
    );
    final fields = {
      'person_id': personId,
      'occurred_at': DateTime.now().toIso8601String(),
      if (language != null) 'language': language,
    };
    final data = await ApiClient.uploadMultipart(
      '/api/interactions',
      [file],
      fields: fields,
    ) as Map<String, dynamic>;
    final model = InteractionModel.fromJson(data);
    final current = Map<String, InteractionModel>.from(
        state.valueOrNull ?? {});
    current[personId] = model;
    state = AsyncValue.data(current);
    return model;
  }
}

final interactionsProvider =
    AsyncNotifierProvider<InteractionsNotifier, Map<String, InteractionModel>>(
  InteractionsNotifier.new,
);
