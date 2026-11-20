import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_backend.dart';
import '../support/fake_auth_repository.dart';
import '../support/fake_vehicle_repository.dart';
import '../support/test_app.dart';

const wrongPassword = 'definitely-wrong-password-marker';

Future<void> signIn(
  WidgetTester tester, {
  String email = validEmail,
  String password = validPassword,
}) async {
  await typeCredentials(tester, email: email, password: password);
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  group('signing in', () {
    testWidgets(
      'valid credentials open the app and load real data with the token',
      (tester) async {
        final backend = await openAgainstBackend(tester);

        await signIn(tester);

        expect(find.text('Welcome back'), findsNothing);
        expect(find.text('AB 12345'), findsOneWidget);
        expect(
          find.text(validEmail),
          findsOneWidget,
          reason: 'the signed-in user is shown',
        );
        expect(
          backend.loginRequests.single.headers.containsKey('Authorization'),
          isFalse,
        );
        expect(backend.vehicleRequests, isNotEmpty);
        for (final r in backend.vehicleRequests) {
          expect(r.headers['Authorization'], 'Bearer ${FakeBackend.token}');
        }
      },
    );

    testWidgets('the email is matched however it is typed', (tester) async {
      await openAgainstBackend(tester);

      await signIn(tester, email: '  ADMIN@Example.com ');

      expect(find.text('AB 12345'), findsOneWidget);
    });

    testWidgets(
      'wrong credentials show a clear error and stay on the sign-in screen',
      (tester) async {
        final backend = await openAgainstBackend(tester);

        await signIn(tester, password: wrongPassword);

        expect(
          find.textContaining('Incorrect email or password'),
          findsOneWidget,
        );
        expect(find.text('Welcome back'), findsOneWidget);
        expect(
          backend.vehicleRequests,
          isEmpty,
          reason: 'no vehicle call without a session',
        );
        final password = tester.widget<EditableText>(
          find.byType(EditableText).at(1),
        );
        expect(
          password.controller.text,
          isEmpty,
          reason: 'the password is cleared after a failure',
        );
        final email = tester.widget<EditableText>(
          find.byType(EditableText).at(0),
        );
        expect(
          email.controller.text,
          validEmail,
          reason: 'the email is kept for another try',
        );
      },
    );

    testWidgets('after a failure the user can try again and succeed', (
      tester,
    ) async {
      await openAgainstBackend(tester);
      await signIn(tester, password: wrongPassword);

      await tester.enterText(find.byType(EditableText).at(1), validPassword);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('AB 12345'), findsOneWidget);
    });

    testWidgets(
      'an unreachable server gets its own message, not "wrong password"',
      (tester) async {
        final backend = await openAgainstBackend(tester);
        backend.down = true;

        await signIn(tester);

        expect(find.textContaining('Cannot reach the server'), findsOneWidget);
        expect(
          find.textContaining('Incorrect email or password'),
          findsNothing,
        );
        expect(find.text('Welcome back'), findsOneWidget);
      },
    );

    testWidgets('empty fields are caught before any request', (tester) async {
      final backend = await openAgainstBackend(tester);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('tapping Sign in repeatedly sends one request', (tester) async {
      final auth = FakeAuthRepository()..gate = Completer<void>();
      await openApp(tester, FakeVehicleRepository(), auth: auth);
      await typeCredentials(tester);

      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.tap(find.text('Sign in'), warnIfMissed: false);
      await tester.pump();

      expect(auth.attempts, hasLength(1));
      auth.gate!.complete();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('the false "demo mode" message is gone', (tester) async {
      await openAgainstBackend(tester);

      expect(find.textContaining('Demo mode'), findsNothing);
    });
  });

  group('protected access', () {
    testWidgets(
      'opening the app address directly never shows vehicles without signing in',
      (tester) async {
        tester.platformDispatcher.defaultRouteNameTestValue = '/app';
        addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
        final backend = await openAgainstBackend(tester);
        await tester.pumpAndSettle();

        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.text('AB 12345'), findsNothing);
        expect(backend.vehicleRequests, isEmpty);
      },
    );

    testWidgets(
      'when the server rejects the token the user is sent back to sign in',
      (tester) async {
        final backend = await openAgainstBackend(tester);
        await signIn(tester);
        expect(find.text('AB 12345'), findsOneWidget);

        backend.tokensExpired = true;
        await tester.tap(find.byTooltip('Refresh list'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(find.text('Welcome back'), findsOneWidget);
        expect(
          find.text('Your session has expired. Please sign in again.'),
          findsOneWidget,
        );
        expect(find.text('AB 12345'), findsNothing);
      },
    );

    testWidgets('signing in again after expiry works and clears the notice', (
      tester,
    ) async {
      final backend = await openAgainstBackend(tester);
      await signIn(tester);
      backend.tokensExpired = true;
      await tester.tap(find.byTooltip('Refresh list'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      backend.tokensExpired = false;
      await signIn(tester);

      expect(find.text('AB 12345'), findsOneWidget);
      expect(find.textContaining('session has expired'), findsNothing);
    });

    testWidgets('signing out returns to sign-in and forgets the data', (
      tester,
    ) async {
      final backend = await openAgainstBackend(tester);
      await signIn(tester);
      final loadsBefore = backend.vehicleRequests.length;

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('AB 12345'), findsNothing);
      expect(find.textContaining('session has expired'), findsNothing);

      await signIn(tester);
      expect(find.text('AB 12345'), findsOneWidget);
      expect(
        backend.vehicleRequests.length,
        greaterThan(loadsBefore),
        reason: 'data is fetched fresh for the new session',
      );
    });
  });

  group('credential hygiene', () {
    testWidgets('passwords and tokens are never printed to the console', (
      tester,
    ) async {
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
      await signIn(tester, password: wrongPassword);
      await signIn(tester);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final everything =
          '${printed.join('\n')}\n${errors.map((e) => e.toString()).join('\n')}';
      expect(everything, isNot(contains(wrongPassword)));
      expect(everything, isNot(contains(validPassword)));
      expect(everything, isNot(contains(FakeBackend.token)));
    });

    testWidgets(
      'the password is sent only in the body of the sign-in request',
      (tester) async {
        final backend = await openAgainstBackend(tester);
        await signIn(tester);

        for (final r in backend.requests) {
          expect(r.url.toString(), isNot(contains(validPassword)));
          expect(r.headers.values.join(), isNot(contains(validPassword)));
          if (r.url.path != '/api/v1/auth/login') {
            expect(r.body, isNot(contains(validPassword)));
          }
        }
        expect(backend.loginRequests.single.body, contains(validPassword));
      },
    );

    testWidgets('the password field hides what is typed', (tester) async {
      await openAgainstBackend(tester);

      final password = tester.widget<EditableText>(
        find.byType(EditableText).at(1),
      );

      expect(password.obscureText, isTrue);
    });
  });
}
