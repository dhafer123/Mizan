import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/core_providers.dart';
import '../../../app/di/expenses_providers.dart';
import '../../../app/di/quick_input_providers.dart';
import '../../../core/clock/calendar_day.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/money/money_parser.dart';
import '../../../core/result/result.dart';
import '../../expenses/domain/entities/category.dart';
import '../../expenses/domain/usecases/add_expenses.dart';
import '../../expenses/domain/usecases/validate_expense.dart';
import '../../expenses/domain/value_objects/expense_item_failure.dart';
import '../../expenses/domain/value_objects/expense_source.dart';
import '../../expenses/presentation/shared/categories_provider.dart';
import '../../expenses/presentation/shared/failure_message.dart';
import '../domain/usecases/parse_expense_text.dart';
import '../domain/value_objects/category_memory.dart';
import '../domain/value_objects/category_source.dart';
import '../domain/value_objects/parse_method.dart';
import '../domain/value_objects/quick_input_error.dart';
import '../domain/value_objects/quick_parse.dart';
import 'category_memory_provider.dart';
import 'quick_input_timings.dart';

/// The confirmation step: every item read from the phrase, editable, saved
/// only when the user taps Save (CLAUDE.md rule 7). Unsure items are
/// marked so the eye goes to them. Categories are suggested from the
/// user's past choices, then keywords, then (in the background) the
/// assistant; saving teaches the next suggestion.
class ConfirmItemsView extends ConsumerStatefulWidget {
  const ConfirmItemsView({
    super.key,
    required this.parse,
    required this.source,
    required this.onSaved,
    required this.onRetry,
    this.sinceSpeech,
  });

  final QuickParse parse;

  /// Saved with each expense: voice, typed (manual) or receipt.
  final ExpenseSource source;

  /// Stopped and recorded once the items are on screen.
  final Stopwatch? sinceSpeech;

  /// With the number of expenses saved.
  final ValueChanged<int> onSaved;
  final VoidCallback onRetry;

  @override
  ConsumerState<ConfirmItemsView> createState() => _ConfirmItemsViewState();
}

class _Row {
  _Row({required String label, required String amount, required this.unsure})
    : note = TextEditingController(text: label),
      amount = TextEditingController(text: amount);

  final TextEditingController note;
  final TextEditingController amount;
  final bool unsure;
  String? categoryId;
  var categoryPicked = false;

  /// Where the pre-selected category came from; null once the user picks.
  CategorySource? suggestedBy;
  var askedAssistant = false;
  String? error;

  void dispose() {
    note.dispose();
    amount.dispose();
  }
}

