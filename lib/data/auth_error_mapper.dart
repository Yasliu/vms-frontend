import '../core/network/api_exception.dart';

/// Turns the backend's sign-up errors into messages for people. Screens never
/// see server wording.
class AuthErrorMapper {
  AuthErrorMapper._();

  static const _wrongCodeFragment = 'not valid';

  static ApiException forRegister(ApiException e) {
    switch (e.kind) {
      case ApiErrorKind.conflict:
        const message =
            'An account with this email already exists. Try signing in instead.';
        return _copy(e, message, {'email': message});

      case ApiErrorKind.forbidden:
        // "That registration code is not valid." belongs on the code field;
        // "Sign-up is not available right now." is not about any one field.
        if (e.message.toLowerCase().contains(_wrongCodeFragment)) {
          return _copy(e, e.message, {'registrationCode': e.message});
        }
        return _copy(
          e,
          'Sign-up is not available right now. Ask your administrator.',
          const {},
        );

      case ApiErrorKind.validation:
        if (e.fieldErrors.isEmpty) {
          return _copy(
            e,
            'Your details could not be saved. Check the form and try again.',
            const {},
          );
        }
        return _copy(e, 'Please correct the highlighted fields.', {
          for (final entry in e.fieldErrors.entries)
            entry.key: fieldMessage(entry.key, entry.value),
        });

      default:
        return e;
    }
  }

  /// Rewrites one Bean Validation message for a sign-up [field].
  static String fieldMessage(String field, String serverMessage) {
    final text = serverMessage.toLowerCase();
    final blank =
        text.contains('must not be blank') ||
        text.contains('must not be null') ||
        text.contains('must not be empty');

    switch (field) {
      case 'email':
        if (blank) return 'Enter your email address.';
        if (text.contains('email')) {
          return 'Enter a valid email, for example name@company.com.';
        }
        if (text.contains('between')) return 'That email address is too long.';
      case 'password':
        if (blank) return 'Enter a password.';
        final size = RegExp(r'between (\d+) and (\d+)').firstMatch(text);
        if (size != null) {
          return 'Use ${size.group(1)} to ${size.group(2)} characters '
              'for the password.';
        }
      case 'registrationCode':
        if (blank) return 'Enter the registration code.';
    }
    return 'This value is not valid.';
  }

  static ApiException _copy(
    ApiException e,
    String message,
    Map<String, String> fieldErrors,
  ) => ApiException(
    kind: e.kind,
    message: message,
    statusCode: e.statusCode,
    fieldErrors: fieldErrors,
    details: e.details,
  );
}
