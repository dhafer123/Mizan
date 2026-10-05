import 'dart:async';

import '../../../../core/result/result.dart';
import '../../domain/value_objects/expense_error.dart';
import '../../domain/value_objects/expense_failure.dart';

/// Turns errors in a watched query (database or row mapping) into an [Err]
/// event, so the stream never errors and the layer above never sees a throw.
StreamTransformer<Result<T, ExpenseFailure>, Result<T, ExpenseFailure>>
storageErrorsAsFailures<T>() => StreamTransformer.fromHandlers(
  handleError: (error, stackTrace, sink) =>
      sink.add(const Err(ExpenseFailure(ExpenseError.storage))),
);
