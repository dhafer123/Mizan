import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../expenses/domain/entities/category.dart';
import '../../../expenses/presentation/shared/categories_provider.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';
import '../shared/group_data_providers.dart';
import '../shared/load_error.dart';

/// The group's expenses, newest first: what, who paid, and how much.
class ExpensesTab extends ConsumerWidget {
  const ExpensesTab({required this.group, super.key});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = {
      for (final m
          in ref.watch(membersProvider(group.id)).value ?? const <Member>[])
        m.id: m.displayName,
    };
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c.name,
    };
    final dates = MaterialLocalizations.of(context);
    return ref
        .watch(sharedExpensesProvider(group.id))
        .when(
          data: (expenses) => expenses.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No expenses yet. Add the first one.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.only(
                    bottom: 88 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    for (final e in expenses)
                      ListTile(
                        title: Text(
                          categories[e.categoryId] ??
                              'Shared by ${e.shares.length}',
                        ),
                        subtitle: Text(
                          'Paid by ${names[e.payerId] ?? 'a former member'} · '
                          '${dates.formatMediumDate(e.date)}',
                        ),
                        trailing: Text(const MoneyFormatter().format(e.amount)),
                      ),
                  ],
                ),
          error: (error, _) => LoadError(
            message: failureMessage(error),
            onRetry: () => ref.invalidate(sharedExpensesProvider(group.id)),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
  }
}
