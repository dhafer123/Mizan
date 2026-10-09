import 'package:dio/dio.dart';

import '../../domain/value_objects/feedback_message.dart';
import '../../domain/value_objects/usage_report.dart';

/// The server's `/beta/*` endpoints (server/beta/views.py). Give it the
/// public [Dio] (no access token: these are anonymous). Methods throw
/// [DioException] for transport and HTTP errors.
class BetaApi {
  const BetaApi(this._dio);

  final Dio _dio;

  Future<void> sendFeedback(FeedbackMessage feedback) => _dio.post<Object?>(
    '/beta/feedback',
    data: {
      'message': feedback.message,
      'contact': feedback.contact,
      'appVersion': feedback.appVersion,
    },
  );

  Future<void> sendUsage(UsageReport report) => _dio.post<Object?>(
    '/beta/usage',
    data: {
      'installId': report.installId,
      'appVersion': report.appVersion,
      'days': [
        for (final day in report.days)
          {
            'day': _isoDate(day.day),
            'manual': day.manual,
            'voice': day.voice,
            'receipt': day.receipt,
          },
      ],
    },
  );

  static String _isoDate(DateTime day) =>
      day.toIso8601String().substring(0, 10);
}