class _ConfirmItemsViewState extends ConsumerState<ConfirmItemsView> {
  late final List<_Row> _rows;
  late DateTime _date;
  var _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _date = widget.parse.date ?? ref.read(clockProvider).now().calendarDay;
    _rows = [
      for (final item in widget.parse.items)
        _Row(
          label: item.label,
          amount: const MoneyFormatter().format(item.amount, withSymbol: false),
          unsure: item.confidence < ParseExpenseText.fallbackBelow,
        ),
    ];
    final stopwatch = widget.sinceSpeech;
    if (stopwatch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        stopwatch.stop();
        if (mounted) {
          ref.read(quickInputTimingsProvider.notifier).add(stopwatch.elapsed);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  /// Fills in a suggested category for rows the user hasn't picked for:
  /// memory or keywords now, else the assistant in the background.
  void _suggest(List<Category> categories, CategoryMemory memory) {
    final suggest = ref.read(suggestCategoryProvider);
    for (final row in _rows) {
      if (row.categoryPicked || row.categoryId != null) continue;
      final suggestion = suggest(
        row.note.text,
        categories: categories,
        memory: memory,
      );
      if (suggestion != null) {
        row
          ..categoryId = suggestion.categoryId
          ..suggestedBy = suggestion.source;
      } else if (!row.askedAssistant) {
        row.askedAssistant = true;
        unawaited(_askAssistant(row, categories));
      }
    }
  }

  Future<void> _askAssistant(_Row row, List<Category> categories) async {
    final suggestion = await ref.read(askLlmCategoryProvider)(
      row.note.text,
      categories: categories,
    );
    if (suggestion == null || !mounted) return;
    if (row.categoryPicked || row.categoryId != null || !_rows.contains(row)) {
      return;
    }
    setState(() {
      row
        ..categoryId = suggestion.categoryId
        ..suggestedBy = suggestion.source;
    });
  }

  Future<void> _save() async {
    final currency = ref.read(appCurrencyProvider);
    var bad = false;
    final expenses = <NewExpense>[];
    setState(() {
      _saveError = null;
      for (final row in _rows) {
        row.error = null;
        final parsed = const MoneyParser().parse(
          row.amount.text,
          currency: currency,
        );
        switch (parsed) {
          case Err(:final failure):
            row.error = failure.message;
            bad = true;
          case Ok(:final value):
            final note = row.note.text.trim();
            expenses.add((
              amount: value,
              categoryId: row.categoryId ?? '',
              date: _date,
              note: note.isEmpty ? null : note,
            ));
        }
      }
    });
    if (bad) return;

    setState(() => _saving = true);
    final result = await ref.read(addExpensesProvider)(
      expenses,
      source: widget.source,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Ok(:final value):
        // The next suggestions learn from what was just saved.
        ref.invalidate(categoryMemoryProvider);
        widget.onSaved(value.length);
      case Err(:final failure):
        setState(() {
          if (failure is ExpenseItemFailure) {
            _rows[failure.index].error = failure.message;
          } else {
            _saveError = failure.message;
          }
        });
    }
  }

  Future<void> _pickDate() async {
    final today = ref.read(clockProvider).now().calendarDay;
    DateTime local(DateTime day) => DateTime(day.year, day.month, day.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: local(_date),
      firstDate: DateTime(2000),
      lastDate: local(today),
    );
    if (picked != null) setState(() => _date = picked.calendarDay);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parse = widget.parse;
    final categories = ref.watch(categoriesProvider);
    final memory = ref.watch(categoryMemoryProvider);
    if ((categories, memory) case (
      AsyncData(value: final all),
      AsyncData(value: final learned),
    )) {
      _suggest(all, learned);
    }

    final note = switch (parse) {
      QuickParse(method: ParseMethod.llm) => 'Read by the on-device assistant.',
      QuickParse(llmFailure: final failure?)
          when _rows.any((r) => r.unsure) &&
              failure.error == QuickInputError.modelNotInstalled =>
        'Not sure about this one. The on-device assistant can help: '
            'get it in Settings.',
      QuickParse(llmFailure: final _?) when _rows.any((r) => r.unsure) =>
        "The assistant couldn't help with this one. Check the items.",
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Check before saving', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '“${parse.text}”',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        if (_rows.isEmpty)
          _NothingFound(
            receipt: widget.source == ExpenseSource.receipt,
            onRetry: widget.onRetry,
          )
        else ...[
          for (final (i, row) in _rows.indexed)
            _ItemCard(
              key: ObjectKey(row),
              row: row,
              categories: categories,
              onCategory: (id) => setState(() {
                row
                  ..categoryId = id
                  ..categoryPicked = true
                  ..suggestedBy = null
                  ..error = null;
              }),
              onRemove: () => setState(() => _rows.removeAt(i).dispose()),
              onEdited: () {
                if (row.error != null) setState(() => row.error = null);
              },
            ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                MaterialLocalizations.of(context).formatMediumDate(
                  DateTime(_date.year, _date.month, _date.day),
                ),
              ),
            ),
          ),
          if (_saveError case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                onPressed: _saving ? null : widget.onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Again'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_rows.length == 1 ? 'Save' : 'Save ${_rows.length}'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.row,
    required this.categories,
    required this.onCategory,
    required this.onRemove,
    required this.onEdited,
  });

  final _Row row;
  final AsyncValue<List<Category>> categories;
  final ValueChanged<String> onCategory;
  final VoidCallback onRemove;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: row.unsure
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.tertiary, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (row.unsure)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text('Check this one', style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: row.amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onEdited(),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      isDense: true,
                      errorText: row.error,
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.note,
                    maxLength: ValidateExpense.maxNoteLength,
                    onChanged: (_) => onEdited(),
                    decoration: const InputDecoration(
                      labelText: 'What',
                      isDense: true,
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: categories.when(
                data: (all) => DropdownButtonFormField<String>(
                  // Rebuilt when a late suggestion (the assistant) arrives.
                  key: ValueKey(row.categoryId),
                  initialValue: row.categoryId,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    helperText: switch (row.suggestedBy) {
                      CategorySource.memory => 'From your past choices',
                      CategorySource.llm => 'Suggested by the assistant',
                      CategorySource.rules || null => null,
                    },
                  ),
                  items: [
                    for (final c in all)
                      if (!c.archived)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (id) {
                    if (id != null) onCategory(id);
                  },
                ),
                error: (error, _) => Text(failureMessage(error)),
                loading: () => const LinearProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.receipt, required this.onRetry});

  final bool receipt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.search_off, size: 48),
        const SizedBox(height: 8),
        Text(
          receipt
              ? 'No total found on this receipt. Try another photo, flat and '
                    'in focus, or type it.'
              : 'No amount found. Say or type what you paid, like '
                    '"coffee 2.5 and taxi 8".',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
