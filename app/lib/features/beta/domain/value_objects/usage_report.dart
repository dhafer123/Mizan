import 'package:freezed_annotation/freezed_annotation.dart';

import 'usage_day.dart';

part 'usage_report.freezed.dart';

/// One install's recent [days], sent to the server's `/beta/usage`.
@freezed
abstract class UsageReport with _$UsageReport {
  const factory UsageReport({
    required String installId,
    required String appVersion,
    required List<UsageDay> days,
  }) = _UsageReport;
}
