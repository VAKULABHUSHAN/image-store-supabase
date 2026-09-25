import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/memory_cue.dart';

final overlayProvider =
    FutureProvider.family<MemoryCue?, String>((ref, personId) async {
  try {
    final data = await ApiClient.get('/api/overlay/$personId');
    if (data == null) return null;
    return MemoryCue.fromJson(data as Map<String, dynamic>);
  } on ApiException catch (e) {
    if (e.statusCode == 404) return null;
    rethrow;
  }
});
