enum TaskStatus {
  pending('pending'),
  approved('approved'),
  inProgress('inProgress'),
  completed('completed'),
  rejected('rejected');

  final String value;
  const TaskStatus(this.value);

  static TaskStatus fromString(String value) {
    return TaskStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid TaskStatus: $value'),
    );
  }
}
