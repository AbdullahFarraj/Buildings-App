enum TaskStatus {
  pending('pending'),
  assigned('assigned'),
  inProgress('inProgress'),
  waitingConfirmation('waitingConfirmation'),
  completed('completed'),
  rejected('rejected');

  final String value;
  const TaskStatus(this.value);

  static TaskStatus fromString(String value) {
    return TaskStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TaskStatus.pending,
    );
  }
}
