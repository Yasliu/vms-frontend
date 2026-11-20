import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// The single place that knows about HTTP: URLs, headers, JSON encoding,
/// timeouts and turning failures into [ApiException]. Everything above this
/// layer deals in Dart objects only.
///
/// Requests are authenticated by default: [tokenProvider] supplies the bearer
/// token, and a request with no token is refused without touching the network.
/// Pass `authenticated: false` only for the sign-in call.
class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
    this.tokenProvider,
    this.onUnauthorized,
  }) : _baseUrl = baseUrl.trim(),
       _client = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  /// Returns the current access token, or null when signed out.
  final String? Function()? tokenProvider;

  /// Called when the server rejects a token we sent (it expired or was
  /// revoked), so the app can end the session.
  final void Function()? onUnauthorized;

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Object?> post(String path, Object body, {bool authenticated = true}) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<Object?> put(String path, Object body) =>
      _send('PUT', path, body: body);

  Future<Object?> delete(String path) => _send('DELETE', path);

  void close() => _client.close();

  Uri _uri(String path, Map<String, String>? query) {
    // An empty base URL means "same origin as the page".
    final base = _baseUrl.isEmpty ? Uri.base : Uri.parse(_baseUrl);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '$basePath$path',
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers['Accept'] = 'application/json';
    if (authenticated) {
      final token = tokenProvider?.call();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: 'Please sign in to continue.',
        );
      }
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      // One timeout for the whole exchange: connecting, headers and body.
      response = await (() async {
        return http.Response.fromStream(await _client.send(request));
      })().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        kind: ApiErrorKind.timeout,
        message: 'The server took too long to respond. Please try again.',
      );
    } on Exception {
      throw const ApiException(
        kind: ApiErrorKind.network,
        message:
            'Cannot reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decodeSuccess(response);
    }
    final error = _errorFrom(response);
    if (authenticated && error.kind == ApiErrorKind.unauthorized) {
      onUnauthorized?.call();
    }
    throw error;
  }

  // The backend sends "application/json" without a charset, which package:http
  // would decode as Latin-1. Always decode the bytes as UTF-8 ourselves.
  Object? _decodeSuccess(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        kind: ApiErrorKind.unexpected,
        message: 'The server sent a response the app could not read.',
        statusCode: response.statusCode,
      );
    }
  }

  ApiException _errorFrom(http.Response response) {
    final status = response.statusCode;
    final kind = switch (status) {
      400 || 422 => ApiErrorKind.validation,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unexpected,
    };

    Map<String, Object?> problem = const {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) problem = decoded;
    } on FormatException {
      // Not JSON (for example an HTML error page from a proxy): use fallbacks.
    }

    // Server faults get one consistent message; their detail adds nothing
    // a user can act on.
    final detail = problem['detail'];
    final message = status < 500 && detail is String && detail.isNotEmpty
        ? detail
        : _fallbackMessage(status);

    final fieldErrors = <String, String>{};
    final errors = problem['errors'];
    if (errors is List) {
      for (final e in errors) {
        if (e is Map && e['field'] is String && e['message'] is String) {
          fieldErrors.putIfAbsent(
            e['field'] as String,
            () => e['message'] as String,
          );
        }
      }
    }

    return ApiException(
      kind: kind,
      message: message,
      statusCode: status,
      fieldErrors: fieldErrors,
      details: problem,
    );
  }

  String _fallbackMessage(int status) {
    if (status >= 500) {
      return 'The server ran into a problem. Please try again later.';
    }
    return switch (status) {
      400 => 'The request was not valid.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have permission to do this.',
      404 => 'The item could not be found.',
      409 => 'This change conflicts with existing data.',
      _ => 'Unexpected response from the server (HTTP $status).',
    };
  }
}
