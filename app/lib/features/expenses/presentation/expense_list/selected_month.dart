import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/di/core_providers.dart';
import '../../../../core/clock/year_month.dart';

part 'selected_month.g.dart';

/// The month the expense list shows. Starts at the current month.
@riverpod
class SelectedMonth extends _$SelectedMonth {
  @override
  YearMonth build() => YearMonth.of(ref.watch(clockProvider).now());

  void previous() => state = state.previous;

  /// Does nothing past the current month: expenses can't be in the future.
  void next() {
    if (state.compareTo(current) < 0) state = state.next;
  }

  YearMonth get current => YearMonth.of(ref.read(clockProvider).now());
}
