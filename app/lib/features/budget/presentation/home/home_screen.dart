import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';

/// Placeholder home screen. Becomes the dashboard in task 2.5; until then it
/// links to the expense list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mizan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 64),
              const SizedBox(height: 16),
              Text('No expenses yet', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Your spending and budget will show up here.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.expenses),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Expenses'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => context.push(AppRoutes.budget),
                icon: const Icon(Icons.savings_outlined),
                label: const Text('Budget'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
