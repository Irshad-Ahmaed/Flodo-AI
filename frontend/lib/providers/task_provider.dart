import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import 'search_provider.dart';

class TaskRepository {
  TaskRepository(this._ref);

  final Ref _ref;

  Future<List<Task>> fetchTasks({
    String? search,
    TaskStatus? status,
  }) {
    return _ref.read(apiClientProvider).fetchTasks(
          search: search,
          status: status,
        );
  }

  Future<List<Task>> fetchAllTasks() {
    return _ref.read(apiClientProvider).fetchAllTasks();
  }

  Future<Task> fetchTask(int id) {
    return _ref.read(apiClientProvider).fetchTask(id);
  }

  Future<Task> createTask(Task task) {
    return _ref.read(apiClientProvider).createTask(task);
  }

  Future<Task> updateTask(Task task) {
    return _ref.read(apiClientProvider).updateTask(task);
  }

  Future<void> deleteTask(int id) {
    return _ref.read(apiClientProvider).deleteTask(id);
  }
}

final taskRepositoryProvider = Provider<TaskRepository>(TaskRepository.new);

final tasksProvider = FutureProvider<List<Task>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  final search = ref.watch(debouncedSearchQueryProvider);
  final status = ref.watch(statusFilterProvider);
  return repository.fetchTasks(
    search: search.trim().isEmpty ? null : search.trim(),
    status: status,
  );
});

final taskOptionsProvider = FutureProvider<List<Task>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.fetchAllTasks();
});

final taskByIdProvider = FutureProvider.family<Task, int>((ref, taskId) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.fetchTask(taskId);
});
