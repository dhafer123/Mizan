import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mizan/app/app_version.dart';
import 'package:mizan/app/di/beta_providers.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_error.dart';
import 'package:mizan/features/beta/domain/value_objects/beta_failure.dart';
import 'package:mizan/features/beta/presentation/feedback_screen.dart';

import '../../../support/fake_beta_repository.dart';

Future<FakeBetaRepository> _pump(WidgetTester tester) async {
  final repository = FakeBetaRepository();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/feedback'),
            child: const Text('Open'),
          ),
        ),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [betaRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return repository;
}

// FilledButton.icon is a private subclass, so match by `is`.
Finder get _send => find.ancestor(
  of: find.text('Send'),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);

void main() {
  testWidgets('Send is off until something is written', (tester) async {
    await _pump(tester);

    expect(tester.widget<FilledButton>(_send).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(_send).onPressed, isNull);
  });

  testWidgets('sends the message and contact, then closes', (tester) async {
    final repository = await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Add dark mode');
    await tester.enterText(find.byType(TextField).last, 'sami@example.com');
    await tester.pump();
    await tester.tap(_send);
    await tester.pumpAndSettle();

    final sent = repository.feedback.single;
    expect(sent.message, 'Add dark mode');
    expect(sent.contact, 'sami@example.com');
    expect(sent.appVersion, appVersion);
    expect(find.byType(FeedbackScreen), findsNothing);
    expect(find.text('Thanks! Your feedback was sent.'), findsOneWidget);
  });

  testWidgets('a failure shows its message and keeps the text', (tester) async {
    final repository = await _pump(tester);
    repository.failure = const BetaFailure(BetaError.offline);

    await tester.enterText(find.byType(TextField).first, 'Add dark mode');
    await tester.pump();
    await tester.tap(_send);
    await tester.pumpAndSettle();

    expect(
      find.text(const BetaFailure(BetaError.offline).message),
      findsOneWidget,
    );
    expect(find.text('Add dark mode'), findsOneWidget);
    expect(tester.widget<FilledButton>(_send).onPressed, isNotNull);
  });
}
