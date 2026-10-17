import 'package:flutter/material.dart';

/// A sentence with a button under it, at the end. Under, not beside: beside
/// a sentence a button squeezes it to a sliver at large text sizes.
class TextWithAction extends StatelessWidget {
  const TextWithAction({required this.text, required this.action, super.key});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text),
        Align(alignment: AlignmentDirectional.centerEnd, child: action),
      ],
    );
  }
}
