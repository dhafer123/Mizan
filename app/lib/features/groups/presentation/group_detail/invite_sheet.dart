import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/member.dart';
import '../../domain/value_objects/group_invite.dart';
import '../shared/group_data_providers.dart';
import '../shared/load_error.dart';

/// Makes an invite to [group] and shows it as a QR code and a link. With
/// [member] (a placeholder), whoever joins becomes that member.
Future<void> showInviteSheet(
  BuildContext context, {
  required Group group,
  Member? member,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _InviteSheet(group: group, member: member),
);

class _InviteSheet extends ConsumerWidget {
  const _InviteSheet({required this.group, this.member});

  final Group group;
  final Member? member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = inviteProvider(group.id, memberId: member?.id);
    final title = member == null
        ? 'Invite to ${group.name}'
        : 'Invite ${member!.displayName}';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ref
              .watch(provider)
              .when(
                data: (invite) => _Invite(invite: invite, member: member),
                error: (error, _) => LoadError(
                  message: failureMessage(error),
                  onRetry: () => ref.invalidate(provider),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
        ],
      ),
    );
  }
}

class _Invite extends StatelessWidget {
  const _Invite({required this.invite, this.member});

  final GroupInvite invite;
  final Member? member;

  @override
  Widget build(BuildContext context) {
    final expires = MaterialLocalizations.of(
      context,
    ).formatMediumDate(invite.expiresAt.toLocal());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          member == null
              ? 'Scan with the other phone, or send the link. It works for '
                    'one person, until $expires.'
              : 'They join as ${member!.displayName} and keep '
                    "${member!.displayName}'s expenses. Works once, until "
                    '$expires.',
        ),
        const SizedBox(height: 16),
        Center(
          child: QrImageView(
            data: invite.link,
            size: 220,
            // Dark on light whatever the theme, so every camera reads it.
            backgroundColor: Colors.white,
            semanticsLabel: 'Invite QR code',
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(invite.link, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: invite.link));
            messenger.showSnackBar(
              const SnackBar(content: Text('Invite link copied')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy link'),
        ),
      ],
    );
  }
}
