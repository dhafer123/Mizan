import '../../../../core/result/failure.dart';
import 'category_error.dart';

class CategoryFailure extends Failure {
  const CategoryFailure(this.error);

  final CategoryError error;

  @override
  String get message => switch (error) {
    CategoryError.nameEmpty => 'Enter a name.',
    CategoryError.nameTooLong => 'The name is too long.',
    CategoryError.nameTaken => 'Another category already has this name.',
    CategoryError.noIcon => 'Pick an icon.',
    CategoryError.limitNotPositive => 'The limit must be more than 0.',
    CategoryError.lastActive => 'Keep at least one category.',
    CategoryError.notFound => 'This category no longer exists.',
    CategoryError.storage => "Couldn't save on this device. Try again.",
  };

  @override
  bool operator ==(Object other) =>
      other is CategoryFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
