import 'package:flutter/material.dart';

/// The glyph for a category's icon key. Unknown keys get a generic tag, so
/// a newer app's icon never breaks an older one.
IconData categoryIcon(String key) => switch (key) {
  'food' => Icons.restaurant,
  'transport' => Icons.directions_bus,
  'rent' => Icons.home_outlined,
  'study' => Icons.school_outlined,
  'leisure' => Icons.sports_esports_outlined,
  'other' => Icons.category_outlined,
  _ => Icons.label_outline,
};
