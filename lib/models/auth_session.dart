/// A signed-in user's session. It lives only in memory: it is never written to
/// browser storage, so a page reload signs the user out by design.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.email,
    required this.expiresAt,
  });

  final String accessToken;
  final String email;
  final DateTime expiresAt;

  /// Never print the token.
  @override
  String toString() => 'AuthSession(email: $email, expiresAt: $expiresAt)';
}
