import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_error.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_failure.dart';
import 'package:mizan/features/auth/domain/value_objects/credentials.dart';

import '../../../../support/fake_auth_repository.dart';
import '../auth_test_app.dart';

Future<FakeAuthRepository> _open(WidgetTester tester) async {
  final repository = FakeAuthRepository();
  await pumpAuthApp(tester, repository);
  await tester.pumpAndSettle();
  await tester.tap(find.text('open login'));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _fill(
  WidgetTester tester, {
  String email = 'sami@example.com',
  String password = 'correct-horse',
}) async {
  await tester.enterText(field('Email'), email);
  await tester.enterText(field('Password'), password);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signs in and goes back with true', (tester) async {
    final repository = await _open(tester);

    await _fill(tester, email: ' Sami@Example.com ');
    await _submit(tester);

    expect(
      repository.credentials.single,
      const Credentials(email: 'sami@example.com', password: 'correct-horse'),
    );
    expect(find.byType(TextField), findsNothing, reason: 'screen closed');
    expect(popped, [true]);
  });

  testWidgets('a bad email shows under the field; typing clears it', (
    tester,
  ) async {
    final repository = await _open(tester);

    await _fill(tester, email: 'sami');
    await _submit(tester);

    expect(errorOf(tester, 'Email'), 'Enter a valid email address.');
    expect(repository.calls, isEmpty);

    await tester.enterText(field('Email'), 'sami@');
    await tester.pump();
    expect(errorOf(tester, 'Email'), isNull);
  });

  testWidgets('an empty password shows under the password', (tester) async {
    await _open(tester);

    await _fill(tester, password: '');
    await _submit(tester);

    expect(errorOf(tester, 'Password'), 'Enter your password.');
  });

  testWidgets('a wrong password shows above the button and can be retried', (
    tester,
  ) async {
    final repository = await _open(tester);
    repository.failure = const AuthFailure(AuthError.invalidCredentials);

    await _fill(tester);
    await _submit(tester);

    expect(find.text('Wrong email or password.'), findsOneWidget);
    expect(popped, isEmpty);

    repository.failure = null;
    await _submit(tester);
    expect(popped, [true]);
  });

  testWidgets('offline', (tester) async {
    final repository = await _open(tester);
    repository.failure = const AuthFailure(AuthError.offline);

    await _fill(tester);
    await _submit(tester);

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('while signing in: a spinner, and the form is locked', (
    tester,
  ) async {
    final repository = await _open(tester);
    repository.gate = Completer<void>();

    await _fill(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(field('Email')).enabled, isFalse);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(popped, [true]);
  });

  testWidgets('the password can be shown', (tester) async {
    await _open(tester);
    bool obscured() => tester.widget<TextField>(field('Password')).obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);
  });

  testWidgets('creating an account from here closes both screens', (
    tester,
  ) async {
    final repository = await _open(tester);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Email'), 'ali@example.com');
    await tester.enterText(field('Password'), 'correct-horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['signUp']);
    expect(find.byType(TextField), findsNothing);
    expect(popped, [true]);
  });
}
