import '../models/auth_session.dart';

/// Signs a user in or creates an account. Implementations throw `ApiException`
/// on failure.
abstract class AuthRepository {
  Future<AuthSession> login(String email, String password);

  /// Creates an account and signs it in. [registrationCode] is the shared code
  /// the server requires for self-service sign-up.
  Future<AuthSession> register(
    String email,
    String password,
    String registrationCode,
  );
}
