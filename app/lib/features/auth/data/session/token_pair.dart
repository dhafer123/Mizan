import 'package:freezed_annotation/freezed_annotation.dart';

part 'token_pair.freezed.dart';

/// The server's JWTs: a short-lived [access] token sent with every request,
/// and a [refresh] token (single use) that gets a new pair.
@freezed
abstract class TokenPair with _$TokenPair {
  const factory TokenPair({required String access, required String refresh}) =
      _TokenPair;

  const TokenPair._();

  /// Never prints the tokens.
  @override
  String toString() => 'TokenPair(***)';
}
