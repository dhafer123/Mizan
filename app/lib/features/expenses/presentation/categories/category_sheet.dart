import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../app/di/expenses_providers.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/category.dart';
import '../../domain/usecases/validate_category.dart';
import '../../domain/value_objects/category_error.dart';
import '../../domain/value_objects/category_failure.dart';
import '../shared/category_icon.dart';

/// Opens the new-category sheet, or the edit sheet for [category].
/// Completes with true once it is saved.
Future<bool?> showCategorySheet(BuildContext context, {Category? category}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CategorySheet(category: category),
    );

/// The create / edit form. It only parses the limit text; every other rule
/// is the domain's (`ValidateCategory`), and its failures show on their
/// fields.
class CategorySheet extends ConsumerStatefulWidget {
  const CategorySheet({this.category, super.key});

  /// The category to edit; null to create one.
  final Category? category;

  @override
  ConsumerState<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<CategorySheet> {
  late final TextEditingController _name;
  late final TextEditingController _limit;
  late String _icon;

  String? _nameError;
  String? _iconError;
  String? _limitError;
  String? _saveError;
  var _saving = false;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _name = TextEditingController(text: category?.name ?? '');
    final limit = category?.monthlyLimit;
    _limit = TextEditingController(
      text: limit == null
          ? ''
          : const MoneyFormatter().format(limit, withSymbol: false),
    );
    _icon = category?.icon ?? 'other';
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  Currency get _currency =>
      widget.category?.monthlyLimit?.currency ?? ref.read(appCurrencyProvider);

  Future<void> _save() async {
    setState(() {
      _nameError = _iconError = _limitError = _saveError = null;
    });

    Money? limit;
    if (_limit.text.trim().isNotEmpty) {
      final parsed = const MoneyParser().parse(
        _limit.text,
        currency: _currency,
      );
      if (parsed case Err(:final failure)) {
        setState(() => _limitError = failure.message);
        return;
      }
      limit = parsed.valueOrNull;
    }

    setState(() => _saving = true);
    final original = widget.category;
    final result = original == null
        ? await ref.read(createCategoryProvider)(
            name: _name.text,
            icon: _icon,
            monthlyLimit: limit,
          )
        : await ref.read(editCategoryProvider)(
            original.copyWith(
              name: _name.text,
              icon: _icon,
              monthlyLimit: limit,
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

  void _showFailure(CategoryFailure failure) {
    final message = failure.message;
    switch (failure.error) {
      case CategoryError.nameEmpty ||
          CategoryError.nameTooLong ||
          CategoryError.nameTaken:
        _nameError = message;
      case CategoryError.noIcon:
        _iconError = message;
      case CategoryError.limitNotPositive:
        _limitError = message;
      case CategoryError.lastActive ||
          CategoryError.notFound ||
          CategoryError.storage:
        _saveError = message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );
    final Currency currency =
        widget.category?.monthlyLimit?.currency ??
        ref.watch(appCurrencyProvider);

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
              _isEdit ? 'Edit category' : 'New category',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !_isEdit,
              maxLength: ValidateCategory.maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Icon', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in categoryIconKeys)
                  IconButton(
                    key: ValueKey('icon-$key'),
                    isSelected: key == _icon,
                    onPressed: () => setState(() {
                      _icon = key;
                      _iconError = null;
                    }),
                    tooltip: key,
                    style: IconButton.styleFrom(
                      backgroundColor: key == _icon
                          ? theme.colorScheme.secondaryContainer
                          : null,
                    ),
                    icon: Icon(categoryIcon(key)),
                  ),
              ],
            ),
            if (_iconError case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error, style: errorStyle),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _limit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (_limitError != null) setState(() => _limitError = null);
              },
              decoration: InputDecoration(
                labelText: 'Monthly limit (optional)',
                helperText: 'Leave empty for no limit.',
                suffixText: currency.symbol,
                errorText: _limitError,
                border: const OutlineInputBorder(),
              ),
            ),
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
          ],
        ),
      ),
    );
  }
}
