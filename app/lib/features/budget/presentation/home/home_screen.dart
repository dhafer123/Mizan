import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/widgets/entrance.dart';
import '../../../../app/widgets/load_error.dart';
import '../../../../app/widgets/skeleton.dart';
import '../../../expenses/presentation/expense_sheet/expense_sheet.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../../mascot/presentation/penny_card.dart';
import '../../../mascot/presentation/penny_lines.dart';
import '../../../mascot/presentation/penny_providers.dart';
import '../../../quick_input/presentation/quick_input_sheet.dart';
import '../../../sync/presentation/sync_status_button.dart';
import '../../domain/value_objects/dashboard.dart';
import 'dashboard_provider.dart';
import 'forecast_card.dart';
import 'money_left_card.dart';
import 'recent_expenses_card.dart';
import 'top_categories_card.dart';

/// The dashboard: money left this month, days until the next income, when
/// the money runs out, where it went, and the newest expenses.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mizan'),
        actions: [
          const SyncStatusButton(),
          IconButton(
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ref
          .watch(dashboardProvider)
          .when(
            // Keep showing the last numbers while a change recomputes.
            skipLoadingOnReload: true,
            data: (dashboard) => _DashboardBody(dashboard: dashboard),
            error: (error, _) => LoadError(
              message: failureMessage(error),
              onRetry: () => retryDashboard(ref),
            ),
            loading: () =>
                const SkeletonCards(heights: [96, 200, 120, 280, 200]),
          ),
      floatingActionButton: _AddButtons(
        onQuickInput: () => _quickInput(context, ref),
        onAdd: () async {
          final saved = await showExpenseSheet(context);
          if (saved == true) _pennyReacts(ref);
        },
      ),
    );
  }
}

class _AddButtons extends StatelessWidget {
  const _AddButtons({required this.onQuickInput, required this.onAdd});

  final VoidCallback onQuickInput;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'quick-input',
          onPressed: onQuickInput,
          tooltip: 'Say an expense',
          child: const Icon(Icons.mic_none),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: 'add-expense',
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add expense'),
        ),
      ],
    );
  }
}

/// Penny cheers when something is logged from Home, louder for the first
/// expense of the month.
void _pennyReacts(WidgetRef ref) {
  final firstOfMonth = ref.read(dashboardProvider).value?.isEmptyMonth ?? false;
  ref
      .read(pennyReactionProvider.notifier)
      .react(firstOfMonth ? PennyMoment.firstOfMonth : PennyMoment.logged);
}

Future<void> _quickInput(BuildContext context, WidgetRef ref) async {
  final saved = await showQuickInputSheet(context);
  if (saved == null || saved == 0 || !context.mounted) return;
  _pennyReacts(ref);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          saved == 1 ? 'Added 1 expense.' : 'Added $saved expenses.',
        ),
      ),
    );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Clear of the add buttons and the system inset.
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        140 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        // The cards come in one after another, top first.
        for (final (i, card) in [
          const PennyCard(),
          MoneyLeftCard(dashboard: dashboard),
          ForecastCard(
            owedToMe: dashboard.owedToMe,
            nextIncome: dashboard.available.next?.date,
          ),
          TopCategoriesCard(dashboard: dashboard),
          RecentExpensesCard(expenses: dashboard.recent),
        ].indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          Entrance(index: i, child: card),
        ],
      ],
    );
  }
}
