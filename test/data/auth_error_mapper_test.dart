import 'package:flutter_test/flutter_test.dart';
import 'package:vms_frontend/core/network/api_exception.dart';
import 'package:vms_frontend/data/auth_error_mapper.dart';

ApiException error(
  ApiErrorKind kind, {
  String message = 'raw server text',
  Map<String, String> fieldErrors = const {},
}) => ApiException(
  kind: kind,
  message: message,
  statusCode: 400,
  fieldErrors: fieldErrors,
);

void main() {
  group('fieldMessage', () {
    test('blank fields ask for the right thing', () {
      expect(
        AuthErrorMapper.fieldMessage('email', 'must not be blank'),
        'Enter your email address.',
      );
      expect(
        AuthErrorMapper.fieldMessage('password', 'must not be blank'),
        'Enter a password.',
      );
      expect(
        AuthErrorMapper.fieldMessage('registrationCode', 'must not be blank'),
        'Enter the registration code.',
      );
    });

    test('a badly formed email is explained with an example', () {
      expect(
        AuthErrorMapper.fieldMessage(
          'email',
          'must be a well-formed email address',
        ),
        'Enter a valid email, for example name@company.com.',
      );
    });

    test('password length names the real limits', () {
      expect(
        AuthErrorMapper.fieldMessage(
          'password',
          'size must be between 12 and 72',
        ),
        'Use 12 to 72 characters for the password.',
      );
    });

    test('unknown wording falls back to a calm message', () {
      expect(
        AuthErrorMapper.fieldMessage('password', 'new rule'),
        'This value is not valid.',
      );
      expect(
        AuthErrorMapper.fieldMessage('mystery', 'x'),
        'This value is not valid.',
      );
    });
  });

  group('forRegister', () {
    test('a taken email points at the email field and suggests signing in', () {
      final mapped = AuthErrorMapper.forRegister(error(ApiErrorKind.conflict));

      expect(mapped.fieldErrors.keys, ['email']);
      expect(mapped.message, contains('Try signing in instead'));
    });

    test('a wrong code points at the code field', () {
      final mapped = AuthErrorMapper.forRegister(
        error(
          ApiErrorKind.forbidden,
          message: 'That registration code is not valid.',
        ),
      );

      expect(mapped.fieldErrors, {
        'registrationCode': 'That registration code is not valid.',
      });
    });

    test('sign-up being switched off is a banner, not a field error', () {
      final mapped = AuthErrorMapper.forRegister(
        error(
          ApiErrorKind.forbidden,
          message: 'Sign-up is not available right now.',
        ),
      );

      expect(mapped.fieldErrors, isEmpty);
      expect(
        mapped.message,
        'Sign-up is not available right now. Ask your administrator.',
      );
    });

    test('validation errors are rewritten per field', () {
      final mapped = AuthErrorMapper.forRegister(
        error(
          ApiErrorKind.validation,
          fieldErrors: {
            'email': 'must be a well-formed email address',
            'password': 'size must be between 12 and 72',
            'registrationCode': 'must not be blank',
          },
        ),
      );

      expect(mapped.message, 'Please correct the highlighted fields.');
      expect(mapped.fieldErrors.values.join(), isNot(contains('must')));
      expect(
        mapped.fieldErrors.keys,
        containsAll(['email', 'password', 'registrationCode']),
      );
    });

    test('network and other errors pass through untouched', () {
      final original = error(ApiErrorKind.network);

      expect(
        identical(AuthErrorMapper.forRegister(original), original),
        isTrue,
      );
    });
  });
}
