import 'dart:async';

import 'package:vms_frontend/core/network/api_exception.dart';
import 'package:vms_frontend/data/auth_repository.dart';
import 'package:vms_frontend/models/auth_session.dart';

const validEmail = 'admin@example.com';
const validPassword = 'correct-horse-battery-staple';
const validRegistrationCode = 'team-signup-code-2026';

/// Accepts exactly one email/password pair, like the real server would.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.failWith, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// When set, every attempt fails with this error (for example a network error).
  ApiException? failWith;

  /// While set, [login] waits for it to complete.
  Completer<void>? gate;

  final List<({String email, String password})> attempts = [];
  final List<({String email, String password, String code})> registrations = [];

  /// Emails that already have an account.
  final Set<String> takenEmails = {validEmail};

  @override
  Future<AuthSession> login(String email, String password) async {
    attempts.add((email: email, password: password));
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
    if (email.trim().toLowerCase() == validEmail && password == validPassword) {
      return AuthSession(
        accessToken: 'fake.jwt.token',
        email: validEmail,
        expiresAt: _now().add(const Duration(minutes: 30)),
      );
    }
    throw const ApiException(
      kind: ApiErrorKind.unauthorized,
      statusCode: 401,
      message: 'Incorrect email or password. Please check them and try again.',
    );
  }

  @override
  Future<AuthSession> register(
    String email,
    String password,
    String registrationCode,
  ) async {
    registrations.add((
      email: email,
      password: password,
      code: registrationCode,
    ));
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
    if (registrationCode != validRegistrationCode) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        statusCode: 403,
        message: 'That registration code is not valid.',
        fieldErrors: {
          'registrationCode': 'That registration code is not valid.',
        },
      );
    }
    final normalized = email.trim().toLowerCase();
    if (takenEmails.contains(normalized)) {
      const message =
          'An account with this email already exists. Try signing in instead.';
      throw const ApiException(
        kind: ApiErrorKind.conflict,
        statusCode: 409,
        message: message,
        fieldErrors: {'email': message},
      );
    }
    takenEmails.add(normalized);
    return AuthSession(
      accessToken: 'fake.jwt.token',
      email: normalized,
      expiresAt: _now().add(const Duration(minutes: 30)),
    );
  }
}
