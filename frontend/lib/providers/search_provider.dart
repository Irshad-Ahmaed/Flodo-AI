import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_status.dart';

final rawSearchQueryProvider = StateProvider<String>((ref) => '');
final debouncedSearchQueryProvider = StateProvider<String>((ref) => '');
final statusFilterProvider = StateProvider<TaskStatus?>((ref) => null);
