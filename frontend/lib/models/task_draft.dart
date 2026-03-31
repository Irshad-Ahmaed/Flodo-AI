import 'task_status.dart';

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.status,
    this.dueDate,
    this.blockedById,
  });

  final String title;
  final String description;
  final DateTime? dueDate;
  final TaskStatus status;
  final int? blockedById;

  factory TaskDraft.fromJson(Map<String, dynamic> json) {
    return TaskDraft(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueDate: json['due_date'] is String && (json['due_date'] as String).isNotEmpty
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      status: TaskStatus.fromApi(json['status'] as String? ?? TaskStatus.todo.label),
      blockedById: json['blocked_by_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'status': status.label,
      'blocked_by_id': blockedById,
    };
  }
}
