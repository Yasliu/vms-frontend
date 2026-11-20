import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../models/auth_session.dart';

/// Holds who is signed in. The access token is kept in memory only (never in
/// browser storage), and the password is never kept at all: it is handed to the
/// repository and forgotten.
class SessionController extends ChangeNotifier {
  SessionController(this._auth, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Treat a token as expired slightly early so requests do not race the clock.
  static const _expirySkew = Duration(seconds: 5);
  static const expiredNotice =
      'Your session has expired. Please sign in again.';

  final AuthRepository _auth;
  final DateTime Function() _now;

  AuthSession? _session;
  String? _notice;
  bool _disposed = false;

  bool get isSignedIn => _session != null;
  String? get email => _session?.email;

  /// A message for the sign-in screen, such as "your session has expired".
  String? get notice => _notice;

  /// The token to send with requests, or null when signed out or expired.
  /// Finding an expired token ends the session.
  String? get accessToken {
    final session = _session;
    if (session == null) return null;
    if (!_now().isBefore(session.expiresAt.subtract(_expirySkew))) {
      scheduleMicrotask(expire);
      return null;
    }
    return session.accessToken;
  }

  /// Throws `ApiException` when the credentials are wrong or the server cannot
  /// be reached.
  Future<void> login(String email, String password) async =>
      _start(await _auth.login(email, password));

  /// Creates an account and signs in with it. Throws `ApiException` when the
  /// server refuses (wrong registration code, email already used, ...).
  Future<void> register(
    String email,
    String password,
    String registrationCode,
  ) async => _start(await _auth.register(email, password, registrationCode));

  void _start(AuthSession session) {
    _session = session;
    _notice = null;
    notifyListeners();
  }

  void logout() => _end(notice: null);

  /// The server (or the clock) says the session is over.
  void expire() {
    if (_session == null) return;
    _end(notice: expiredNotice);
  }

  void _end({required String? notice}) {
    final wasSignedIn = _session != null;
    _session = null;
    _notice = notice;
    if (wasSignedIn || notice != null) notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
