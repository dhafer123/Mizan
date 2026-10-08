/// The on-device assistant model as Settings shows it.
class AssistantModel {
  const AssistantModel({required this.installed, this.progress, this.error});

  final bool installed;

  /// 0-100 while downloading.
  final int? progress;

  /// Why the last download or delete failed.
  final String? error;

  bool get downloading => progress != null;
}
