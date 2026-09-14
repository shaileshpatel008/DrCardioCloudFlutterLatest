/// Mirrors the `success_data` object returned by `api/login` and
/// `api/get-token`.
class UserModel {
  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.rememberToken,
    this.reportLimitEnabled = false,
    this.reportLimit = 0,
  });

  final int userId;
  final String name;
  final String email;
  final String rememberToken;
  final bool reportLimitEnabled;
  final int reportLimit;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      rememberToken: json['remember_token'] as String? ?? '',
      reportLimitEnabled: (json['report_limit_enabled'] == 1 || json['report_limit_enabled'] == true),
      reportLimit: json['report_limit'] as int? ?? 0,
    );
  }
}
