import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/auth_session.dart';
import 'auth_error_mapper.dart';
import 'auth_repository.dart';

/// `POST /api/v1/auth/login` with `{email, password}`, and
/// `POST /api/v1/auth/register` with `{email, password, registrationCode}`.
/// Both answer `{accessToken, tokenType: "Bearer", expiresIn (seconds), email}`.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _now;

  static const _path = '/api/v1/auth/login';
  static const _registerPath = '/api/v1/auth/register';

  @override
  Future<AuthSession> login(String email, String password) async {
    final Object? json;
    try {
      json = await _api.post(_path, {
        'email': email.trim(),
        'password': password,
      }, authenticated: false);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized) {
        throw ApiException(
          kind: e.kind,
          statusCode: e.statusCode,
          message:
              'Incorrect email or password. Please check them and try again.',
        );
      }
      rethrow;
    }

    return _sessionFrom(json);
  }

  @override
  Future<AuthSession> register(
    String email,
    String password,
    String registrationCode,
  ) async {
    final Object? json;
    try {
      json = await _api.post(_registerPath, {
        'email': email.trim(),
        'password': password,
        'registrationCode': registrationCode.trim(),
      }, authenticated: false);
    } on ApiException catch (e) {
      throw AuthErrorMapper.forRegister(e);
    }
    return _sessionFrom(json);
  }

  AuthSession _sessionFrom(Object? json) {
    if (json is! Map<String, Object?>) throw _unreadable();
    final token = json['accessToken'];
    final type = json['tokenType'];
    final expiresIn = json['expiresIn'];
    final returnedEmail = json['email'];
    if (token is! String ||
        token.isEmpty ||
        type is! String ||
        type.toLowerCase() != 'bearer' ||
        expiresIn is! int ||
        returnedEmail is! String) {
      throw _unreadable();
    }
    return AuthSession(
      accessToken: token,
      email: returnedEmail,
      expiresAt: _now().add(Duration(seconds: expiresIn)),
    );
  }

  ApiException _unreadable() => const ApiException(
    kind: ApiErrorKind.unexpected,
    message: 'The server sent a sign-in response the app could not understand.',
  );
}
