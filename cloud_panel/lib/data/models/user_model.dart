import '../../core/utils/json_utils.dart';

/// Panel roles, as named by the backend.
enum PanelRole { admin, subAdmin, client, cardiologist, unknown }

PanelRole panelRoleFrom(String? value) => switch (value) {
      'admin' => PanelRole.admin,
      'sub_admin' => PanelRole.subAdmin,
      'client' => PanelRole.client,
      'cardiologist' => PanelRole.cardiologist,
      _ => PanelRole.unknown,
    };

/// The signed-in account: identity, role, and which sections it may open
/// (`menu` keys come from the server so the app never guesses permissions).
class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleLabel,
    required this.menu,
    this.phoneNumber,
    this.oemAccess = false,
    this.logoUrl,
    this.client,
    this.cardiologist,
    this.raw = const {},
  });

  final int id;
  final String name;
  final String email;
  final String? phoneNumber;
  final PanelRole role;
  final String roleLabel;
  final List<String> menu;
  final bool oemAccess;
  final String? logoUrl;
  final ClientProfile? client;
  final CardiologistProfile? cardiologist;
  final Map<String, dynamic> raw;

  bool can(String menuKey) => menu.contains(menuKey);

  bool get isAdmin => role == PanelRole.admin;
  bool get isOem => role == PanelRole.subAdmin;
  bool get isClient => role == PanelRole.client;
  bool get isCardiologist => role == PanelRole.cardiologist;
  bool get isAdminSide => isAdmin || isOem;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty && p != 'Dr.' && p != 'Dr').toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final client = json['client'];
    final cardio = json['cardiologist'];
    return UserModel(
      id: asIntOr(json['id']),
      name: asStringOr(json['name'], 'User'),
      email: asStringOr(json['email']),
      phoneNumber: asString(json['phone_number']),
      role: panelRoleFrom(asString(json['role'])),
      roleLabel: asStringOr(json['role_label'], 'User'),
      menu: (json['menu'] is List) ? (json['menu'] as List).map((e) => e.toString()).toList() : const ['dashboard', 'profile'],
      oemAccess: asBool(json['oem_access']),
      logoUrl: asString(json['logo_url']),
      client: client is Map ? ClientProfile.fromJson(asMap(client)) : null,
      cardiologist: cardio is Map ? CardiologistProfile.fromJson(asMap(cardio)) : null,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class ClientProfile {
  ClientProfile({
    required this.id,
    required this.hospitalName,
    this.doctorName,
    this.address,
    this.multiHospitalAccess = false,
    this.reportLimitEnabled = false,
    this.reportLimit = 0,
  });

  final int id;
  final String hospitalName;
  final String? doctorName;
  final String? address;
  final bool multiHospitalAccess;
  final bool reportLimitEnabled;
  final int reportLimit;

  factory ClientProfile.fromJson(Map<String, dynamic> json) => ClientProfile(
        id: asIntOr(json['id']),
        hospitalName: asStringOr(json['hospital_name']),
        doctorName: asString(json['doctor_name']),
        address: asString(json['address']),
        multiHospitalAccess: asBool(json['multi_hospital_access']),
        reportLimitEnabled: asBool(json['report_limit_enabled']),
        reportLimit: asIntOr(json['report_limit']),
      );
}

class CardiologistProfile {
  CardiologistProfile({this.address, this.footer, this.logoUrl, this.signatureUrl});

  final String? address;
  final String? footer;
  final String? logoUrl;
  final String? signatureUrl;

  factory CardiologistProfile.fromJson(Map<String, dynamic> json) => CardiologistProfile(
        address: asString(json['address']),
        footer: asString(json['footer']),
        logoUrl: asString(json['logo_url']),
        signatureUrl: asString(json['signature_url']),
      );
}
