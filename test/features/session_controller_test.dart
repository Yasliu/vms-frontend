import 'package:flutter_test/flutter_test.dart';
import 'package:vms_frontend/core/network/api_exception.dart';
import 'package:vms_frontend/features/auth/session_controller.dart';

import '../support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late DateTime now;
  late SessionController session;

  setUp(() {
    now = DateTime(2026, 6, 1, 10);
    auth = FakeAuthRepository(now: () => now);
    session = SessionController(auth, now: () => now);
  });

  test('starts signed out with no token', () {
    expect(session.isSignedIn, isFalse);
    expect(session.accessToken, isNull);
    expect(session.email, isNull);
  });

  test('a valid login signs in and exposes the token', () async {
    var notified = 0;
    session.addListener(() => notified++);

    await session.login(validEmail, validPassword);

    expect(session.isSignedIn, isTrue);
    expect(session.email, validEmail);
    expect(session.accessToken, isNotNull);
    expect(notified, 1);
  });

  test('wrong credentials leave the user signed out and rethrow', () async {
    await expectLater(
      session.login(validEmail, 'wrong'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.unauthorized,
        ),
      ),
    );

    expect(session.isSignedIn, isFalse);
    expect(session.accessToken, isNull);
  });

  test('a network failure leaves the user signed out', () async {
    auth.failWith = const ApiException(
      kind: ApiErrorKind.network,
      message: 'down',
    );

    await expectLater(
      session.login(validEmail, validPassword),
      throwsA(isA<ApiException>()),
    );

    expect(session.isSignedIn, isFalse);
  });

  test('logout clears the session and leaves no notice', () async {
    await session.login(validEmail, validPassword);

    session.logout();

    expect(session.isSignedIn, isFalse);
    expect(session.accessToken, isNull);
    expect(session.notice, isNull);
  });

  test(
    'expire (server rejected the token) signs out with an explanatory notice',
    () async {
      await session.login(validEmail, validPassword);

      session.expire();

      expect(session.isSignedIn, isFalse);
      expect(session.notice, SessionController.expiredNotice);
    },
  );

  test('expire does nothing when already signed out', () {
    var notified = 0;
    session.addListener(() => notified++);

    session.expire();

    expect(notified, 0);
    expect(session.notice, isNull);
  });

  test(
    'a token past its expiry is never handed out and ends the session',
    () async {
      await session.login(validEmail, validPassword);
      now = now.add(const Duration(minutes: 31));

      expect(session.accessToken, isNull);
      await pumpEventQueue();

      expect(session.isSignedIn, isFalse);
      expect(session.notice, SessionController.expiredNotice);
    },
  );

  test(
    'a token close to expiry is treated as expired (clock-skew margin)',
    () async {
      await session.login(validEmail, validPassword);
      now = now.add(const Duration(minutes: 29, seconds: 57));

      expect(session.accessToken, isNull);
    },
  );

  test('signing in again clears the expiry notice', () async {
    await session.login(validEmail, validPassword);
    session.expire();
    expect(session.notice, isNotNull);

    await session.login(validEmail, validPassword);

    expect(session.notice, isNull);
    expect(session.isSignedIn, isTrue);
  });

  group('register', () {
    test('signs the new user in', () async {
      var notified = 0;
      session.addListener(() => notified++);

      await session.register(
        'new.user@example.com',
        'a-brand-new-password-1',
        validRegistrationCode,
      );

      expect(session.isSignedIn, isTrue);
      expect(session.email, 'new.user@example.com');
      expect(session.accessToken, isNotNull);
      expect(notified, 1);
    });

    test('a wrong code leaves the user signed out and rethrows', () async {
      await expectLater(
        session.register(
          'new.user@example.com',
          'a-brand-new-password-1',
          'wrong',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.forbidden,
          ),
        ),
      );

      expect(session.isSignedIn, isFalse);
    });

    test('an email that is already registered is refused', () async {
      await expectLater(
        session.register(
          validEmail,
          'a-brand-new-password-1',
          validRegistrationCode,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.conflict,
          ),
        ),
      );

      expect(session.isSignedIn, isFalse);
    });

    test('registering clears an earlier expiry notice', () async {
      await session.login(validEmail, validPassword);
      session.expire();
      expect(session.notice, isNotNull);

      await session.register(
        'new.user@example.com',
        'a-brand-new-password-1',
        validRegistrationCode,
      );

      expect(session.notice, isNull);
    });
  });
}
