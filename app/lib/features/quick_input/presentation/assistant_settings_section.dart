import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expenses/presentation/shared/failure_message.dart';
import 'assistant_model.dart';
import 'assistant_model_controller.dart';
import 'quick_input_timings.dart';

/// Settings for quick input: the opt-in on-device assistant (download or
/// delete) and the voice timings measured this session.
class AssistantSettingsSection extends ConsumerWidget {
  const AssistantSettingsSection({super.key});

  Future<void> _confirmDownload(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download the assistant?'),
        content: const Text(
          'It reads phrases the quick rules are unsure about, on this phone '
          'only. It takes about 550 MB: use Wi-Fi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(assistantModelControllerProvider.notifier).download();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(assistantModelControllerProvider);
    final timings = ref.watch(quickInputTimingsProvider);
    final median = medianOf(timings);

    return Column(
      children: [
        model.when(
          data: (model) => _modelTile(context, ref, model),
          error: (error, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('On-device assistant'),
            subtitle: Text(failureMessage(error)),
            onTap: () => ref.invalidate(assistantModelControllerProvider),
          ),
          loading: () => const ListTile(
            leading: Icon(Icons.auto_awesome_outlined),
            title: Text('On-device assistant'),
            subtitle: LinearProgressIndicator(),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('Voice timings'),
          subtitle: Text(
            median == null
                ? 'From the end of speech to the items on screen. Nothing '
                      'measured yet.'
                : 'Median ${median.inMilliseconds} ms over ${timings.length} '
                      'phrase(s), this session.',
          ),
          trailing: timings.isEmpty
              ? null
              : IconButton(
                  onPressed: ref.read(quickInputTimingsProvider.notifier).clear,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear',
                ),
        ),
      ],
    );
  }

  Widget _modelTile(BuildContext context, WidgetRef ref, AssistantModel model) {
    final controller = ref.read(assistantModelControllerProvider.notifier);
    final error = model.error;
    if (model.downloading) {
      return ListTile(
        leading: const Icon(Icons.downloading_outlined),
        title: Text('Downloading the assistant: ${model.progress}%'),
        subtitle: LinearProgressIndicator(value: model.progress! / 100),
      );
    }
    if (model.installed) {
      return ListTile(
        leading: const Icon(Icons.auto_awesome),
        title: const Text('On-device assistant'),
        subtitle: Text(error ?? 'Ready. Reads unsure phrases on this phone.'),
        trailing: TextButton(
          onPressed: controller.delete,
          child: const Text('Delete'),
        ),
      );
    }
    return ListTile(
      leading: const Icon(Icons.auto_awesome_outlined),
      title: const Text('On-device assistant'),
      subtitle: Text(
        error ?? 'Helps read numbers in words and messy phrases. About 550 MB.',
      ),
      trailing: TextButton(
        onPressed: () => _confirmDownload(context, ref),
        child: Text(error == null ? 'Download' : 'Retry'),
      ),
    );
  }
}
