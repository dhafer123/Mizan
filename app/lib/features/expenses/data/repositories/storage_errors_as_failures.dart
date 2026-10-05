import 'dart:async';

import '../../../../core/result/failure.dart';
import '../../../../core/result/result.dart';

/// Turns errors in a watched query (database or row mapping) into an [Err]
/// carrying [failure], so the stream never errors and the layer above never
/// sees a throw.
StreamTransformer<Result<T, F>, Result<T, F>>
storageErrorsAsFailures<T, F extends Failure>(F failure) =>
    StreamTransformer.fromHandlers(
      handleError: (error, stackTrace, sink) => sink.add(Err(failure)),
    );
