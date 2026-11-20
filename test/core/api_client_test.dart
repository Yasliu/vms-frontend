import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vms_frontend/core/network/api_client.dart';
import 'package:vms_frontend/core/network/api_exception.dart';

ApiClient clientFor(
  Future<http.Response> Function(http.Request) handler, {
  String baseUrl = 'http://api.test:8080',
  Duration timeout = const Duration(seconds: 5),
}) => ApiClient(
  baseUrl: baseUrl,
  timeout: timeout,
  httpClient: MockClient(handler),
  tokenProvider: () => 'test-token',
);

http.Response problem(int status, Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/problem+json'},
);

Future<ApiException> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on ApiException catch (e) {
    return e;
  }
  fail('Expected an ApiException');
}

void main() {
  group('requests', () {
    test('builds the URL from base URL, path and query', () async {
      late http.Request seen;
      final client = clientFor((r) async {
        seen = r;
        return http.Response('{}', 200);
      }, baseUrl: 'http://api.test:8080/');

      await client.get('/api/v1/vehicles', query: {'page': '2', 'size': '100'});

      expect(seen.method, 'GET');
      expect(
        seen.url.toString(),
        'http://api.test:8080/api/v1/vehicles?page=2&size=100',
      );
      expect(seen.headers['Accept'], 'application/json');
    });

    test('keeps a path prefix on the base URL', () async {
      late http.Request seen;
      final client = clientFor((r) async {
        seen = r;
        return http.Response('{}', 200);
      }, baseUrl: 'https://example.com/vms-api');

      await client.get('/api/v1/vehicles');

      expect(
        seen.url.toString(),
        'https://example.com/vms-api/api/v1/vehicles',
      );
    });

    test('sends JSON bodies with a JSON content type', () async {
      late http.Request seen;
      final client = clientFor((r) async {
        seen = r;
        return http.Response('{}', 201);
      });

      await client.post('/x', {'a': 1});
      expect(seen.method, 'POST');
      expect(seen.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(seen.body), {'a': 1});

      await client.put('/x/1', {'b': 2});
      expect(seen.method, 'PUT');
    });
  });

  group('responses', () {
    test('decodes JSON as UTF-8 even without a charset header', () async {
      final client = clientFor(
        (r) async => http.Response.bytes(
          utf8.encode('{"company":"Göteborg ধাকা"}'),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(await client.get('/x'), {'company': 'Göteborg ধাকা'});
    });

    test('204 No Content returns null', () async {
      final client = clientFor((r) async => http.Response('', 204));

      expect(await client.delete('/x/1'), isNull);
    });

    test('malformed success body becomes an unexpected error', () async {
      final client = clientFor((r) async => http.Response('<html>', 200));

      final e = await failureOf(client.get('/x'));

      expect(e.kind, ApiErrorKind.unexpected);
    });
  });

  group('errors', () {
    test('409 problem+json keeps the server detail and extras', () async {
      final client = clientFor(
        (r) async => problem(409, {
          'title': 'Duplicate vehicle number',
          'detail': 'A vehicle with vehicle number AB 1 already exists',
          'vehicleNumber': 'AB 1',
        }),
      );

      final e = await failureOf(client.post('/x', {}));

      expect(e.kind, ApiErrorKind.conflict);
      expect(e.statusCode, 409);
      expect(e.message, 'A vehicle with vehicle number AB 1 already exists');
      expect(e.details['vehicleNumber'], 'AB 1');
    });

    test('400 collects per-field errors', () async {
      final client = clientFor(
        (r) async => problem(400, {
          'title': 'Validation failed',
          'detail': 'One or more fields are invalid.',
          'errors': [
            {'field': 'vehicleNumber', 'message': 'must not be blank'},
            {'field': 'model', 'message': 'size must be between 0 and 50'},
          ],
        }),
      );

      final e = await failureOf(client.post('/x', {}));

      expect(e.kind, ApiErrorKind.validation);
      expect(e.fieldErrors, {
        'vehicleNumber': 'must not be blank',
        'model': 'size must be between 0 and 50',
      });
    });

    test('404 maps to notFound', () async {
      final client = clientFor(
        (r) async =>
            problem(404, {'detail': 'Vehicle with id 9 was not found'}),
      );

      final e = await failureOf(client.get('/x'));

      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, 'Vehicle with id 9 was not found');
    });

    test('500 is a retryable server error', () async {
      final client = clientFor(
        (r) async => problem(500, {'detail': 'An unexpected error occurred.'}),
      );

      final e = await failureOf(client.get('/x'));

      expect(e.kind, ApiErrorKind.server);
      expect(e.isRetryable, isTrue);
    });

    test('a non-JSON error page never leaks into the message', () async {
      final client = clientFor(
        (r) async => http.Response('<html>nginx 502 Bad Gateway</html>', 502),
      );

      final e = await failureOf(client.get('/x'));

      expect(e.kind, ApiErrorKind.server);
      expect(e.message, isNot(contains('nginx')));
      expect(e.message, isNot(contains('<html>')));
    });

    test('connection failures become a friendly network error', () async {
      final client = clientFor(
        (r) async => throw http.ClientException(
          'XMLHttpRequest error. http://api.test:8080/x',
        ),
      );

      final e = await failureOf(client.get('/x'));

      expect(e.kind, ApiErrorKind.network);
      expect(e.message, isNot(contains('api.test')));
      expect(e.isRetryable, isTrue);
    });

    test('slow servers time out', () async {
      final client = clientFor(
        (r) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 50),
      );

      final e = await failureOf(client.get('/x'));

      expect(e.kind, ApiErrorKind.timeout);
    });
  });
}
