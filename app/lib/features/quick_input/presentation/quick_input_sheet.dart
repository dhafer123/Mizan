import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Say or type expenses ("coffee 3.5 and taxi 8"), then check and save
/// them. Nothing is saved before the confirmation step.
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
          ),
          QuickTyping() => _Typing(
            controller: _text,
            onSubmit: _submit,
            onListen: _controller.listen,
          ),
          QuickReading(:final text) => _Reading(text: text),
          QuickConfirming(:final parse, :final fromVoice, :final sinceSpeech) =>
            ConfirmItemsView(
              key: ObjectKey(parse),
              parse: parse,
              fromVoice: fromVoice,
              sinceSpeech: sinceSpeech,
              onSaved: (count) => Navigator.of(context).pop(count),
              onRetry: fromVoice ? _controller.listen : _controller.type,
            ),
          QuickFailed(:final message) => _Failed(
            message: message,
            onRetry: _controller.listen,
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
  });

  final String heard;
  final VoidCallback onDone;
  final VoidCallback onType;

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
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onListen;

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
        Text('“$text”', textAlign: TextAlign.center),
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
    required this.onRetry,
    required this.onType,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mic_off_outlined, size: 48),
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
