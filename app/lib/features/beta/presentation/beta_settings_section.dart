import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../expenses/presentation/shared/failure_message.dart';
import 'usage_sharing_controller.dart';

/// Settings for the beta: the feedback button and the opt-in, anonymous
/// usage counter.
class BetaSettingsSection extends ConsumerWidget {
  const BetaSettingsSection({super.key});

  Future<void> _setSharing(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await ref
        .read(usageSharingControllerProvider.notifier)
        .setEnabled(enabled: enabled);
    if (failure != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const title = Text('Share anonymous usage counts');
    const icon = Icon(Icons.insights_outlined);
    return Column(
      children: [
        ListTile(
          onTap: () => context.push(AppRoutes.feedback),
          leading: const Icon(Icons.feedback_outlined),
          title: const Text('Send feedback'),
          subtitle: const Text('Tell us what is broken, confusing or missing.'),
        ),
        ref
            .watch(usageSharingControllerProvider)
            .when(
              skipLoadingOnReload: true,
              data: (enabled) => SwitchListTile(
                value: enabled,
                onChanged: (on) => _setSharing(context, ref, enabled: on),
                secondary: icon,
                title: title,
                subtitle: const Text(
                  'How many expenses you log each day, and how (typed, voice '
                  'or receipt). No amounts, notes, categories or account.',
                ),
              ),
              error: (error, _) => ListTile(
                leading: icon,
                title: title,
                subtitle: Text(failureMessage(error)),
                trailing: TextButton(
                  onPressed: () =>
                      ref.invalidate(usageSharingControllerProvider),
                  child: const Text('Retry'),
                ),
              ),
              loading: () => const ListTile(
                leading: icon,
                title: title,
                trailing: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      ],
    );
  }
}
