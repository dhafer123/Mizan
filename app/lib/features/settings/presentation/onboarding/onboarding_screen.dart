import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/clock/year_month.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../auth/presentation/account_provider.dart';
import '../../../budget/domain/usecases/compute_budget_overview.dart';
import '../../../budget/domain/value_objects/income_schedule.dart';
import '../../../budget/presentation/budget/budget_limit_sheet.dart';
import '../../../budget/presentation/budget/budget_providers.dart';
import '../../../budget/presentation/income/income_sheet.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import 'onboarding_controller.dart';

const _money = MoneyFormatter();

/// First-run setup on a new install: a welcome, income, a monthly budget,
/// and an optional group. Every step can be skipped, and each saves through
/// the same sheets (and use cases) as the rest of the app, so nothing here
/// works differently offline.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 4;

  final _pages = PageController();
  var _step = 0;

  bool get _isLast => _step == _steps - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).finish();
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // System back walks back through the steps before leaving.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
                child: OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    Text(
                      'Step ${_step + 1} of $_steps',
                      style: theme.textTheme.labelLarge,
                    ),
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Skip setup'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _steps,
                  borderRadius: BorderRadius.circular(2),
                  semanticsLabel: 'Setup progress',
                  semanticsValue: 'Step ${_step + 1} of $_steps',
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  // Moved with the buttons only, so a swipe can't skip a step
                  // the screen reader hasn't announced.
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    _WelcomeStep(),
                    _IncomeStep(),
                    _BudgetStep(),
                    _GroupStep(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
                // Side by side when they fit; stacked, Next on top, when not.
                child: OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.end,
                  overflowDirection: VerticalDirection.up,
                  overflowSpacing: 8,
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: () => _goTo(_step - 1),
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox.shrink(),
                    FilledButton(
                      onPressed: _isLast ? _finish : () => _goTo(_step + 1),
                      child: Text(switch (_step) {
                        0 => 'Get started',
                        _ when _isLast => 'Done',
                        _ => 'Next',
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A step's layout: an icon, a title, a short explanation and the step's
/// own content, scrollable for large text.
class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.icon,
    required this.title,
    required this.body,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String text) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(text),
    );
    return _StepPage(
      icon: Icons.balance,
      title: 'Welcome to Mizan',
      body:
          'A minute of setup: your income, a budget, and a group if you '
          'share costs. Skip anything; you can change it all later.',
      children: [
        point(Icons.cloud_off_outlined, 'Log what you spend, even offline.'),
        point(
          Icons.trending_down,
          'See when your money will run out, before it does.',
        ),
        point(Icons.groups_outlined, 'Split rent and groceries with friends.'),
      ],
    );
  }
}

class _IncomeStep extends ConsumerWidget {
  const _IncomeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StepPage(
      icon: Icons.payments_outlined,
      title: 'Your income',
      body:
          'A grant, a job, family support… Mizan uses it to work out what '
          'you can spend each month.',
      children: [
        ref
            .watch(incomeSourcesProvider)
            .when(
              data: (sources) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final source in sources)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(source.name),
                      subtitle: Text(
                        '${_money.format(source.amount)} · '
                        '${_scheduleText(source.schedule)}',
                      ),
                      onTap: () => showIncomeSheet(context, source: source),
                    ),
                  const SizedBox(height: 8),
                  sources.isEmpty
                      ? FilledButton.tonalIcon(
                          onPressed: () => showIncomeSheet(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add income'),
                        )
                      : TextButton.icon(
                          onPressed: () => showIncomeSheet(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add another'),
                        ),
                ],
              ),
              error: (error, _) => _StepError(
                message: failureMessage(error),
                onRetry: () => ref.invalidate(incomeSourcesProvider),
              ),
              loading: () => const LinearProgressIndicator(),
            ),
      ],
    );
  }

  static String _scheduleText(IncomeSchedule schedule) => switch (schedule) {
    MonthlyIncome(:final dayOfMonth) => 'monthly, on day $dayOfMonth',
    OneOffIncome() => 'once',
    IrregularIncome() => 'about this much a month',
  };
}

class _BudgetStep extends ConsumerWidget {
  const _BudgetStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = YearMonth.of(ref.watch(clockProvider).now());
    return _StepPage(
      icon: Icons.savings_outlined,
      title: 'A monthly budget',
      body:
          'The most you want to spend in a month. Mizan warns you when you '
          'reach 80% of it, and uses it to forecast until it knows your '
          'habits.',
      children: [
        ref
            .watch(budgetsProvider)
            .when(
              data: (budgets) {
                final limit = ComputeBudgetOverview.budgetFor(
                  month,
                  budgets,
                )?.totalLimit;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (limit != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text('${_money.format(limit)} a month'),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => showBudgetLimitSheet(
                        context,
                        month: month,
                        current: limit,
                      ),
                      icon: Icon(limit == null ? Icons.add : Icons.edit),
                      label: Text(
                        limit == null ? 'Set a budget' : 'Change budget',
                      ),
                    ),
                  ],
                );
              },
              error: (error, _) => _StepError(
                message: failureMessage(error),
                onRetry: () => ref.invalidate(budgetsProvider),
              ),
              loading: () => const LinearProgressIndicator(),
            ),
      ],
    );
  }
}

class _GroupStep extends ConsumerWidget {
  const _GroupStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(accountProvider).value != null;
    return _StepPage(
      icon: Icons.groups_outlined,
      title: 'Share costs? (optional)',
      body: signedIn
          ? 'Split rent, groceries or a trip and see who owes whom. Create a '
                'group, or join one with an invite link.'
          : 'Split rent, groceries or a trip and see who owes whom. Groups '
                'sync through an account, so sign in first. Everything else '
                'works without one.',
      children: [
        if (signedIn)
          FilledButton.tonalIcon(
            // Setup is done at this point: finish it and open the tab.
            onPressed: () async {
              await ref.read(onboardingControllerProvider.notifier).finish();
              if (context.mounted) context.go(AppRoutes.groups);
            },
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Open groups'),
          )
        else
          FilledButton.tonalIcon(
            onPressed: () => context.push(AppRoutes.login),
            icon: const Icon(Icons.login),
            label: const Text('Sign in'),
          ),
        const SizedBox(height: 16),
        Text(
          'You can do this later from Groups on the home screen.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _StepError extends StatelessWidget {
  const _StepError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
