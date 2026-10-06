/// This phone, as sent with sign-up and sign-in so the server can keep a
/// device row (push tokens arrive in task 4.6).
class DeviceInfo {
  const DeviceInfo({required this.id, required this.platform});

  final String id;

  /// `android` or `ios`.
  final String platform;

  Map<String, Object?> toJson() => {'id': id, 'platform': platform};
}
