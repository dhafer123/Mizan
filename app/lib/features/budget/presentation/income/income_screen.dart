import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/entities/income_source.dart';
import '../../domain/value_objects/income_schedule.dart';
import '../budget/budget_providers.dart';
import 'income_sheet.dart';

/// The income sources. Tap one to edit or delete it.
class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
      body: ref
          .watch(incomeSourcesProvider)
          .when(
            data: (sources) => sources.isEmpty
                ? const _NoIncome()
                : ListView(
                    // Clear of the add button and the system inset.
                    padding: EdgeInsets.only(
                      bottom: 88 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      for (final source in sources)
                        _IncomeTile(
                          source: source,
                          onTap: () => showIncomeSheet(context, source: source),
                        ),
                    ],
                  ),
            error: (error, _) => _LoadError(
              message: failureMessage(error),
              onRetry: () => ref.invalidate(incomeSourcesProvider),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showIncomeSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add income'),
      ),
    );
  }
}

class _IncomeTile extends StatelessWidget {
  const _IncomeTile({required this.source, required this.onTap});

  final IncomeSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        child: ExcludeSemantics(child: Icon(Icons.payments_outlined)),
      ),
      title: Text(source.name),
      subtitle: Text(describeSchedule(context, source.schedule)),
      trailing: Text(
        const MoneyFormatter().format(source.amount),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

/// "Monthly on day 15", "Once, on Tue, Oct 20", "Irregular, per month".
String describeSchedule(
  BuildContext context,
  IncomeSchedule schedule,
) => switch (schedule) {
  MonthlyIncome(:final dayOfMonth) => 'Monthly on day $dayOfMonth',
  OneOffIncome(:final date) =>
    'Once, on ${MaterialLocalizations.of(context).formatMediumDate(DateTime(date.year, date.month, date.day))}',
  IrregularIncome() => 'Irregular, about this much a month',
};

class _NoIncome extends StatelessWidget {
  const _NoIncome();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.payments_outlined, size: 56),
            const SizedBox(height: 16),
            Text('No income yet', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add your grant, job or family support to see what you can '
              'spend each month.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
