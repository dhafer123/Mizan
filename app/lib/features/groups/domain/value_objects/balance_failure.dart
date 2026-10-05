import '../../../../core/result/failure.dart';
import 'balance_error.dart';

class BalanceFailure extends Failure {
  const BalanceFailure(this.error, {required this.recordId});

  final BalanceError error;

  /// The expense or settlement that broke the rule.
  final String recordId;

  @override
  String get message => switch (error) {
    BalanceError.currencyMismatch =>
      'A record in this group uses a different currency.',
    BalanceError.sharesDoNotMatchAmount =>
      "An expense's shares do not add up to its amount.",
    BalanceError.invalidSettlement => 'A payment in this group is invalid.',
  };

  @override
  bool operator ==(Object other) =>
      other is BalanceFailure &&
      other.error == error &&
      other.recordId == recordId;

  @override
  int get hashCode => Object.hash(error, recordId);
}
