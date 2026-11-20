import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vms_frontend/core/network/api_client.dart';
import 'package:vms_frontend/core/network/api_exception.dart';

const secretToken = 'header.payload-secret-marker.signature';

http.Response problem(int status, Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/problem+json'},
);

void main() {
  late List<http.Request> requests;
  late int unauthorizedCalls;

  ApiClient client(
    Future<http.Response> Function(http.Request) handler, {
    String? token = secretToken,
  }) {
    requests = [];
    unauthorizedCalls = 0;
    return ApiClient(
      baseUrl: 'http://api.test',
      httpClient: MockClient((r) {
        requests.add(r);
        return handler(r);
      }),
      tokenProvider: () => token,
      onUnauthorized: () => unauthorizedCalls++,
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

  test('protected requests carry the bearer token', () async {
    final api = client((_) async => http.Response('{}', 200));

    await api.get('/api/v1/vehicles');
    await api.post('/api/v1/vehicles', {'a': 1});
    await api.put('/api/v1/vehicles/1', {'a': 1});
    await api.delete('/api/v1/vehicles/1');

    expect(requests, hasLength(4));
    for (final r in requests) {
      expect(r.headers['Authorization'], 'Bearer $secretToken');
    }
  });

  test(
    'without a token a protected request never reaches the network',
    () async {
      final api = client((_) async => http.Response('{}', 200), token: null);

      final e = await failureOf(api.get('/api/v1/vehicles'));

      expect(e.kind, ApiErrorKind.unauthorized);
      expect(requests, isEmpty);
      expect(
        unauthorizedCalls,
        0,
        reason: 'nothing was rejected by the server',
      );
    },
  );

  test('every protected operation is refused when signed out', () async {
    final api = client((_) async => http.Response('{}', 200), token: null);

    for (final call in <Future<Object?> Function()>[
      () => api.get('/api/v1/vehicles'),
      () => api.post('/api/v1/vehicles', {}),
      () => api.put('/api/v1/vehicles/1', {}),
      () => api.delete('/api/v1/vehicles/1'),
    ]) {
      expect((await failureOf(call())).kind, ApiErrorKind.unauthorized);
    }
    expect(requests, isEmpty);
  });

  test('the sign-in call is sent without a token', () async {
    final api = client((_) async => http.Response('{}', 200));

    await api.post('/api/v1/auth/login', {
      'email': 'a',
      'password': 'b',
    }, authenticated: false);

    expect(requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('a 401 on a protected call ends the session exactly once', () async {
    final api = client(
      (_) async => problem(401, {
        'detail': 'Your session has expired. Please sign in again.',
      }),
    );

    final e = await failureOf(api.get('/api/v1/vehicles'));

    expect(e.kind, ApiErrorKind.unauthorized);
    expect(e.message, 'Your session has expired. Please sign in again.');
    expect(unauthorizedCalls, 1);
  });

  test('a 401 from the sign-in call (wrong password) does not look like an expired session', () async {
    final api = client(
      (_) async => problem(401, {'detail': 'Invalid email or password.'}),
    );

    final e = await failureOf(
      api.post('/api/v1/auth/login', {
        'email': 'a',
        'password': 'b',
      }, authenticated: false),
    );

    expect(e.kind, ApiErrorKind.unauthorized);
    expect(unauthorizedCalls, 0);
  });

  test('403 is reported as forbidden and does not end the session', () async {
    final api = client(
      (_) async =>
          problem(403, {'detail': 'You do not have permission to do this.'}),
    );

    final e = await failureOf(api.delete('/api/v1/vehicles/1'));

    expect(e.kind, ApiErrorKind.forbidden);
    expect(unauthorizedCalls, 0);
  });

  test('the token never appears in an error message', () async {
    final api = client((_) async => problem(401, {'detail': 'Bad token'}));

    final e = await failureOf(api.get('/api/v1/vehicles'));

    expect(e.message, isNot(contains(secretToken)));
    expect(e.toString(), isNot(contains(secretToken)));
  });
}
