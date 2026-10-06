import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/groups_providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/money/money_parser.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';

/// Records a payment between two members: a suggested transfer (prefilled,
/// the amount can be lowered for a partial payment) or any other one.
/// Completes with true once saved.
Future<bool?> showRecordPaymentSheet(
  BuildContext context, {
  required Group group,
  required List<Member> members,
  String? fromMemberId,
  String? toMemberId,
  Money? amount,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => RecordPaymentSheet(
    group: group,
    members: members,
    fromMemberId: fromMemberId,
    toMemberId: toMemberId,
    amount: amount,
  ),
);

class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({
    required this.group,
    required this.members,
    this.fromMemberId,
    this.toMemberId,
    this.amount,
    super.key,
  });

  final Group group;
  final List<Member> members;
  final String? fromMemberId;
  final String? toMemberId;
  final Money? amount;

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  late String _from = widget.fromMemberId ?? widget.members.first.id;
  late String _to =
      widget.toMemberId ?? widget.members.firstWhere((m) => m.id != _from).id;
  late final _amount = TextEditingController(
    text: widget.amount == null
        ? ''
        : const MoneyFormatter().format(widget.amount!, withSymbol: false),
  );
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = const MoneyParser().parse(
      _amount.text,
      currency: widget.group.currency,
    );
    if (parsed case Err(:final failure)) {
      setState(() => _error = failure.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref.read(recordSettlementProvider)(
      groupId: widget.group.id,
      fromMemberId: _from,
      toMemberId: _to,
      amount: parsed.valueOrNull!,
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
    DropdownMenuItem<String> item(Member m) =>
        DropdownMenuItem(value: m.id, child: Text(m.displayName));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Record a payment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('payment-from'),
            initialValue: _from,
            decoration: const InputDecoration(labelText: 'Who paid'),
            items: [for (final m in widget.members) item(m)],
            onChanged: (id) => setState(() => _from = id ?? _from),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('payment-to'),
            initialValue: _to,
            decoration: const InputDecoration(labelText: 'To whom'),
            items: [for (final m in widget.members) item(m)],
            onChanged: (id) => setState(() => _to = id ?? _to),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('payment-amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: widget.group.currency.symbol,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('payment-save'),
            onPressed: _saving ? null : _save,
            child: const Text('Record payment'),
          ),
        ],
      ),
    );
  }
}
