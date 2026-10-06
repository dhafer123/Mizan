import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mizan/app/di/auth_providers.dart';
import 'package:mizan/app/router/app_router.dart';
import 'package:mizan/features/auth/presentation/account_section.dart';
import 'package:mizan/features/auth/presentation/login/login_screen.dart';
import 'package:mizan/features/auth/presentation/sign_up/sign_up_screen.dart';

import '../../../support/fake_auth_repository.dart';

/// Results the start page got back from pushing a route.
final popped = <Object?>[];

/// A start page with the [AccountSection] and buttons that open the auth
/// screens, plus the real routes for them.
Future<void> pumpAuthApp(
  WidgetTester tester,
  FakeAuthRepository repository,
) async {
  popped.clear();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ListView(
            children: [
              const AccountSection(),
              TextButton(
                onPressed: () async =>
                    popped.add(await context.push<bool>(AppRoutes.login)),
                child: const Text('open login'),
              ),
              TextButton(
                onPressed: () async =>
                    popped.add(await context.push<bool>(AppRoutes.signUp)),
                child: const Text('open sign-up'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

Finder field(String label) => find.widgetWithText(TextField, label);

String? errorOf(WidgetTester tester, String label) =>
    tester.widget<TextField>(field(label)).decoration?.errorText;
