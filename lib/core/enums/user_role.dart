enum UserRole {
  tenant('tenant'),
  technician('technician'),
  admin('admin');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.tenant,
    );
  }
}
