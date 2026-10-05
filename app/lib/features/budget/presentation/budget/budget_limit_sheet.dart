import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/budget_providers.dart';
import '../../../../app/di/core_providers.dart';
import '../../../../core/clock/year_month.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/result/result.dart';

/// Opens the sheet that sets the overall budget from [month] on.
/// Completes with true once it is saved.
Future<bool?> showBudgetLimitSheet(
  BuildContext context, {
  required YearMonth month,
  required Money? current,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => BudgetLimitSheet(month: month, current: current),
);

/// Sets or removes the overall monthly limit. It applies from [month] on;
/// earlier months keep theirs.
class BudgetLimitSheet extends ConsumerStatefulWidget {
  const BudgetLimitSheet({
    required this.month,
    required this.current,
    super.key,
  });

  final YearMonth month;

  /// The limit in force now, if any.
  final Money? current;

  @override
  ConsumerState<BudgetLimitSheet> createState() => _BudgetLimitSheetState();
}

class _BudgetLimitSheetState extends ConsumerState<BudgetLimitSheet> {
  late final TextEditingController _limit;
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _limit = TextEditingController(
      text: current == null
          ? ''
          : const MoneyFormatter().format(current, withSymbol: false),
    );
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Currency get _currency =>
      widget.current?.currency ?? ref.read(appCurrencyProvider);

  Future<void> _save({required bool remove}) async {
    setState(() => _error = null);
    Money? limit;
    if (!remove) {
      final parsed = const MoneyParser().parse(
        _limit.text,
        currency: _currency,
      );
      if (parsed case Err(:final failure)) {
        setState(() => _error = failure.message);
        return;
      }
      limit = parsed.valueOrNull;
    }

    setState(() => _saving = true);
    final result = await ref.read(setMonthlyBudgetProvider)(
      widget.month,
      totalLimit: limit,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _saving = false;
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = MaterialLocalizations.of(
      context,
    ).formatMonthYear(DateTime(widget.month.year, widget.month.month));

    return Padding(
      // Stay above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        // Clear of the system navigation bar too (edge-to-edge Android).
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Monthly budget', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'From $monthName on, until you change it.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _limit,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'Spend at most',
                suffixText: _currency.symbol,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : () => _save(remove: false),
              child: const Text('Save'),
            ),
            if (widget.current != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : () => _save(remove: true),
                child: const Text('Remove budget'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
