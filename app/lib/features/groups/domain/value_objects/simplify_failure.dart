import '../../../../core/result/failure.dart';
import 'simplify_error.dart';

class SimplifyFailure extends Failure {
  const SimplifyFailure(this.error);

  final SimplifyError error;

  @override
  String get message => switch (error) {
    SimplifyError.notBalanced => "The group's balances do not add up.",
    SimplifyError.currencyMismatch =>
      "The group's balances use more than one currency.",
  };

  @override
  bool operator ==(Object other) =>
      other is SimplifyFailure && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
