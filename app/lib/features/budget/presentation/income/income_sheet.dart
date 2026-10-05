import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/budget_providers.dart';
import '../../../../app/di/core_providers.dart';
import '../../../../core/clock/calendar_day.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/income_source.dart';
import '../../domain/usecases/validate_income_source.dart';
import '../../domain/value_objects/budget_error.dart';
import '../../domain/value_objects/budget_failure.dart';
import '../../domain/value_objects/income_schedule.dart';

/// Opens the add sheet, or the edit sheet for [source]. Completes with true
/// once it is saved or deleted.
Future<bool?> showIncomeSheet(BuildContext context, {IncomeSource? source}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => IncomeSheet(source: source),
    );

enum _Kind { monthly, oneOff, irregular }

/// The add / edit form for an income source. It only parses the amount and
/// day text; every other rule is the domain's (`ValidateIncomeSource`).
class IncomeSheet extends ConsumerStatefulWidget {
  const IncomeSheet({this.source, super.key});

  /// The source to edit; null to add one.
  final IncomeSource? source;

  @override
  ConsumerState<IncomeSheet> createState() => _IncomeSheetState();
}

class _IncomeSheetState extends ConsumerState<IncomeSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _day;
  late _Kind _kind;
  late DateTime _date;

  String? _nameError;
  String? _amountError;
  String? _dayError;
  String? _saveError;
  var _saving = false;

  bool get _isEdit => widget.source != null;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _name = TextEditingController(text: source?.name ?? '');
    _amount = TextEditingController(
      text: source == null
          ? ''
          : const MoneyFormatter().format(source.amount, withSymbol: false),
    );
    final schedule = source?.schedule;
    _kind = switch (schedule) {
      OneOffIncome() => _Kind.oneOff,
      IrregularIncome() => _Kind.irregular,
      _ => _Kind.monthly,
    };
    _day = TextEditingController(
      text: schedule is MonthlyIncome ? '${schedule.dayOfMonth}' : '',
    );
    _date = schedule is OneOffIncome
        ? schedule.date
        : ref.read(clockProvider).now().calendarDay;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  Currency get _currency =>
      widget.source?.amount.currency ?? ref.read(appCurrencyProvider);

  Future<void> _save() async {
    setState(() {
      _nameError = _amountError = _dayError = _saveError = null;
    });

    final parsed = const MoneyParser().parse(_amount.text, currency: _currency);
    if (parsed case Err(:final failure)) {
      setState(() => _amountError = failure.message);
      return;
    }
    final amount = parsed.valueOrNull!;
    final schedule = switch (_kind) {
      // An unreadable day goes to the domain as 0, which it rejects.
      _Kind.monthly => IncomeSchedule.monthly(
        dayOfMonth: int.tryParse(_day.text.trim()) ?? 0,
      ),
      _Kind.oneOff => IncomeSchedule.oneOff(date: _date),
      _Kind.irregular => const IncomeSchedule.irregular(),
    };

    setState(() => _saving = true);
    final original = widget.source;
    final result = original == null
        ? await ref.read(addIncomeSourceProvider)(
            name: _name.text,
            amount: amount,
            schedule: schedule,
          )
        : await ref.read(editIncomeSourceProvider)(
            original.copyWith(
              name: _name.text,
              amount: amount,
              schedule: schedule,
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

  void _showFailure(BudgetFailure failure) {
    final message = failure.message;
    switch (failure.error) {
      case BudgetError.nameEmpty || BudgetError.nameTooLong:
        _nameError = message;
      case BudgetError.amountNotPositive:
        _amountError = message;
      case BudgetError.invalidDay:
        _dayError = message;
      case BudgetError.limitNotPositive ||
          BudgetError.notFound ||
          BudgetError.storage:
        _saveError = message;
    }
  }

  Future<void> _delete() async {
    final source = widget.source!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${source.name}?'),
        content: const Text('It will no longer count towards your income.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final result = await ref.read(deleteIncomeSourceProvider)(source.id);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _saving = false;
          _saveError = failure.message;
        });
    }
  }

  Future<void> _pickDate() async {
    DateTime local(DateTime day) => DateTime(day.year, day.month, day.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: local(_date),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked.calendarDay);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

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
            Text(
              _isEdit ? 'Edit income' : 'Add income',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !_isEdit,
              maxLength: ValidateIncomeSource.maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Grant, job, family…',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: _currency.symbol,
                errorText: _amountError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_Kind>(
              segments: const [
                ButtonSegment(value: _Kind.monthly, label: Text('Monthly')),
                ButtonSegment(value: _Kind.oneOff, label: Text('One-off')),
                ButtonSegment(value: _Kind.irregular, label: Text('Irregular')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (kinds) => setState(() {
                _kind = kinds.single;
                _dayError = null;
              }),
            ),
            const SizedBox(height: 16),
            switch (_kind) {
              _Kind.monthly => TextField(
                controller: _day,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_dayError != null) setState(() => _dayError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Day of the month',
                  helperText: 'In shorter months, it counts on the last day.',
                  errorText: _dayError,
                  border: const OutlineInputBorder(),
                ),
              ),
              _Kind.oneOff => InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    localizations.formatMediumDate(
                      DateTime(_date.year, _date.month, _date.day),
                    ),
                  ),
                ),
              ),
              _Kind.irregular => Text(
                'Enter about how much you get in a typical month. It counts '
                'towards every month.',
                style: theme.textTheme.bodyMedium,
              ),
            },
            const SizedBox(height: 16),
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
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _delete,
                child: const Text('Delete'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
