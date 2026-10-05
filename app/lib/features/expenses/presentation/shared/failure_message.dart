import '../../../../core/result/failure.dart';

/// The text to show for an error state.
String failureMessage(Object error) =>
    error is Failure ? error.message : 'Something went wrong.';
