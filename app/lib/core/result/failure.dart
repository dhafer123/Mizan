/// An expected, recoverable error, returned inside a `Result` instead of
/// being thrown. Every failure carries a [message] the UI can show.
///
/// Features define their own subclasses (e.g. `MoneyParseFailure`).
abstract class Failure {
  const Failure();

  String get message;

  @override
  String toString() => '$runtimeType: $message';
}
