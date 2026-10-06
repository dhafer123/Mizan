/// Invite links: `mizan://mizan.app/join/<token>`. The app opens them (deep
/// link), shows them as a QR code, and accepts them pasted.
abstract final class InviteLink {
  static const scheme = 'mizan';
  static const host = 'mizan.app';

  static final _token = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

  static String forToken(String token) => '$scheme://$host/join/$token';

  /// The token in a pasted link (or a bare token), or null if [input] is
  /// neither. Takes any link whose path is `/join/<token>`, so an https
  /// form would work too.
  static String? tokenFrom(String input) {
    final text = input.trim();
    if (_token.hasMatch(text)) return text;
    final segments = Uri.tryParse(text)?.pathSegments ?? const <String>[];
    final at = segments.indexOf('join');
    if (at == -1 || at != segments.length - 2) return null;
    final token = segments.last;
    return _token.hasMatch(token) ? token : null;
  }
}
