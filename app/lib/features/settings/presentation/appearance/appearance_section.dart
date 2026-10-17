import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/theme_choice.dart';
import 'theme_choice_controller.dart';

/// The theme setting: a tile showing the current choice, which opens a
/// dialog to change it.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice =
        ref.watch(themeChoiceControllerProvider).value ?? ThemeChoice.system;
    return ListTile(
      leading: const Icon(Icons.dark_mode_outlined),
      title: const Text('Theme'),
      subtitle: Text(choice.label),
      onTap: () => _choose(context, ref, choice),
    );
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
    if (failure != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}
