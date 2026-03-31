import 'package:intl/intl.dart';

import 'task_status.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.isBlocked,
    this.blockedById,
    this.blockedByTitle,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final int? blockedById;
  final bool isBlocked;
  final String? blockedByTitle;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueDate: DateTime.parse(json['due_date'] as String),
      status: TaskStatus.fromApi(json['status'] as String? ?? 'To-Do'),
      blockedById: json['blocked_by_id'] as int?,
      isBlocked: json['is_blocked'] as bool? ?? false,
      blockedByTitle: json['blocked_by_title'] as String?,
      createdAt: _parseOptionalDateTime(json['created_at']),
      updatedAt: _parseOptionalDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'title': title.trim(),
      'description': description,
      'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      'status': status.label,
      'blocked_by_id': blockedById,
    };
  }
}

DateTime? _parseOptionalDateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
