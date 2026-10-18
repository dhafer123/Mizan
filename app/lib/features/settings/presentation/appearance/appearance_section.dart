import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/failure.dart';
import '../../domain/value_objects/theme_choice.dart';
import 'reduce_motion_controller.dart';
import 'theme_choice_controller.dart';

/// The theme (a tile showing the current choice, which opens a dialog to
/// change it) and the "Reduce motion" switch.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice =
        ref.watch(themeChoiceControllerProvider).value ?? ThemeChoice.system;
    // The phone's own setting, not the app's (which `MizanApp` adds to the
    // MediaQuery below it).
    final phoneStill = MediaQueryData.fromView(
      View.of(context),
    ).disableAnimations;
    final appStill = ref.watch(reduceMotionControllerProvider).value ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Theme'),
          subtitle: Text(choice.label),
          onTap: () => _choose(context, ref, choice),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.motion_photos_off_outlined),
          title: const Text('Reduce motion'),
          subtitle: Text(
            phoneStill
                ? 'On, because your phone asks for it.'
                : 'No animations or vibrations.',
          ),
          value: phoneStill || appStill,
          onChanged: phoneStill
              ? null
              : (on) async {
                  final failure = await ref
                      .read(reduceMotionControllerProvider.notifier)
                      .set(on: on);
                  if (context.mounted) _showFailure(context, failure);
                },
        ),
      ],
    );
  }

  void _showFailure(BuildContext context, Failure? failure) {
    if (failure == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure.message)));
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    ThemeChoice current,
  ) async {
    final picked = await showDialog<ThemeChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          RadioGroup<ThemeChoice>(
            groupValue: current,
            onChanged: (choice) => Navigator.of(context).pop(choice),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final choice in ThemeChoice.values)
                  RadioListTile<ThemeChoice>(
                    value: choice,
                    title: Text(choice.label),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    final failure = await ref
        .read(themeChoiceControllerProvider.notifier)
        .choose(picked);
    if (context.mounted) _showFailure(context, failure);
  }
}
