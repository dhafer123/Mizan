import 'category.dart';

/// The student categories every install starts with. Their ids are fixed, so
/// they are the same on every device and need no sync; a stored category
/// with the same id (renamed or archived, task 2.3) replaces the default.
abstract final class DefaultCategories {
  static const food = Category(id: 'food', name: 'Food', icon: 'food');
  static const transport = Category(
    id: 'transport',
    name: 'Transport',
    icon: 'transport',
  );
  static const rent = Category(id: 'rent', name: 'Rent', icon: 'rent');
  static const study = Category(id: 'study', name: 'Study', icon: 'study');
  static const leisure = Category(
    id: 'leisure',
    name: 'Leisure',
    icon: 'leisure',
  );
  static const other = Category(id: 'other', name: 'Other', icon: 'other');

  static const all = [food, transport, rent, study, leisure, other];
}
