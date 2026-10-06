import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mizan/features/auth/domain/entities/account.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_error.dart';
import 'package:mizan/features/auth/domain/value_objects/auth_failure.dart';

import '../../../support/fake_auth_repository.dart';
import 'auth_test_app.dart';

const _sami = Account(id: '1', email: 'sami@example.com', displayName: 'Sami');

Future<void> _logOut(WidgetTester tester, {required String confirm}) async {
  await tester.tap(find.text('Log out'));
  await tester.pumpAndSettle();
  expect(find.text('Log out?'), findsOneWidget);
  await tester.tap(find.widgetWithText(TextButton, confirm));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loading, then "Sign in to sync" in local-only mode', (
    tester,
  ) async {
    await pumpAuthApp(tester, FakeAuthRepository());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Sign in to sync'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
  });

  testWidgets('signing in from it shows the account', (tester) async {
    await pumpAuthApp(tester, FakeAuthRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in to sync'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Email'), 'sami@example.com');
    await tester.enterText(field('Password'), 'correct-horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Signed in.'), findsOneWidget);
    expect(find.text('sami@example.com'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('signed in: the name and email', (tester) async {
    await pumpAuthApp(tester, FakeAuthRepository(_sami));
    await tester.pumpAndSettle();

    expect(find.text('Sami'), findsOneWidget);
    expect(find.text('sami@example.com'), findsOneWidget);
  });

  testWidgets('without a name: just the email', (tester) async {
    await pumpAuthApp(
      tester,
      FakeAuthRepository(const Account(id: '1', email: 'sami@example.com')),
    );
    await tester.pumpAndSettle();

    expect(find.text('sami@example.com'), findsOneWidget);
  });

  testWidgets('log out asks first, then goes back to local-only', (
    tester,
  ) async {
    final repository = FakeAuthRepository(_sami);
    await pumpAuthApp(tester, repository);
    await tester.pumpAndSettle();

    await _logOut(tester, confirm: 'Log out');

    expect(repository.calls, ['logOut']);
    expect(find.text('Logged out.'), findsOneWidget);
    expect(find.text('Sign in to sync'), findsOneWidget);
  });

  testWidgets('cancelling log out keeps you signed in', (tester) async {
    final repository = FakeAuthRepository(_sami);
    await pumpAuthApp(tester, repository);
    await tester.pumpAndSettle();

    await _logOut(tester, confirm: 'Cancel');

    expect(repository.calls, isEmpty);
    expect(find.text('Sami'), findsOneWidget);
  });

  testWidgets('a failed log out shows why', (tester) async {
    final repository = FakeAuthRepository(_sami)
      ..failure = const AuthFailure(AuthError.storage);
    await pumpAuthApp(tester, repository);
    await tester.pumpAndSettle();

    await _logOut(tester, confirm: 'Log out');

    expect(
      find.text("Couldn't save on this device. Try again."),
      findsOneWidget,
    );
    expect(find.text('Sami'), findsOneWidget);
  });

  testWidgets('the session ending elsewhere shows as signed out', (
    tester,
  ) async {
    final repository = FakeAuthRepository(_sami);
    await pumpAuthApp(tester, repository);
    await tester.pumpAndSettle();

    await repository.logOut();
    await tester.pumpAndSettle();

    expect(find.text('Sign in to sync'), findsOneWidget);
  });

  testWidgets('a storage error shows, and can be retried', (tester) async {
    final repository = FakeAuthRepository()
      ..watchFailure = const AuthFailure(AuthError.storage);
    await pumpAuthApp(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save on this device. Try again."),
      findsOneWidget,
    );

    repository.watchFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to sync'), findsOneWidget);
  });
}
