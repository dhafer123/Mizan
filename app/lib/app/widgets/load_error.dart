import 'package:flutter/material.dart';

/// An error state with a retry button. Scrolls when large text makes it
/// taller than the space it has.
class LoadError extends StatelessWidget {
  const LoadError({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.error_outline, size: 56, color: colors.error),
            ),
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
