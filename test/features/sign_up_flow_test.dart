import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_backend.dart';
import '../support/fake_vehicle_repository.dart';
import '../support/test_app.dart';

const newPassword = 'a-brand-new-password-1';
const newEmail = 'new.user@example.com';

Future<void> openSignUp(WidgetTester tester) async {
  await tester.tap(find.text('Sign up'));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Create account'));
  await tester.tap(find.text('Create account'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  group('getting to the sign-up screen', () {
    testWidgets('the sign-in screen links to sign-up and back', (tester) async {
      await openAgainstBackend(tester);

      await openSignUp(tester);
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('the sign-up address opens the sign-up screen directly', (
      tester,
    ) async {
      tester.platformDispatcher.defaultRouteNameTestValue = '/register';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      await openAgainstBackend(tester);

      expect(find.text('Create your account'), findsOneWidget);
    });
  });

  group('validation happens before any request', () {
    testWidgets('empty form', (tester) async {
      final backend = await openAgainstBackend(tester);
      await openSignUp(tester);

      await submit(tester);

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter a password.'), findsOneWidget);
      expect(find.text('Enter the password again.'), findsOneWidget);
      expect(find.text('Enter the registration code.'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('typing in one field does not flag the untouched ones', (
      tester,
    ) async {
      await openAgainstBackend(tester);
      await openSignUp(tester);

      await tester.enterText(find.byType(EditableText).at(0), newEmail);
      await tester.pumpAndSettle();

      expect(find.text('Enter a password.'), findsNothing);
      expect(find.text('Enter the password again.'), findsNothing);
      expect(find.text('Enter the registration code.'), findsNothing);

      await tester.enterText(find.byType(EditableText).at(0), '');
      await tester.pumpAndSettle();
      expect(
        find.text('Enter your email address.'),
        findsOneWidget,
        reason: 'the touched field is validated',
      );
    });

    testWidgets('short password, mismatch and a malformed email', (
      tester,
    ) async {
      final backend = await openAgainstBackend(tester);
      await openSignUp(tester);

      await typeSignUp(
        tester,
        email: 'not-an-email',
        password: 'too short',
        confirm: 'different',
      );
      await submit(tester);

      expect(find.textContaining('Enter a valid email'), findsOneWidget);
      expect(find.textContaining('Use 12 to 72 characters'), findsOneWidget);
      expect(find.text('The two passwords do not match.'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('a password that is too long is caught locally', (
      tester,
    ) async {
      final backend = await openAgainstBackend(tester);
      await openSignUp(tester);

      await typeSignUp(tester, password: 'x' * 73);
      await submit(tester);

      expect(find.textContaining('Use 12 to 72 characters'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });
  });

  group('signing up', () {
    testWidgets(
      'a valid sign-up creates the account, signs in and loads the app with the token',
      (tester) async {
        final backend = await openAgainstBackend(tester);
        await openSignUp(tester);

        await typeSignUp(tester);
        await submit(tester);

        expect(find.text('Create your account'), findsNothing);
        expect(
          find.text('AB 12345'),
          findsOneWidget,
          reason: 'the vehicle list loaded with the new session',
        );
        expect(
          find.text(newEmail),
          findsOneWidget,
          reason: 'the new account is the one signed in',
        );
        expect(backend.registerRequests, hasLength(1));
        expect(
          backend.registerRequests.single.headers.containsKey('Authorization'),
          isFalse,
        );
        for (final r in backend.vehicleRequests) {
          expect(r.headers['Authorization'], 'Bearer ${FakeBackend.token}');
        }
      },
    );

    testWidgets(
      'a wrong registration code is shown on that field and nothing is lost',
      (tester) async {
        final backend = await openAgainstBackend(tester);
        await openSignUp(tester);

        await typeSignUp(tester, code: 'definitely-wrong-code');
        await submit(tester);

        expect(
          find.text('That registration code is not valid.'),
          findsOneWidget,
        );
        expect(
          find.text('Create your account'),
          findsOneWidget,
          reason: 'still on the form',
        );
        expect(backend.vehicleRequests, isEmpty);
        final fields = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .toList();
        expect(fields[0].controller.text, newEmail, reason: 'email kept');
        expect(
          fields[1].controller.text,
          newPassword,
          reason: 'password kept so only the code needs fixing',
        );

        await tester.enterText(
          find.byType(EditableText).at(3),
          validRegistrationCode,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('That registration code is not valid.'),
          findsNothing,
          reason: 'editing clears the server message',
        );

        await submit(tester);
        expect(find.text('AB 12345'), findsOneWidget);
      },
    );

    testWidgets(
      'an email that already has an account is explained on the email field',
      (tester) async {
        final backend = await openAgainstBackend(tester);
        await openSignUp(tester);

        await typeSignUp(tester, email: '  ADMIN@Example.com ');
        await submit(tester);

        expect(
          find.textContaining('An account with this email already exists'),
          findsOneWidget,
        );
        expect(find.text('Create your account'), findsOneWidget);
        expect(backend.registeredEmails, {
          validEmail,
        }, reason: 'nothing was created');

        await tester.enterText(find.byType(EditableText).at(0), newEmail);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('An account with this email already exists'),
          findsNothing,
        );
      },
    );

    testWidgets('when sign-up is switched off the user is told plainly', (
      tester,
    ) async {
      final backend = await openAgainstBackend(tester);
      backend.signUpDisabled = true;
      await openSignUp(tester);

      await typeSignUp(tester);
      await submit(tester);

      expect(
        find.text(
          'Sign-up is not available right now. Ask your administrator.',
        ),
        findsOneWidget,
      );
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets(
      'an unreachable server gets a connection message and keeps the input',
      (tester) async {
        final backend = await openAgainstBackend(tester);
        backend.down = true;
        await openSignUp(tester);

        await typeSignUp(tester);
        await submit(tester);

        expect(find.textContaining('Cannot reach the server'), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).at(0))
              .controller
              .text,
          newEmail,
        );

        backend.down = false;
        await submit(tester);
        expect(
          find.text('AB 12345'),
          findsOneWidget,
          reason: 'retrying the same form works',
        );
      },
    );

    testWidgets('tapping Create account repeatedly sends one request', (
      tester,
    ) async {
      final auth = FakeAuthRepository()..gate = Completer<void>();
      await openApp(tester, FakeVehicleRepository(), auth: auth);
      await openSignUp(tester);
      await typeSignUp(tester);

      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pump();
      await tester.tap(find.text('Create account'), warnIfMissed: false);
      await tester.pump();

      expect(auth.registrations, hasLength(1));
      auth.gate!.complete();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  group('credential hygiene', () {
    testWidgets('the password, confirmation and code are hidden while typing', (
      tester,
    ) async {
      await openAgainstBackend(tester);
      await openSignUp(tester);

      final fields = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();

      expect(fields[0].obscureText, isFalse, reason: 'the email is visible');
      expect(fields[1].obscureText, isTrue);
      expect(fields[2].obscureText, isTrue);
      expect(fields[3].obscureText, isTrue);
    });

    testWidgets(
      'secrets appear only in the sign-up request body, never in a URL or header',
      (tester) async {
        final backend = await openAgainstBackend(tester);
        await openSignUp(tester);
        await typeSignUp(tester);
        await submit(tester);

        for (final r in backend.requests) {
          expect(r.url.toString(), isNot(contains(newPassword)));
          expect(r.url.toString(), isNot(contains(validRegistrationCode)));
          expect(r.headers.values.join(), isNot(contains(newPassword)));
          expect(
            r.headers.values.join(),
            isNot(contains(validRegistrationCode)),
          );
          if (r.url.path != '/api/v1/auth/register') {
            expect(r.body, isNot(contains(newPassword)));
            expect(r.body, isNot(contains(validRegistrationCode)));
          }
        }
        expect(backend.registerRequests.single.body, contains(newPassword));
      },
    );

    testWidgets(
      'nothing secret is printed to the console, on success or failure',
      (tester) async {
        final printed = <String>[];
        final original = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) =>
            printed.add(message ?? '');
        addTearDown(() => debugPrint = original);
        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = originalOnError);

        await openAgainstBackend(tester);
        await openSignUp(tester);
        await typeSignUp(tester, code: 'wrong-code-marker-xyz');
        await submit(tester);
        await typeSignUp(tester);
        await submit(tester);

        final everything = '${printed.join('\\n')}\\n${errors.join('\\n')}';
        expect(everything, isNot(contains(newPassword)));
        expect(everything, isNot(contains(validRegistrationCode)));
        expect(everything, isNot(contains('wrong-code-marker-xyz')));
        expect(everything, isNot(contains(FakeBackend.token)));
      },
    );
  });

  testWidgets('the sign-up form lays out on a phone-sized screen', (
    tester,
  ) async {
    await openAgainstBackend(tester, size: const Size(390, 844));
    await openSignUp(tester);

    expect(find.text('Create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
