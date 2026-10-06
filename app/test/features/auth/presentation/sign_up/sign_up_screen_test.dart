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
  await tester.tap(find.text('open sign-up'));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _create(
  WidgetTester tester, {
  String name = '',
  String email = 'ali@example.com',
  String password = 'correct-horse',
}) async {
  await tester.enterText(field('Name (optional)'), name);
  await tester.enterText(field('Email'), email);
  await tester.enterText(field('Password'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('creates the account and goes back with true', (tester) async {
    final repository = await _open(tester);

    await _create(tester, name: ' Ali ');

    expect(
      repository.credentials.single,
      const Credentials(
        email: 'ali@example.com',
        password: 'correct-horse',
        displayName: 'Ali',
      ),
    );
    expect(popped, [true]);
  });

  testWidgets('a short password shows under the password', (tester) async {
    final repository = await _open(tester);

    await _create(tester, password: 'short');

    expect(errorOf(tester, 'Password'), 'Use 8 to 128 characters.');
    expect(repository.calls, isEmpty);
  });

  testWidgets('a long name shows under the name', (tester) async {
    await _open(tester);

    await _create(tester, name: 'a' * 51);

    expect(errorOf(tester, 'Name (optional)'), 'Use 50 characters or fewer.');
  });

  testWidgets('a taken email shows under the email', (tester) async {
    final repository = await _open(tester);
    repository.failure = const AuthFailure(AuthError.emailTaken);

    await _create(tester);

    expect(
      errorOf(tester, 'Email'),
      'An account with this email already exists. Sign in instead.',
    );
    expect(popped, isEmpty);
  });

  testWidgets('a weak password (server) shows under the password', (
    tester,
  ) async {
    final repository = await _open(tester);
    repository.failure = const AuthFailure(AuthError.weakPassword);

    await _create(tester, password: '12345678');

    expect(errorOf(tester, 'Password'), contains('too easy to guess'));
  });

  testWidgets('too many tries shows above the button', (tester) async {
    final repository = await _open(tester);
    repository.failure = const AuthFailure(AuthError.tooManyAttempts);

    await _create(tester);

    expect(
      find.text('Too many tries. Wait a minute and try again.'),
      findsOneWidget,
    );
  });
}
