import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../app/di/expenses_providers.dart';
import '../../../../core/clock/calendar_day.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/expense.dart';
import '../../domain/usecases/validate_expense.dart';
import '../../domain/value_objects/expense_error.dart';
import '../../domain/value_objects/expense_failure.dart';
import '../shared/categories_provider.dart';
import '../shared/category_icon.dart';
import '../shared/failure_message.dart';

/// Opens the add sheet, or the edit sheet for [expense]. Completes with true
/// once the expense is saved.
Future<bool?> showExpenseSheet(BuildContext context, {Expense? expense}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ExpenseSheet(expense: expense),
    );

/// The add / edit form. It only parses the amount text; every other rule is
/// the domain's (`ValidateExpense`), and its failures show on their fields.
class ExpenseSheet extends ConsumerStatefulWidget {
  const ExpenseSheet({this.expense, super.key});

  /// The expense to edit; null to add a new one.
  final Expense? expense;

  @override
  ConsumerState<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<ExpenseSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  String? _categoryId;

  String? _amountError;
  String? _categoryError;
  String? _noteError;
  String? _dateError;
  String? _saveError;
  var _saving = false;

  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amount = TextEditingController(
      text: expense == null
          ? ''
          : const MoneyFormatter().format(expense.amount, withSymbol: false),
    );
    _note = TextEditingController(text: expense?.note ?? '');
    _date = expense?.date ?? ref.read(clockProvider).now().calendarDay;
    _categoryId = expense?.categoryId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final Currency currency =
        widget.expense?.amount.currency ?? ref.read(appCurrencyProvider);
    setState(() {
      _amountError = _categoryError = _noteError = _dateError = null;
      _saveError = null;
    });

    final parsed = const MoneyParser().parse(_amount.text, currency: currency);
    if (parsed case Err(:final failure)) {
      setState(() => _amountError = failure.message);
      return;
    }
    final amount = parsed.valueOrNull!;

    setState(() => _saving = true);
    final original = widget.expense;
    final result = original == null
        ? await ref.read(addExpenseProvider)(
            amount: amount,
            categoryId: _categoryId ?? '',
            date: _date,
            note: _note.text,
          )
        : await ref.read(editExpenseProvider)(
            original.copyWith(
              amount: amount,
              categoryId: _categoryId ?? '',
              date: _date,
              note: _note.text,
            ),
          );
    if (!mounted) return;

    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _saving = false;
          _showFailure(failure);
        });
    }
  }

  void _showFailure(ExpenseFailure failure) {
    final message = failure.message;
    switch (failure.error) {
      case ExpenseError.amountNotPositive:
        _amountError = message;
      case ExpenseError.noCategory:
        _categoryError = message;
      case ExpenseError.noteTooLong:
        _noteError = message;
      case ExpenseError.dateInFuture:
        _dateError = message;
      case ExpenseError.notFound || ExpenseError.storage:
        _saveError = message;
    }
  }

  Future<void> _pickDate() async {
    final today = ref.read(clockProvider).now().calendarDay;
    DateTime local(DateTime day) => DateTime(day.year, day.month, day.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: local(_date.isAfter(today) ? today : _date),
      firstDate: DateTime(2000),
      lastDate: local(today),
    );
    if (picked != null) {
      setState(() {
        _date = picked.calendarDay;
        _dateError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Currency currency =
        widget.expense?.amount.currency ?? ref.watch(appCurrencyProvider);
    final localizations = MaterialLocalizations.of(context);

    return Padding(
      // Stay above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEdit ? 'Edit expense' : 'Add expense',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: !_isEdit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: currency.symbol,
                errorText: _amountError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Category', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _CategoryPicker(
              selectedId: _categoryId,
              onSelected: (id) => setState(() {
                _categoryId = id;
                _categoryError = null;
              }),
            ),
            if (_categoryError case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date',
                  errorText: _dateError,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  localizations.formatMediumDate(
                    DateTime(_date.year, _date.month, _date.day),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: ValidateExpense.maxNoteLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                errorText: _noteError,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_saveError case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chips for the active categories, plus the selected one if it has since
/// been archived (so editing an old expense doesn't silently drop it).
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({required this.selectedId, required this.onSelected});

  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(categoriesProvider)
        .when(
          data: (categories) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final Category category in categories)
                if (!category.archived || category.id == selectedId)
                  ChoiceChip(
                    avatar: Icon(categoryIcon(category.icon)),
                    label: Text(category.name),
                    selected: category.id == selectedId,
                    onSelected: (_) => onSelected(category.id),
                  ),
            ],
          ),
          error: (error, _) => Text(failureMessage(error)),
          loading: () => const LinearProgressIndicator(),
        );
  }
}
