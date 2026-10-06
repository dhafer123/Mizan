import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/groups_providers.dart';
import '../../../../app/di/sync_providers.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/result/result.dart';
import '../../../auth/presentation/account_provider.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/value_objects/invite_link.dart';
import '../../domain/value_objects/invite_preview.dart';
import '../shared/group_data_providers.dart';
import '../shared/load_error.dart';

/// Join a group with an invite: opened from an invite link (with [token]),
/// or with a pasted link. Shows where the invite leads before joining.
class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({this.token, super.key});

  /// From a deep link; null to paste one.
  final String? token;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  late final _link = TextEditingController(
    text: widget.token == null ? '' : InviteLink.forToken(widget.token!),
  );

  /// The link being previewed; null until one is submitted.
  late String? _submitted = widget.token == null ? null : _link.text;
  var _joining = false;
  String? _joinError;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _lookUp() => setState(() {
    _submitted = _link.text.trim();
    _joinError = null;
  });

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _joinError = null;
    });
    final result = await ref.read(joinGroupProvider)(_submitted!);
    if (!mounted) return;
    switch (result) {
      case Ok(value: final groupId):
        // The group's rows come with the next sync.
        ref.read(syncSchedulerProvider).syncNow();
        context.pushReplacement(AppRoutes.group(groupId));
      case Err(:final failure):
        setState(() {
          _joining = false;
          _joinError = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Join a group')),
      body: switch (account) {
        AsyncData(value: null) => _SignInFirst(),
        AsyncData() => _body(context),
        AsyncError(:final error) => LoadError(
          message: failureMessage(error),
          onRetry: () => ref.invalidate(accountProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context) {
    final submitted = _submitted;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Paste the invite link someone sent you, or scan their QR code '
          'with your camera.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _link,
          decoration: const InputDecoration(labelText: 'Invite link'),
          onSubmitted: (_) => _lookUp(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: _joining ? null : _lookUp,
            child: const Text('Look up'),
          ),
        ),
        const SizedBox(height: 16),
        if (submitted != null)
          ref
              .watch(invitePreviewProvider(submitted))
              .when(
                data: (preview) => _Preview(
                  preview: preview,
                  joining: _joining,
                  error: _joinError,
                  onJoin: _join,
                ),
                error: (error, _) => LoadError(
                  message: failureMessage(error),
                  onRetry: () =>
                      ref.invalidate(invitePreviewProvider(submitted)),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.preview,
    required this.joining,
    required this.error,
    required this.onJoin,
  });

  final InvitePreview preview;
  final bool joining;
  final String? error;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = this.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(preview.groupName, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Invited by ${preview.invitedBy}'),
            if (preview.memberName case final name?) ...[
              const SizedBox(height: 8),
              Text(
                'You join as $name, with the expenses already recorded '
                'for them.',
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: joining ? null : onJoin,
              child: Text(joining ? 'Joining…' : 'Join'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInFirst extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Groups sync through your account. Sign in, then open the '
              'invite again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push(AppRoutes.login),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
