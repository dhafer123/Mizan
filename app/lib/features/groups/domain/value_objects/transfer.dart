import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/money/money.dart';

part 'transfer.freezed.dart';

/// A suggested payment to settle up: [fromMemberId] pays [toMemberId]
/// [amount]. Recording it creates a `Settlement`.
@freezed
abstract class Transfer with _$Transfer {
  const factory Transfer({
    required String fromMemberId,
    required String toMemberId,
    required Money amount,
  }) = _Transfer;
}
