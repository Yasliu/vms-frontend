/// What went wrong, in terms the UI can react to.
enum ApiErrorKind {
  /// The server could not be reached at all.
  network,
  timeout,

  /// 400: the request was rejected as invalid.
  validation,

  /// 401: not signed in, wrong credentials, or the session has expired.
  unauthorized,

  /// 403: signed in but not allowed to do this.
  forbidden,
  notFound,

  /// 409: for example a duplicate vehicle number.
  conflict,
  server,
  unexpected,
}

/// The only error type the data layer throws. [message] is always safe to show
/// to a user: it never contains URLs, stack traces or raw response bodies.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.details = const {},
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  /// Per-field problems reported by the server (field name -> message).
  final Map<String, String> fieldErrors;

  /// The decoded problem document, for the data layer to inspect.
  final Map<String, Object?> details;

  /// Whether retrying the same request later could succeed.
  bool get isRetryable =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.server;

  @override
  String toString() => 'ApiException($kind, $statusCode, $message)';
}
