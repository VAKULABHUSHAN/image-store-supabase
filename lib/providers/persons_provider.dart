import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/person_model.dart';

class PersonsNotifier extends AsyncNotifier<List<PersonModel>> {
  @override
  Future<List<PersonModel>> build() => _fetchAll();

  Future<List<PersonModel>> _fetchAll() async {
    final data = await ApiClient.get('/api/persons') as List<dynamic>;
    return data
        .map((e) => PersonModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchAll);
  }

  Future<PersonModel> confirmPerson(
      String personId, String name, String? relationship) async {
    final data = await ApiClient.patchJson(
      '/api/persons/$personId/confirm',
      {'name': name, 'relationship': relationship},
    ) as Map<String, dynamic>;
    final updated = PersonModel.fromJson(data);
    state = AsyncValue.data(
      state.valueOrNull
              ?.map((p) => p.id == personId ? updated : p)
              .toList() ??
          [updated],
    );
    return updated;
  }

  Future<void> deletePerson(String personId) async {
    await ApiClient.delete('/api/persons/$personId');
    state = AsyncValue.data(
      state.valueOrNull?.where((p) => p.id != personId).toList() ?? [],
    );
  }
}

final personsProvider =
    AsyncNotifierProvider<PersonsNotifier, List<PersonModel>>(
  PersonsNotifier.new,
);
