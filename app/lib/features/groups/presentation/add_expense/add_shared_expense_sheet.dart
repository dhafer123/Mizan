import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/groups_providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/result/result.dart';
import '../../../auth/presentation/account_provider.dart';
import '../../../expenses/presentation/shared/categories_provider.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';
import '../../domain/value_objects/split.dart';
import '../../domain/value_objects/split_type.dart';
import 'percent_input.dart';

/// Opens the add-expense sheet for [group]. Completes with true once saved.
Future<bool?> showAddSharedExpenseSheet(
  BuildContext context, {
  required Group group,
  required List<Member> members,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => AddSharedExpenseSheet(group: group, members: members),
);

/// Amount, payer, how to split and between whom, and a category. Every
/// member's share is previewed live (`ComputeShares`, the same rule the
/// saved expense uses), and Save stays disabled until the split works out:
/// shares adding up to the amount.
class AddSharedExpenseSheet extends ConsumerStatefulWidget {
  const AddSharedExpenseSheet({
    required this.group,
    required this.members,
    super.key,
  });

  final Group group;
  final List<Member> members;

  @override
  ConsumerState<AddSharedExpenseSheet> createState() =>
      _AddSharedExpenseSheetState();
}

class _AddSharedExpenseSheetState extends ConsumerState<AddSharedExpenseSheet> {
  final _amount = TextEditingController();

  /// Per member: an exact amount, a percentage or a weight, by split type.
  late final Map<String, TextEditingController> _values = {
    for (final m in widget.members) m.id: TextEditingController(),
  };
  late final Set<String> _included = {for (final m in widget.members) m.id};
  late String _payerId = _defaultPayer();
  var _type = SplitType.equal;
  String? _categoryId;
  String? _saveError;
  var _saving = false;

  String _defaultPayer() {
    final me = ref.read(accountProvider).value?.id;
    return widget.members
            .where((m) => m.userId == me && me != null)
            .firstOrNull
            ?.id ??
        widget.members.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() => _saveError = null);

  Money? get _parsedAmount => _amount.text.trim().isEmpty
      ? null
      : const MoneyParser()
            .parse(_amount.text, currency: widget.group.currency)
            .valueOrNull;

  /// The split as entered, or why it can't be built yet.
  ({Split? split, String? problem}) _split() {
    final ids = widget.members.map((m) => m.id).where(_included.contains);
    String text(String id) => _values[id]!.text.trim();
    switch (_type) {
      case SplitType.equal:
        return (split: Split.equal(ids.toSet()), problem: null);
      case SplitType.exact:
        final amounts = <String, Money>{};
        for (final id in ids) {
          final parsed = text(id).isEmpty
              ? Money.zero(widget.group.currency)
              : const MoneyParser()
                    .parse(text(id), currency: widget.group.currency)
                    .valueOrNull;
          if (parsed == null) {
            return (split: null, problem: 'Check the amounts.');
          }
          amounts[id] = parsed;
        }
        return (split: Split.exact(amounts), problem: null);
      case SplitType.percentage:
        final points = <String, int>{};
        for (final id in ids) {
          final parsed = text(id).isEmpty ? 0 : parseBasisPoints(text(id));
          if (parsed == null) {
            return (split: null, problem: 'Use percentages like 33.33.');
          }
          points[id] = parsed;
        }
        return (split: Split.percentage(points), problem: null);
      case SplitType.shares:
        final weights = <String, int>{};
        for (final id in ids) {
          final parsed = text(id).isEmpty ? 0 : int.tryParse(text(id));
          if (parsed == null || parsed < 0) {
            return (split: null, problem: 'Shares are whole numbers.');
          }
          weights[id] = parsed;
        }
        return (split: Split.shares(weights), problem: null);
    }
  }

  /// Each member's share, or the reason there is none yet.
  ({Map<String, Money>? shares, String? problem}) _preview() {
    final amount = _parsedAmount;
    if (amount == null) {
      return (
        shares: null,
        problem: _amount.text.trim().isEmpty ? null : 'Check the amount.',
      );
    }
    final (:split, :problem) = _split();
    if (split == null) return (shares: null, problem: problem);
    final result = ref.read(computeSharesProvider)(
      amount,
      split,
      groupMemberIds: {for (final m in widget.members) m.id},
    );
    return switch (result) {
      Ok(:final value) => (shares: value, problem: null),
      Err(:final failure) => (shares: null, problem: failure.message),
    };
  }

  Future<void> _save(Split split) async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final result = await ref.read(addSharedExpenseProvider)(
      groupId: widget.group.id,
      payerId: _payerId,
      amount: _parsedAmount!,
      split: split,
      categoryId: _categoryId,
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview();
    final shares = preview.shares;
    final split = shares == null ? null : _split().split;
    const formatter = MoneyFormatter();
    final categories = ref.watch(categoriesProvider).value ?? const [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text('Add an expense', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('amount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: widget.group.currency.symbol,
            ),
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('payer'),
            initialValue: _payerId,
            decoration: const InputDecoration(labelText: 'Paid by'),
            items: [
              for (final m in widget.members)
                DropdownMenuItem(value: m.id, child: Text(m.displayName)),
            ],
            onChanged: (id) => setState(() => _payerId = id ?? _payerId),
          ),
          const SizedBox(height: 16),
          SegmentedButton<SplitType>(
            segments: const [
              ButtonSegment(value: SplitType.equal, label: Text('Equal')),
              ButtonSegment(value: SplitType.exact, label: Text('Exact')),
              ButtonSegment(value: SplitType.percentage, label: Text('%')),
              ButtonSegment(value: SplitType.shares, label: Text('Shares')),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _type = s.single;
              for (final c in _values.values) {
                c.clear();
              }
            }),
          ),
          const SizedBox(height: 8),
          for (final m in widget.members)
            _MemberRow(
              member: m,
              type: _type,
              included: _included.contains(m.id),
              controller: _values[m.id]!,
              share: shares?[m.id],
              onIncluded: (on) => setState(() {
                on ? _included.add(m.id) : _included.remove(m.id);
              }),
              onChanged: _changed,
            ),
          if (preview.problem case final problem?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                problem,
                key: const Key('split-problem'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (categories.where((c) => !c.archived).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Category', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories.where((c) => !c.archived))
                  ChoiceChip(
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (on) =>
                        setState(() => _categoryId = on ? c.id : null),
                  ),
              ],
            ),
          ],
          if (_saveError case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                error,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save'),
            onPressed: split == null || _saving ? null : () => _save(split),
            child: Text(
              shares == null
                  ? 'Save'
                  : 'Save ${formatter.format(_parsedAmount!)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.type,
    required this.included,
    required this.controller,
    required this.share,
    required this.onIncluded,
    required this.onChanged,
  });

  final Member member;
  final SplitType type;
  final bool included;
  final TextEditingController controller;
  final Money? share;
  final ValueChanged<bool> onIncluded;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final share = this.share;
    final label = switch (type) {
      SplitType.equal => null,
      SplitType.exact => 'Amount',
      SplitType.percentage => '%',
      SplitType.shares => 'Shares',
    };
    return Row(
      children: [
        Checkbox(
          key: Key('include-${member.id}'),
          value: included,
          onChanged: (on) => onIncluded(on ?? false),
        ),
        Expanded(child: Text(member.displayName)),
        if (label != null && included)
          SizedBox(
            width: 88,
            child: TextField(
              key: Key('value-${member.id}'),
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: label, isDense: true),
              onChanged: (_) => onChanged(),
            ),
          ),
        SizedBox(
          width: 96,
          child: Text(
            included && share != null
                ? const MoneyFormatter().format(share)
                : '',
            key: Key('share-${member.id}'),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
