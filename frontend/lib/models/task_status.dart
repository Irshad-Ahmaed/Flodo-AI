enum TaskStatus {
  todo('To-Do'),
  inProgress('In Progress'),
  done('Done');

  const TaskStatus(this.label);

  final String label;

  static TaskStatus fromApi(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.label == value,
      orElse: () => TaskStatus.todo,
    );
  }
}
