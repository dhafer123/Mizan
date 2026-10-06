import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_report.freezed.dart';

/// What one sync did.
@freezed
abstract class SyncReport with _$SyncReport {
  const factory SyncReport({
    /// Ops the server applied or merged.
    @Default(0) int pushed,

    /// Ops the server refused (kept in the outbox as rejected).
    @Default(0) int rejected,

    /// Rows and history entries pulled and applied.
    @Default(0) int pulled,
  }) = _SyncReport;
}
