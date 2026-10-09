import 'package:dio/dio.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/beta_repository.dart';
import '../../domain/value_objects/beta_error.dart';
import '../../domain/value_objects/beta_failure.dart';
import '../../domain/value_objects/feedback_message.dart';
import '../../domain/value_objects/usage_report.dart';
import '../remote/beta_api.dart';

/// [BetaRepository] over [BetaApi]. Network errors become [BetaFailure]s.
class BetaRepositoryImpl implements BetaRepository {
  const BetaRepositoryImpl(this._api);

  final BetaApi _api;

  @override
  Future<Result<void, BetaFailure>> sendFeedback(FeedbackMessage feedback) =>
      _guard(() => _api.sendFeedback(feedback));

  @override
  Future<Result<void, BetaFailure>> sendUsage(UsageReport report) =>
      _guard(() => _api.sendUsage(report));

  static Future<Result<void, BetaFailure>> _guard(
    Future<void> Function() call,
  ) async {
    try {
      await call();
      return const Ok(null);
    } on DioException catch (e) {
      return Err(BetaFailure(_fromDio(e)));
    }
  }

  static BetaError _fromDio(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => BetaError.offline,
    DioExceptionType.badResponse when e.response?.statusCode == 429 =>
      BetaError.tooManyRequests,
    _ => BetaError.server,
  };
}
