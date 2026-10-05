import 'package:flutter/material.dart';

/// The icon keys a category can use, in picker order. Keys are stored and
/// synced, so never rename one; add new ones at the end.
const categoryIconKeys = [
  'food',
  'transport',
  'rent',
  'study',
  'leisure',
  'other',
  'coffee',
  'groceries',
  'health',
  'phone',
  'clothes',
  'gifts',
  'sport',
  'travel',
  'bills',
  'beauty',
];

/// The glyph for a category's icon key. Unknown keys get a generic tag, so
/// a newer app's icon never breaks an older one.
IconData categoryIcon(String key) => switch (key) {
  'food' => Icons.restaurant,
  'transport' => Icons.directions_bus,
  'rent' => Icons.home_outlined,
  'study' => Icons.school_outlined,
  'leisure' => Icons.sports_esports_outlined,
  'other' => Icons.category_outlined,
  'coffee' => Icons.local_cafe_outlined,
  'groceries' => Icons.shopping_basket_outlined,
  'health' => Icons.medical_services_outlined,
  'phone' => Icons.smartphone,
  'clothes' => Icons.checkroom,
  'gifts' => Icons.card_giftcard,
  'sport' => Icons.fitness_center,
  'travel' => Icons.flight_outlined,
  'bills' => Icons.receipt_outlined,
  'beauty' => Icons.spa_outlined,
  _ => Icons.label_outline,
};
