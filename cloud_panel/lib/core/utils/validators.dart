/// Form validators matching the Laravel rules (required, email, min:6, confirmed).
class Validators {
  Validators._();

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required.' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Please enter a valid email address.';
  }

  /// [optional] = edit forms, where a blank password keeps the current one.
  static String? password(String? v, {bool optional = false}) {
    if (v == null || v.isEmpty) return optional ? null : 'Password is required.';
    if (v.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  static String? confirm(String? v, String password, {bool optional = false}) {
    if (optional && password.isEmpty && (v == null || v.isEmpty)) return null;
    if (v == null || v.isEmpty) return 'Please confirm the password.';
    return v == password ? null : 'Passwords don\'t match.';
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required.';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length < 7 ? 'Please enter a valid phone number.' : null;
  }

  static String? url(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final uri = Uri.tryParse(v.trim());
    return (uri != null && uri.hasScheme && uri.host.isNotEmpty) ? null : 'Please enter a full URL starting with https://';
  }

  /// 0–4 score used by the password strength meter.
  static int strength(String v) {
    if (v.isEmpty) return 0;
    var score = 0;
    if (v.length >= 6) score++;
    if (v.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) score++;
    if (RegExp(r'[0-9]').hasMatch(v) && RegExp(r'[^A-Za-z0-9]').hasMatch(v)) score++;
    return score.clamp(0, 4);
  }
}
