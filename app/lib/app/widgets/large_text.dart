import 'package:flutter/widgets.dart';

extension LargeText on BuildContext {
  /// The user's text size is 130% or more: side-by-side layouts should
  /// stack instead.
  bool get hasLargeText => MediaQuery.textScalerOf(this).scale(10) >= 13;
}
