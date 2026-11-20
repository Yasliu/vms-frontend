import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_auth_repository.dart'
    show validEmail, validPassword, validRegistrationCode;

/// A tiny stand-in for the Spring Boot API that enforces the documented
/// authentication contract, so tests can exercise the real HTTP stack.
class FakeBackend {
  static const token = 'issued.jwt.token-marker';

  /// When true, every token is rejected as expired.
  bool tokensExpired = false;

  /// When true, the server is "down".
  bool down = false;

  final List<http.Request> requests = [];
  final Set<String> registeredEmails = {validEmail};

  /// When true, sign-up answers "not available right now".
  bool signUpDisabled = false;

  Iterable<http.Request> get vehicleRequests =>
      requests.where((r) => r.url.path.startsWith('/api/v1/vehicles'));
  Iterable<http.Request> get registerRequests =>
      requests.where((r) => r.url.path == '/api/v1/auth/register');
  Iterable<http.Request> get loginRequests =>
      requests.where((r) => r.url.path == '/api/v1/auth/login');

  MockClient get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (down) throw http.ClientException('connection refused');

    if (request.method == 'POST' && request.url.path == '/api/v1/auth/login') {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final ok =
          (body['email'] as String).trim().toLowerCase() == validEmail &&
          body['password'] == validPassword;
      if (!ok) {
        return _problem(
          401,
          'Authentication failed',
          'Invalid email or password.',
        );
      }
      return _json({
        'accessToken': token,
        'tokenType': 'Bearer',
        'expiresIn': 1800,
        'email': validEmail,
      });
    }

    if (request.method == 'POST' &&
        request.url.path == '/api/v1/auth/register') {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      if (signUpDisabled) {
        return _problem(
          403,
          'Registration not allowed',
          'Sign-up is not available right now.',
        );
      }
      if (body['registrationCode'] != validRegistrationCode) {
        return _problem(
          403,
          'Registration not allowed',
          'That registration code is not valid.',
        );
      }
      final email = (body['email'] as String).trim().toLowerCase();
      if (registeredEmails.contains(email)) {
        return _problem(
          409,
          'Duplicate email',
          'An account with this email already exists.',
        );
      }
      registeredEmails.add(email);
      return http.Response(
        jsonEncode({
          'accessToken': token,
          'tokenType': 'Bearer',
          'expiresIn': 1800,
          'email': email,
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.url.path.startsWith('/api/v1/vehicles')) {
      final auth = request.headers['Authorization'];
      if (auth != 'Bearer $token') {
        return _problem(
          401,
          'Unauthorized',
          'Authentication is required to access this resource.',
        );
      }
      if (tokensExpired) {
        return _problem(
          401,
          'Unauthorized',
          'Your session has expired. Please sign in again.',
        );
      }
      if (request.method == 'GET') {
        return _json({
          'content': [
            {
              'id': 1,
              'vehicleNumber': 'AB 12345',
              'company': 'Acme',
              'type': 'Truck',
              'brand': 'Volvo',
              'model': 'FH16',
              'status': 'ACTIVE',
            },
          ],
          'page': 0,
          'size': 100,
          'totalElements': 1,
          'totalPages': 1,
        });
      }
      return http.Response('', 204);
    }
    return http.Response('', 404);
  }

  static http.Response _json(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );

  static http.Response _problem(int status, String title, String detail) =>
      http.Response(
        jsonEncode({
          'type': 'about:blank',
          'title': title,
          'status': status,
          'detail': detail,
        }),
        status,
        headers: {'content-type': 'application/problem+json'},
      );
}
