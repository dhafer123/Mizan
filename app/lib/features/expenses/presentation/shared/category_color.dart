import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/entities/category.dart';
import 'category_icon.dart';

/// A category's colour, from its icon key, so it is the same on every phone
/// without storing or syncing a colour: the chart slice, the avatar, the
/// budget bar. Unknown keys (from a newer app) and no category are grey.
Color categoryColor(BuildContext context, Category? category) {
  final colors = AppColors.of(context);
  final slot = switch (category?.icon) {
    'study' || 'phone' => 0, // blue
    'transport' || 'travel' => 1, // cyan
    'food' || 'coffee' || 'groceries' => 2, // amber
    'leisure' || 'gifts' || 'beauty' => 3, // pink
    'rent' || 'bills' => 4, // violet
    'health' || 'sport' => 5, // green
    'clothes' => 6, // orange
    'other' => 7, // sky
    _ => null,
  };
  return slot == null ? colors.chartOther : colors.categories[slot];
}

/// A category's icon in a tonal circle of its colour. Decoration: the
/// category's name is always next to it.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({required this.category, this.radius = 20, super.key});

  /// Null while categories load, or for one this phone doesn't know.
  final Category? category;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(context, category);
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
        child: Icon(categoryIcon(category?.icon ?? ''), size: radius),
      ),
    );
  }
}
