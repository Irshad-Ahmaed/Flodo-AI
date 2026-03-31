import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_draft.dart';

const _createDraftKey = 'create_task_draft';

class DraftStore {
  DraftStore(this._preferences);

  final SharedPreferences _preferences;

  Future<TaskDraft?> loadCreateDraft() async {
    final raw = _preferences.getString(_createDraftKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return TaskDraft.fromJson(decoded);
  }

  Future<void> saveCreateDraft(TaskDraft draft) async {
    await _preferences.setString(_createDraftKey, jsonEncode(draft.toJson()));
  }

  Future<void> clearCreateDraft() async {
    await _preferences.remove(_createDraftKey);
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final draftStoreProvider = FutureProvider<DraftStore>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return DraftStore(preferences);
});
