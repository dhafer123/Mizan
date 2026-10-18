import 'package:flutter/material.dart';

import '../../features/mascot/presentation/penny_pose.dart';

/// An error state with a worried Penny and a retry button. Scrolls when
/// large text makes it taller than the space it has.
class LoadError extends StatelessWidget {
  const LoadError({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PennyPose(PennyArt.worried, size: 120),
            const SizedBox(height: 16),
            // Read out as soon as it appears.
            Semantics(
              liveRegion: true,
              child: Text(message, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
