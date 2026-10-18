import 'package:flutter/material.dart';

import '../../features/mascot/presentation/penny_pose.dart';

/// A screen or tab with nothing to show yet: Penny (or an icon), a title,
/// what to do about it, and optionally a button that does it. Scrolls when
/// large text makes it taller than the space it has.
class EmptyState extends StatelessWidget {
  const EmptyState({
    this.penny,
    this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  }) : assert(penny != null || icon != null, 'Penny or an icon');

  /// Penny in a pose that fits; shown instead of [icon].
  final PennyArt? penny;
  final IconData? icon;
  final String title;
  final String message;

  /// A button, e.g. "Add income".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The title says it; Penny or the icon is decoration.
            if (penny case final penny?)
              PennyPose(penny, size: 160)
            else
              ExcludeSemantics(
                child: Icon(icon, size: 56, color: theme.colorScheme.primary),
              ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
