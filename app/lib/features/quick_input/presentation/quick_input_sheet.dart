import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expenses/domain/value_objects/expense_source.dart';
import 'confirm_items_view.dart';
import 'quick_input_controller.dart';
import 'quick_input_state.dart';

/// Opens quick input, listening straight away ([listen]) or for typing.
/// Completes with the number of expenses saved, or null.
Future<int?> showQuickInputSheet(BuildContext context, {bool listen = true}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => QuickInputSheet(listen: listen),
    );

/// Say or type expenses ("coffee 3.5 and taxi 8"), or photograph a receipt,
/// then check and save them. Nothing is saved before the confirmation
/// step.
class QuickInputSheet extends ConsumerStatefulWidget {
  const QuickInputSheet({super.key, this.listen = true});

  final bool listen;

  @override
  ConsumerState<QuickInputSheet> createState() => _QuickInputSheetState();
}

class _QuickInputSheetState extends ConsumerState<QuickInputSheet> {
  final _text = TextEditingController();

  QuickInputController get _controller =>
      ref.read(quickInputControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    if (widget.listen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.listen();
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _scan() => _controller.scanReceipt(fromGallery: false);

  void _submit() {
    if (_text.text.trim().isEmpty) return;
    _controller.submit(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickInputControllerProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: switch (state) {
          QuickListening(:final heard) => _Listening(
            heard: heard,
            onDone: _controller.stop,
            onType: _controller.type,
            onReceipt: _scan,
          ),
          QuickTyping() => _Typing(
            controller: _text,
            onSubmit: _submit,
            onListen: _controller.listen,
            onReceipt: _scan,
            onGallery: () => _controller.scanReceipt(fromGallery: true),
          ),
          QuickReading(:final text) => _Reading(text: '“$text”'),
          QuickScanning() => const _Reading(text: 'Reading the receipt'),
          QuickConfirming(:final parse, :final source, :final sinceSpeech) =>
            ConfirmItemsView(
              key: ObjectKey(parse),
              parse: parse,
              source: source,
              sinceSpeech: sinceSpeech,
              onSaved: (count) => Navigator.of(context).pop(count),
              onRetry: switch (source) {
                ExpenseSource.voice => _controller.listen,
                ExpenseSource.receipt => _scan,
                ExpenseSource.manual => _controller.type,
              },
            ),
          QuickFailed(:final message, :final receipt) => _Failed(
            message: message,
            receipt: receipt,
            onRetry: receipt ? _scan : _controller.listen,
            onType: _controller.type,
          ),
        },
      ),
    );
  }
}

class _Listening extends StatelessWidget {
  const _Listening({
    required this.heard,
    required this.onDone,
    required this.onType,
    required this.onReceipt,
  });

  final String heard;
  final VoidCallback onDone;
  final VoidCallback onType;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Listening…', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Icon(Icons.mic, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          heard.isEmpty
              ? 'Say what you paid, like "coffee 2.5 and taxi 8".'
              : heard,
          textAlign: TextAlign.center,
          style: heard.isEmpty
              ? theme.textTheme.bodyMedium
              : theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onReceipt,
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Scan a receipt',
            ),
            TextButton.icon(
              onPressed: onType,
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Type instead'),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ],
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing({
    required this.controller,
    required this.onSubmit,
    required this.onListen,
    required this.onReceipt,
    required this.onGallery,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onListen;
  final VoidCallback onReceipt;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Quick add', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            hintText: 'coffee 2.5 and taxi 8',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: onListen,
              icon: const Icon(Icons.mic_none),
              tooltip: 'Speak instead',
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onSubmit, child: const Text('Read')),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReceipt,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Scan receipt'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('From photos'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Reading…'),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.receipt,
    required this.onRetry,
    required this.onType,
  });

  final String message;
  final bool receipt;
  final VoidCallback onRetry;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          receipt ? Icons.receipt_long_outlined : Icons.mic_off_outlined,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: onType,
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text('Type instead'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ],
    );
  }
}
