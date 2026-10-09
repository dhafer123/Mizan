import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/beta_providers.dart';
import '../../../core/result/result.dart';
import '../domain/value_objects/feedback_message.dart';

/// The beta's feedback form: a message, and an optional contact for a
/// reply. Sent anonymously; on a failure the text stays so it can be sent
/// again.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _message = TextEditingController();
  final _contact = TextEditingController();
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref.read(sendFeedbackProvider)(
      message: _message.text,
      contact: _contact.text,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Thanks! Your feedback was sent.')),
          );
        Navigator.of(context).pop();
      case Err(:final failure):
        setState(() {
          _sending = false;
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = !_sending && _message.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const Text(
            "Mizan is in beta. Tell us what's broken, confusing or missing. "
            'Your message is sent without your account.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _message,
            enabled: !_sending,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            maxLength: FeedbackMessage.maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Your feedback',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contact,
            enabled: !_sending,
            maxLength: FeedbackMessage.maxContactLength,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email or phone (optional)',
              helperText: 'Only if you want a reply.',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canSend ? _send : null,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_sending ? 'Sending…' : 'Send'),
          ),
        ],
      ),
    );
  }
}
