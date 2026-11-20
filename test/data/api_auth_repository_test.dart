import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vms_frontend/core/network/api_client.dart';
import 'package:vms_frontend/core/network/api_exception.dart';
import 'package:vms_frontend/data/api_auth_repository.dart';

const password = 'Sup3r-secret-password-marker';
final fixedNow = DateTime.utc(2026, 6, 1, 10);

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late List<http.Request> requests;

  ApiAuthRepository repo(Future<http.Response> Function(http.Request) handler) {
    requests = [];
    return ApiAuthRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
        // A token provider that would blow up proves login never asks for one.
        tokenProvider: () => throw StateError('login must not read the token'),
      ),
      now: () => fixedNow,
    );
  }

  Future<ApiException> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on ApiException catch (e) {
      return e;
    }
    fail('Expected an ApiException');
  }

  test(
    'POSTs the credentials to the documented endpoint, without a token',
    () async {
      final r = repo(
        (_) async => json({
          'accessToken': 'jwt',
          'tokenType': 'Bearer',
          'expiresIn': 1800,
          'email': 'admin@example.com',
        }),
      );

      await r.login('  admin@example.com ', password);

      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.toString(),
        'http://api.test/api/v1/auth/login',
      );
      expect(jsonDecode(requests.single.body), {
        'email': 'admin@example.com',
        'password': password,
      });
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      expect(
        requests.single.url.query,
        isEmpty,
        reason: 'credentials must never be in the URL',
      );
    },
  );

  test('builds a session from the response', () async {
    final r = repo(
      (_) async => json({
        'accessToken': 'the.jwt',
        'tokenType': 'Bearer',
        'expiresIn': 1800,
        'email': 'admin@example.com',
      }),
    );

    final session = await r.login('admin@example.com', password);

    expect(session.accessToken, 'the.jwt');
    expect(session.email, 'admin@example.com');
    expect(session.expiresAt, fixedNow.add(const Duration(seconds: 1800)));
  });

  test('wrong credentials become a clear, friendly message', () async {
    final r = repo(
      (_) async => http.Response(
        jsonEncode({
          'title': 'Authentication failed',
          'detail': 'Invalid email or password.',
          'status': 401,
        }),
        401,
        headers: {'content-type': 'application/problem+json'},
      ),
    );

    final e = await failureOf(r.login('admin@example.com', 'wrong'));

    expect(e.kind, ApiErrorKind.unauthorized);
    expect(e.message, contains('Incorrect email or password'));
  });

  test('an unreachable server is reported as such', () async {
    final r = repo(
      (_) async => throw http.ClientException('connection refused'),
    );

    final e = await failureOf(r.login('admin@example.com', password));

    expect(e.kind, ApiErrorKind.network);
  });

  test('a malformed success response is rejected', () async {
    for (final body in <Object>[
      {'accessToken': '', 'tokenType': 'Bearer', 'expiresIn': 10, 'email': 'a'},
      {'accessToken': 'x', 'tokenType': 'Basic', 'expiresIn': 10, 'email': 'a'},
      {'accessToken': 'x', 'tokenType': 'Bearer', 'email': 'a'},
      ['not', 'an', 'object'],
    ]) {
      final r = repo((_) async => json(body));
      expect(
        (await failureOf(r.login('a@b.com', password))).kind,
        ApiErrorKind.unexpected,
      );
    }
  });

  test(
    'the password never appears in errors, exceptions or the session',
    () async {
      final failing = repo(
        (_) async => json({'detail': 'Invalid email or password.'}, 401),
      );
      final e = await failureOf(failing.login('admin@example.com', password));
      expect(e.message, isNot(contains(password)));
      expect(e.toString(), isNot(contains(password)));

      final ok = repo(
        (_) async => json({
          'accessToken': 'jwt',
          'tokenType': 'Bearer',
          'expiresIn': 60,
          'email': 'admin@example.com',
        }),
      );
      final session = await ok.login('admin@example.com', password);
      expect(session.toString(), isNot(contains(password)));
      expect(
        session.toString(),
        isNot(contains('jwt')),
        reason: 'the token is not printable',
      );
    },
  );

  group('register', () {
    const code = 'Team-code-secret-marker-1';

    http.Response created() => json({
      'accessToken': 'new.jwt',
      'tokenType': 'Bearer',
      'expiresIn': 1800,
      'email': 'new@example.com',
    }, 201);

    test('POSTs email, password and code to the documented endpoint, without a token', () async {
      final r = repo((_) async => created());

      final session = await r.register(
        '  new@example.com ',
        password,
        ' $code ',
      );

      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.toString(),
        'http://api.test/api/v1/auth/register',
      );
      expect(jsonDecode(requests.single.body), {
        'email': 'new@example.com',
        'password': password,
        'registrationCode': code,
      });
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      expect(
        requests.single.url.query,
        isEmpty,
        reason: 'secrets must never be in the URL',
      );
      expect(session.accessToken, 'new.jwt');
      expect(session.email, 'new@example.com');
      expect(session.expiresAt, fixedNow.add(const Duration(seconds: 1800)));
    });

    test('a wrong code becomes an error on the code field', () async {
      final r = repo(
        (_) async => json({
          'title': 'Registration not allowed',
          'detail': 'That registration code is not valid.',
        }, 403),
      );

      final e = await failureOf(r.register('new@example.com', password, code));

      expect(e.kind, ApiErrorKind.forbidden);
      expect(e.fieldErrors.keys, ['registrationCode']);
    });

    test('a taken email becomes an error on the email field', () async {
      final r = repo(
        (_) async => json({
          'title': 'Duplicate email',
          'detail': 'An account with this email already exists.',
        }, 409),
      );

      final e = await failureOf(r.register('new@example.com', password, code));

      expect(e.kind, ApiErrorKind.conflict);
      expect(e.fieldErrors.keys, ['email']);
      expect(e.message, contains('Try signing in instead'));
    });

    test('server validation is rewritten', () async {
      final r = repo(
        (_) async => json({
          'detail': 'One or more fields are invalid.',
          'errors': [
            {'field': 'password', 'message': 'size must be between 12 and 72'},
          ],
        }, 400),
      );

      final e = await failureOf(r.register('new@example.com', 'short', code));

      expect(
        e.fieldErrors['password'],
        'Use 12 to 72 characters for the password.',
      );
    });

    test(
      'the password and the code never appear in errors or the session',
      () async {
        final failing = repo(
          (_) async =>
              json({'detail': 'That registration code is not valid.'}, 403),
        );
        final e = await failureOf(
          failing.register('new@example.com', password, code),
        );
        expect('${e.message} ${e.fieldErrors} $e', isNot(contains(password)));
        expect('${e.message} ${e.fieldErrors} $e', isNot(contains(code)));

        final ok = repo((_) async => created());
        final session = await ok.register('new@example.com', password, code);
        expect(session.toString(), isNot(contains(password)));
        expect(session.toString(), isNot(contains('new.jwt')));
      },
    );

    test('an unreachable server is reported as such', () async {
      final r = repo((_) async => throw http.ClientException('refused'));

      expect(
        (await failureOf(r.register('new@example.com', password, code))).kind,
        ApiErrorKind.network,
      );
    });

    test('a malformed success response is rejected', () async {
      final r = repo((_) async => json({'accessToken': ''}, 201));

      expect(
        (await failureOf(r.register('new@example.com', password, code))).kind,
        ApiErrorKind.unexpected,
      );
    });
  });
}
