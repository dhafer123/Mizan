import 'package:flutter/material.dart';

import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';

/// A one-field sheet: a name, saved by [onSave]. Its failure shows under
/// the field. Completes with true once saved.
Future<bool?> showNameSheet(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  required Future<Result<Object?, Failure>> Function(String name) onSave,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      _NameSheet(title: title, label: label, action: action, onSave: onSave),
);

class _NameSheet extends StatefulWidget {
  const _NameSheet({
    required this.title,
    required this.label,
    required this.action,
    required this.onSave,
  });

  final String title;
  final String label;
  final String action;
  final Future<Result<Object?, Failure>> Function(String name) onSave;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  final _name = TextEditingController();
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.onSave(_name.text);
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
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _saving ? null : _save(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.action),
          ),
        ],
      ),
    );
  }
}
