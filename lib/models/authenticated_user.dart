class AuthenticatedUser {
  const AuthenticatedUser({
    required this.uid,
    this.email = '',
    this.isEmailVerified = false,
    this.phoneNumber = '',
  });

  final String uid;
  final String email;
  final bool isEmailVerified;

  /// Retained only to migrate existing phone-auth beta users without changing
  /// their Firebase UID or losing account-scoped data.
  final String phoneNumber;

  bool get hasEmail => email.trim().isNotEmpty;
}
